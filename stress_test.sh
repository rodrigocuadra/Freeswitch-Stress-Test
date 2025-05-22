#!/bin/bash
set -e
# Authors:      Rodrigo Cuadra
#               Adapted for FreeSWITCH
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
    n=1
    while read line; do
        case $n in
            1) ip_remote=$line ;;
            2) ssh_remote_port=$line ;;
            3) interface_name=$line ;;
            4) maxcpuload=$line ;;
            5) call_step=$line ;;
            6) call_step_seconds=$line ;;
        esac
        n=$((n+1))
    done < $filename
    echo -e "IP Remote....................... >  $ip_remote"
    echo -e "SSH Remote Port................ >  $ssh_remote_port"
    echo -e "Network Interface.............. >  $interface_name"
    echo -e "Max CPU Load................... >  $maxcpuload"
    echo -e "Calls per Step................. >  $call_step"
    echo -e "Seconds per Step............... >  $call_step_seconds"
fi

while [[ $ip_remote == '' ]]; do
    read -p "IP Remote....................... > " ip_remote
done

while [[ $ssh_remote_port == '' ]]; do
    read -p "SSH Remote Port (Default 22)... > " ssh_remote_port
done

while [[ $interface_name == '' ]]; do
    read -p "Network Interface name (e.g., eth0) > " interface_name
done

while [[ $maxcpuload == '' ]]; do
    read -p "Max CPU Load (%)............... > " maxcpuload
done

while [[ $call_step == '' ]]; do
    read -p "Calls per Step................. > " call_step
done

while [[ $call_step_seconds == '' ]]; do
    read -p "Seconds per Step............... > " call_step_seconds
done

echo -e "$ip_remote"            > config.txt
echo -e "$ssh_remote_port"    >> config.txt
echo -e "$interface_name"     >> config.txt
echo -e "$maxcpuload"         >> config.txt
echo -e "$call_step"          >> config.txt
echo -e "$call_step_seconds"  >> config.txt
# -------------------------------------------------------------
# Copy dialplan and gateway XML to remote server
# -------------------------------------------------------------
scp -P $ssh_remote_port dialplan_9500.xml root@$ip_remote:/etc/freeswitch/dialplan/default/9500.xml
scp -P $ssh_remote_port gateway_call-test-trk.xml root@$ip_remote:/etc/freeswitch/sip_profiles/external/call-test-trk.xml

ssh -p $ssh_remote_port root@$ip_remote "fs_cli -x 'reloadxml'"
ssh -p $ssh_remote_port root@$ip_remote "fs_cli -x 'reload mod_sofia'"


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
        fs_cli -x "originate sofia/gateway/call-test-trk/9000 &park()" >/dev/null
        sleep 0.2
    done

    R2=$(cat /sys/class/net/$interface_name/statistics/rx_bytes)
    T2=$(cat /sys/class/net/$interface_name/statistics/tx_bytes)
    date2=$(date +%s)
    diff=$((date2 - date1))
    bwtx=$(((T2 - T1) / 128 / diff))
    bwrx=$(((R2 - R1) / 128 / diff))
    load=$(cat /proc/loadavg | awk '{print $1}')
    cpu=$(top -bn1 | grep Cpu | awk '{print 100 - $8}')
    activecalls=$(fs_cli -x "show calls count" | grep total | awk '{print $1}')

    echo "$step,$i,$cpu,$load,$bwtx,$bwrx" >> data.csv

    cpuint={cpu%.*}
    if [ "$cpuint" -gt "$maxcpuload" ]; then
        echo "CPU load too high ($cpu%), stopping test..."
        break
    fi

    i=$((i + call_step))
    step=$((step + 1))
    sleep "$call_step_seconds"
done

echo -e "\n\033[1;32mTest complete. Results saved to data.csv\033[0m"
