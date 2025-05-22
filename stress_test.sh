#!/bin/bash
set -e
# Authors:      Rodrigo Cuadra
#               Final Version for FreeSWITCH
# Date:         22-May-2025
# Support:      rcuadra@vitalpbx.com

clear
echo -e "\n\033[1;36m"
echo -e "************************************************************"
echo -e "*        Welcome to the FreeSWITCH Stress Test Tool        *"
echo -e "*              All options are mandatory                   *"
echo -e "************************************************************"
echo -e "\033[0m"

filename="config.txt"
if [ -f $filename ]; then
    echo -e "Loading config file..."
    mapfile -t config < "$filename"
    ip_remote="${config[0]}"
    ssh_remote_port="${config[1]}"
    interface_name="${config[2]}"
    maxcpuload="${config[3]}"
    call_step="${config[4]}"
    call_step_seconds="${config[5]}"
    call_duration="${config[6]}"
    echo -e "IP Remote...................... >  $ip_remote"
    echo -e "SSH Remote Port................ >  $ssh_remote_port"
    echo -e "Network Interface.............. >  $interface_name"
    echo -e "Max CPU Load................... >  $maxcpuload"
    echo -e "Calls per Step................. >  $call_step"
    echo -e "Seconds per Step............... >  $call_step_seconds"
    echo -e "Estimated Call Duration (s).... >  $call_duration"
fi

read -rp "IP Remote............................. > " -e -i "$ip_remote" ip_remote
read -rp "SSH Remote Port (Default 22).......... > " -e -i "${ssh_remote_port:-22}" ssh_remote_port
read -rp "Network Interface name (e.g., eth0)... > " -e -i "$interface_name" interface_name
read -rp "Max CPU Load (%)...................... > " -e -i "$maxcpuload" maxcpuload
read -rp "Calls per Step........................ > " -e -i "$call_step" call_step
read -rp "Seconds per Step...................... > " -e -i "$call_step_seconds" call_step_seconds
read -rp "Estimated Call Duration (s)........... > " -e -i "${call_duration:-180}" call_duration

echo -e "$ip_remote"           > config.txt
echo -e "$ssh_remote_port"    >> config.txt
echo -e "$interface_name"     >> config.txt
echo -e "$maxcpuload"         >> config.txt
echo -e "$call_step"          >> config.txt
echo -e "$call_step_seconds"  >> config.txt
echo -e "$call_duration"      >> config.txt

# -------------------------------------------------------------
# Copy SSH Key to Remote Server
# -------------------------------------------------------------
echo -e "************************************************************"
echo -e "*          Copy Authorization key to remote server         *"
echo -e "************************************************************"

sshKeyFile="/root/.ssh/id_rsa"

if [ ! -f "$sshKeyFile" ]; then
    echo -e "Generating SSH key..."
    ssh-keygen -f "$sshKeyFile" -t rsa -N '' >/dev/null
fi

echo -e "Copying public key to $ip_remote..."
ssh-copy-id -i "${sshKeyFile}.pub" -p "$ssh_remote_port" root@$ip_remote

if [ $? -eq 0 ]; then
    echo -e "*** SSH key installed successfully. ***"
else
    echo -e "❌ Failed to copy SSH key. You might need to check connectivity or credentials."
    exit 1
fi

# -------------------------------------------------------------
# Create SIP Gateway to remote FreeSWITCH
# -------------------------------------------------------------
echo -e "Creating local SIP gateway configuration..."

cat <<EOF > /etc/freeswitch/sip_profiles/external/call-test-trk.xml
<gateway name="call-test-trk">
  <param name="proxy" value="$ip_remote"/>
  <param name="register" value="false"/>
  <param name="username" value="calltest"/>
  <param name="password" value="test123"/>
  <param name="context" value="default"/>
</gateway>
EOF

fs_cli -x 'reloadxml' >/dev/null
fs_cli -x 'reload mod_sofia' >/dev/null

