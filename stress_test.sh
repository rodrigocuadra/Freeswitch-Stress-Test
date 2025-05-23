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
  <param name="proxy" value="$ip_remote:5080"/>
  <param name="register" value="false"/>
  <param name="username" value="calltest"/>
  <param name="password" value="test123"/>
  <param name="context" value="default"/>
</gateway>
EOF

# -------------------------------------------------------------
# Create Extension 9600
# -------------------------------------------------------------
wget -O /usr/local/freeswitch/sounds/en/us/callie/sarah.wav  https://github.com/VitalPBX/VitalPBX-Stress-Test/raw/refs/heads/master/sarah.wav

cat <<EOF > /etc/freeswitch/dialplan/public/9600.xml
<extension name="stress-test-9600">
  <condition field="destination_number" expression="^9600$">
    <action application="set" data="hangup_after_bridge=true"/>
    <action application="set" data="execute_on_answer=playback(sarah.wav)"/>
    <action application="answer"/>
    <action application="sleep" data="500"/>
    <action application="bridge" data="sofia/gateway/call-test-trk/9500"/>
  </condition>
</extension>
EOF

# -------------------------------------------------------------
# Create dialplan for extension 9500 on remote server
# -------------------------------------------------------------
echo -e "Creating dialplan for 9500 on remote server..."

ssh -p $ssh_remote_port root@$ip_remote "wget -O /usr/local/freeswitch/sounds/en/us/callie/jonathan.wav https://github.com/VitalPBX/VitalPBX-Stress-Test/raw/refs/heads/master/jonathan.wav"

ssh -p "$ssh_remote_port" root@$ip_remote 'cat <<EOF > /etc/freeswitch/dialplan/public/9500.xml
<extension name="stress-test-remote">
  <condition field="destination_number" expression="^9500$">
    <action application="answer"/>
    <action application="playback" data="jonathan.wav"/>
    <action application="sleep" data="60000"/>
    <action application="hangup"/>
  </condition>
</extension>
EOF'

echo -e "*** Done ***"
echo -e " **************************************************************************************"
echo -e " *                      Restarting Freeswitch in both Server                          *"
echo -e " **************************************************************************************"
systemctl restart freeswitch
ssh -p $ssh_remote_port root@$ip_remote "systemctl restart freeswitch"
sleep 10
numcores=`nproc --all`
exitcalls=false
i=0
step=0
clear
echo -e " ************************************************************************************************"
echo -e "     Actual Test State (Step: "$call_step_seconds"s, Core: "$numcores", Protocol: "$protocol_name", Codec: "$codec_name", Recording: "$recording")     "
echo -e " ************************************************************************************************"
echo -e " ------------------------------------------------------------------------------------------------"
printf "%2s %7s %10s %21s %10s %10s %10s %12s %12s\n" "|" " Step |" "Calls |" "Freeswitch Channels |" "CPU Load |" "Load |" "Memory |" "BW TX kb/s |" "BW RX kb/s |"
R1=`cat /sys/class/net/"$interface_name"/statistics/rx_bytes`
T1=`cat /sys/class/net/"$interface_name"/statistics/tx_bytes`
date1=$(date +"%s")
slepcall=$(printf %.2f "$((1000000000 * call_step_seconds / call_step))e-9")
sleep 1
#echo -e "calls, active calls, cpu load (%), memory (%), bwtx (kb/s), bwrx(kb/s), interval(seg)" 	> data.csv
echo "step,calls,cpu(%),load,tx(kb/s),rx(kb/s)" > data.csv
	while [ $exitcalls = 'false' ]        
        do
       		R2=`cat /sys/class/net/"$interface_name"/statistics/rx_bytes`
       		T2=`cat /sys/class/net/"$interface_name"/statistics/tx_bytes`
		date2=$(date +"%s")
		diff=$(($date2-$date1))
		seconds="$(($diff % 60))"
		T2=`expr $T2 + 128`
		R2=`expr $R2 + 128`
        	TBPS=`expr $T2 - $T1`
        	RBPS=`expr $R2 - $R1`
        	TKBPS=`expr $TBPS / 128`
        	RKBPS=`expr $RBPS / 128`
		bwtx="$((TKBPS/seconds))"
		bwrx="$((RKBPS/seconds))"
                activecalls=$(fs_cli -x "show channels count" | grep total | awk '{print $1}')
  		load=`cat /proc/loadavg | awk '{print $0}' | cut -d " " -f 1`
		cpu=`top -n 1 | awk 'FNR > 7 {s+=$10} END {print s}'`
		cpuint=${cpu%.*}
		cpu="$((cpuint/numcores))"
		# memory=`free | awk '/Mem/{printf("%.2f%"), $3/$2*100} /buffers\/cache/{printf(", buffers: %.2f%"), $4/($3+$4)*100}'`
                memory=$(free | awk '/Mem:/ {used=$3; total=$2} END {if (total>0) printf("%.2f%%", used/total*100); else print "N/A"}')
		if [ "$cpu" -le 34 ] ;then
			echo -e "\e[92m ------------------------------------------------------------------------------------------------"
		fi
		if [ "$cpu" -ge 35 ] && [ "$cpu" -lt 65 ] ;then
			echo -e "\e[93m ------------------------------------------------------------------------------------------------"
		fi
		if [ "$cpu" -ge 65 ] ;then
			echo -e "\e[91m ------------------------------------------------------------------------------------------------"
		fi
		printf "%2s %7s %10s %21s %10s %10s %10s %12s %12s\n" "|" " "$step" |" ""$i" |" ""$activecalls" |" ""$cpu"% |" ""$load" |" ""$memory" |" ""$bwtx" |" ""$bwrx" |"
                echo "$step,$i,$cpu,$load,$bwtx,$bwrx" >> data.csv
		exitstep=false
		x=1
		while [ $exitstep = 'false' ]  
        	do
			let x=x+1
			if [ "$call_step" -lt $x ] ;then
				exitstep=true
			fi
                fs_cli -x "originate {absolute_codec_string=PCMU,ignore_early_media=true}sofia/internal/9600@localhost &park()" >/dev/null
                sleep "$slepcall"
		done
		let step=step+1
		let i=i+"$call_step"
		if [ "$cpu" -gt "$maxcpuload" ] ;then
			exitcalls=true
		fi
		R1=`cat /sys/class/net/"$interface_name"/statistics/rx_bytes`
		T1=`cat /sys/class/net/"$interface_name"/statistics/tx_bytes`
		date1=$(date +"%s")
#		sleep "$call_step_seconds"
		sleep 1
	done
echo -e "\e[39m ------------------------------------------------------------------------------------------------"
echo -e " ************************************************************************************************"
echo -e " *                                    Restarting Freeswitch                                     *"
echo -e " ************************************************************************************************"
systemctl restart freeswitch
ssh -p $ssh_remote_port root@$ip_remote "systemctl restart freeswitch"

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