# -------------------------------------------------------------
# Create dialplan for extension 9500 on remote server
# -------------------------------------------------------------
echo -e "Creating dialplan for 9500 on remote server..."

ssh -p "$ssh_remote_port" root@$ip_remote "cat <<EOF > /etc/freeswitch/dialplan/default/9500.xml
<extension name=\"moh-test\">
  <condition field=\"destination_number\" expression=\"^9500$\">
    <action application=\"answer\"/>
    <action application=\"playback\" data=\"local_stream://moh\"/>
    <action application=\"hangup\"/>
  </condition>
</extension>
EOF"

ssh -p "$ssh_remote_port" root@$ip_remote "fs_cli -x 'reloadxml'" >/dev/null

echo -e "\n\033[1;33m************************************************************"
echo -e "*              Starting Stress Test Execution              *"
echo -e "************************************************************\033[0m"

numcores=$(nproc --all)
step=0
i=0
echo "step,calls,cpu(%),load,tx(kb/s),rx(kb/s)" > data.csv

while true; do
    R1=$(cat /sys/class/net/$interface_name/statistics/rx_bytes)
    T1=$(cat /sys/class/net/$interface_name/statistics/tx_bytes)
    date1=$(date +%s)

    for ((j=1; j<=call_step; j++)); do
        fs_cli -x "originate sofia/gateway/call-test-trk/9500 &park()" >/dev/null
        sleep 0.2
    done

    R2=$(cat /sys/class/net/$interface_name/statistics/rx_bytes)
    T2=$(cat /sys/class/net/$interface_name/statistics/tx_bytes)
    date2=$(date +%s)
    diff=$((date2 - date1))
    [[ $diff -eq 0 ]] && diff=1
    bwtx=$(((T2 - T1) / 128 / diff))
    bwrx=$(((R2 - R1) / 128 / diff))
    load=$(awk '{print $1}' /proc/loadavg)
    cpu=$(top -bn1 | grep Cpu | awk '{print 100 - $8}' | cut -d'.' -f1)
    activecalls=$(fs_cli -x "show calls count" | grep total | awk '{print $1}')

    echo "$step,$i,$cpu,$load,$bwtx,$bwrx" >> data.csv

    if [ "$cpu" -gt "$maxcpuload" ]; then
        echo "⚠️  CPU load too high ($cpu%), stopping test..."
        break
    fi

    i=$((i + call_step))
    step=$((step + 1))
    sleep "$call_step_seconds"
done

echo -e "\n\033[1;32m✅ Test complete. Results saved to data.csv\033[0m"

# -------------------------------------------------------------
# Summary Report
# -------------------------------------------------------------
echo -e "\n\033[1;34mGenerating summary from data.csv...\033[0m"

if [ -f data.csv ]; then
    tail -n +2 data.csv | awk -F',' -v dur="$call_duration" '
    BEGIN {
        max_cpu=0; sum_cpu=0; count=0;
        max_calls=0; sum_calls=0;
    }
    {
        cpu = $3 + 0;
        calls = $2 + 0;
        if(cpu > max_cpu) max_cpu = cpu;
        if(calls > max_calls) max_calls = calls;
        sum_cpu += cpu;
        sum_calls += calls;
        count++;
    }
    END {
        avg_cpu = (count > 0) ? sum_cpu / count : 0;
        avg_calls = (count > 0) ? sum_calls / count : 0;
        est_calls_per_hour = (dur > 0) ? max_calls * (3600 / dur) : 0;
        printf("\n📊 Summary:\n");
        printf("• Max CPU Usage.......: %.2f%%\n", max_cpu);
        printf("• Average CPU Usage...: %.2f%%\n", avg_cpu);
        printf("• Max Concurrent Calls: %d\n", max_calls);
        printf("• Average Calls/Step..: %.2f\n", avg_calls);
        printf("• ➕ Estimated Calls/hour (duration ~%ds): %.0f\n\n", dur, est_calls_per_hour);
    }'
else
    echo "data.csv not found."
fi


