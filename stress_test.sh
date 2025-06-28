#!/bin/bash

# ------------------------------------------------------------------------------
# Stress Test Script for FreeSWITCH with SIP
# ------------------------------------------------------------------------------
#
# Purpose:      Performs stress testing on FreeSWITCH by generating SIP calls
#               between two servers, monitoring CPU, memory, and bandwidth usage,
#               and generating a performance report.
#
# Authors:      Rodrigo Cuadra (original author)
#               Adapted for FreeSWITCH by Grok 3 (xAI)
#
# Version:      1.0 for FreeSWITCH 1.10.12
# Date:         May 24, 2025
#
# Compatibility: FreeSWITCH 1.10.x with Sofia-SIP module
# Requirements: 
#               - Two FreeSWITCH servers with SSH access
#               - Sofia-SIP configured for UDP transport
#               - Audio files for playback (e.g., WAV files in sounds directory)
#               - Supported codecs: PCMU, G.729, OPUS
#
# Usage:        sudo ./stress_test_freeswitch.sh
#               Follow prompts to configure test parameters or use config.txt
#
# Output:       - Real-time performance metrics (CPU, calls, bandwidth)
#               - Summary report in data.csv
#
# Notes:        - Ensure ports 5060/UDP and RTP range (e.g., 16384-32767) are open
#               - G.729 and OPUS require respective codec modules
#               - Run as root or with sudo
#
# Support:      For issues, refer to FreeSWITCH documentation (https://freeswitch.org/confluence)
#               or contact your system administrator
#
# ------------------------------------------------------------------------------

set -e

# Clear the terminal for a clean start
clear

# Colors for output
CYAN='\033[1;36m'
NC='\033[0m' # No color

# Display welcome message
echo -e "\n${CYAN}"
echo -e "************************************************************"
echo -e "*        Welcome to the FreeSWITCH Stress Test Tool        *"
echo -e "*              All options are mandatory                   *"
echo -e "************************************************************"
echo -e "${NC}"

# Read configuration from configst.txt if it exists
filename="configst.txt"
	if [ -f $filename ]; then
		echo -e "config file"
		n=1
		while read line; do
			case $n in
				1)
					ip_local=$line
  				;;
				2)
					ip_remote=$line
  				;;
				3)
					ssh_remote_port=$line
  				;;
				4)
					interface_name=$line
  				;;
				5)
					codec=$line
  				;;
				6)
					recording=$line
  				;;
				7)
					maxcpuload=$line
  				;;
				8)
					call_step=$line
  				;;
				9)
					call_step_seconds=$line
  				;;
				10)
					call_duration=$line
  				;;
      				11)
					json_output_enabled=$line
  				;;
                        esac
			n=$((n+1))
		done < $filename
		echo -e "IP Local.............................................. >  $ip_local"	
		echo -e "IP Remote............................................. >  $ip_remote"
		echo -e "SSH Remote Port (Default is 22)....................... >  $ssh_remote_port"
		echo -e "Network Interface name (ej: eth0)..................... >  $interface_name"
		echo -e "Codec (1.-PCMU, 2.-G279, 3.- OPUS).................... >  $codec"
		echo -e "Recording Calls (yes,no).............................. >  $recording"
		echo -e "Max CPU Load (Recommended 75%)........................ >  $maxcpuload"
		echo -e "Calls Step (Recommended 5-100)........................ >  $call_step"
		echo -e "Seconds between each step (Recommended 5-30).......... >  $call_step_seconds"
		echo -e "Estimated Call Duration Seconds (ej: 180)............. >  $call_duration"
                echo -e "Enable JSON output for web visualization? (yes,no).... >  $json_output_enabled"

	fi
	
	while [[ $ip_local == '' ]]
	do
    		read -p "IP Local.......................................... > " ip_local 
	done 

	while [[ $ip_remote == '' ]]
	do
    		read -p "IP Remote......................................... > " ip_remote 
	done

	while [[ $ssh_remote_port == '' ]]
	do
    		read -p "SSH Remote Port (Default is 22)................... > " ssh_remote_port 
	done

	while [[ $interface_name == '' ]]
	do
    		read -p "Network Interface name (ej: eth0)................. > " interface_name 
	done

	while [[ $codec == '' ]]
	do
    		read -p "Codec (1.-PCMU, 2.-G79, 3.- OPUS)................. > " codec 
	done 

	while [[ $recording == '' ]]
	do
    		read -p "Recording Calls (yes,no).......................... > " recording 
	done 

	while [[ $maxcpuload == '' ]]
	do
    		read -p "Max CPU Load (Recommended 75%).................... > " maxcpuload 
	done 

	while [[ $call_step == '' ]]
	do
    		read -p "Calls Step (Recommended 5-100).................... > " call_step 
	done 

	while [[ $call_step_seconds == '' ]]
	do
    		read -p "Seconds between each step (Recommended 5-30)...... > " call_step_seconds
	done 

 	while [[ $call_duration == '' ]]
	do
    		read -p "Estimated Call Duration Seconds (ej: 180)......... > " call_duration
	done 
        while [[ -z $json_output_enabled ]]; do
            read -p "Enable JSON output for web visualization? (yes,no).... > " json_output_enabled
        done

echo -e "************************************************************"
echo -e "*                   Check Information                      *"
echo -e "*        Make sure that both server have communication     *"
echo -e "************************************************************"
	while [[ $veryfy_info != yes && $veryfy_info != no ]]
	do
    		read -p "Are you sure to continue with this settings? (yes,no) > " veryfy_info 
	done

	if [ "$veryfy_info" = yes ] ;then
		echo -e "************************************************************"
		echo -e "*                Starting to run the scripts               *"
		echo -e "************************************************************"
	else
		while [[ $ip_local == '' ]]
		do
    			read -p "IP Local.............................................. > " ip_local 
		done 

		while [[ $ip_remote == '' ]]
		do
    			read -p "IP Remote............................................. > " ip_remote 
		done

		while [[ $ssh_remote_port == '' ]]
		do
    			read -p "SSH Remote Port (Default is 22)....................... > " ssh_remote_port 
		done

		while [[ $interface_name == '' ]]
		do
    			read -p "Network Interface name (ej: eth0)..................... > " interface_name 
		done

		while [[ $codec == '' ]]
		do
    			read -p "Codec (1.-PCMU, 2.-G79, 3.- OPUS...................... > " codec 
		done 

		while [[ $recording == '' ]]
		do
    			read -p "Recording Calls (yes,no).............................. > " recording 
		done 

		while [[ $maxcpuload == '' ]]
		do
    			read -p "Max CPU Load (Recommended 75%)........................ > " maxcpuload 
		done 

		while [[ $call_step == '' ]]
		do
    			read -p "Calls Step (Recommended 5-100)........................ > " call_step 
		done 

		while [[ $call_step_seconds == '' ]]
		do
    			read -p "Seconds between each step (Recommended 5-30).......... > " call_step_seconds
		done 
  
		while [[ $call_duration == '' ]]
		do
    			read -p "Estimated Call Duration Seconds (ej: 180)............. > " call_duration
		done 
               
	        while [[ -z $json_output_enabled ]]; do
                        read -p "Enable JSON output for web visualization? (yes,no).... > " json_output_enabled
                done
         fi

echo -e "$ip_local" 		> configst.txt
echo -e "$ip_remote" 		>> configst.txt
echo -e "$ssh_remote_port"	>> configst.txt
echo -e "$interface_name" 	>> configst.txt
echo -e "$codec" 		>> configst.txt
echo -e "$recording" 		>> configst.txt
echo -e "$maxcpuload"     	>> configst.txt
echo -e "$call_step" 		>> configst.txt
echo -e "$call_step_seconds" 	>> configst.txt
echo -e "$call_duration" 	>> configst.txt
echo -e "$json_output_enabled"    >> config.txt

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

case "$codec" in
  1)
    codec_name="PCMU"
    ;;
  2)
    codec_name="G729"
    ;;
  3)
    codec_name="opus"
    ;;
  *)
    codec_name="PCMU"
    ;;
esac

# -------------------------------------------------------------
# Download Local Audio
# -------------------------------------------------------------
wget -O /usr/local/freeswitch/sounds/en/us/callie/jonathan.wav  https://github.com/rodrigocuadra/Freeswitch-Stress-Test/raw/refs/heads/main/jonathan.wav
chmod 644 /usr/local/freeswitch/sounds/en/us/callie/jonathan.wav
chown freeswitch:freeswitch /usr/local/freeswitch/sounds/en/us/callie/jonathan.wav

# -------------------------------------------------------------
# Create SIP Account for Gateway Register
# -------------------------------------------------------------
echo -e "Create SIP Account for Gateway Register..."

ssh -p "$ssh_remote_port" root@$ip_remote 'cat <<EOF > /etc/freeswitch/directory/default/calltest.xml
<include>
  <user id="calltest">
    <params>
      <param name="password" value="test123"/>
    </params>
    <variables>
      <variable name="user_context" value="default"/>
    </variables>
  </user>
</include>
EOF'

# -------------------------------------------------------------
# Create dialplan for extension 9500 on remote server
# -------------------------------------------------------------
echo -e "Creating dialplan for 9500 on remote server..."

ssh -p $ssh_remote_port root@$ip_remote "wget -O /usr/local/freeswitch/sounds/en/us/callie/sarah.wav https://github.com/rodrigocuadra/Freeswitch-Stress-Test/raw/refs/heads/main/sarah.wav"
ssh -p $ssh_remote_port root@$ip_remote "chmod 644 /usr/local/freeswitch/sounds/en/us/callie/sarah.wav"
ssh -p $ssh_remote_port root@$ip_remote "chown freeswitch:freeswitch /usr/local/freeswitch/sounds/en/us/callie/sarah.wav"

ssh -p "$ssh_remote_port" root@$ip_remote 'cat <<EOF > /etc/freeswitch/dialplan/public/9500.xml
<extension name="stress-test-remote">
  <condition field="destination_number" expression="^9500$">
    <action application="answer"/>
    <action application="playback" data="/usr/local/freeswitch/sounds/en/us/callie/sarah.wav" loops="3"/>
    <action application="sleep" data="1000"/>
  </condition>
</extension>
EOF'

echo -e " *******************************************************************************************"
echo -e " *                        Restarting Freeswitch in remote Server                           *"
echo -e " *******************************************************************************************"
ssh -p $ssh_remote_port root@$ip_remote "systemctl restart freeswitch"
sleep 5

# -------------------------------------------------------------
# Create SIP Gateway to remote FreeSWITCH
# -------------------------------------------------------------
echo -e "Creating local SIP gateway configuration..."

cat <<EOF > /etc/freeswitch/sip_profiles/external/call-test-trk.xml
<gateway name="call-test-trk">
  <param name="username" value="calltest"/>
  <param name="password" value="test123"/>
  <param name="proxy" value="$ip_remote:5080"/>
  <param name="register" value="true"/>
  <param name="context" value="default"/>
</gateway>
EOF

echo -e " *******************************************************************************************"
echo -e " *                        Restarting Freeswitch in local Server                            *"
echo -e " *******************************************************************************************"
systemctl restart freeswitch

sleep 5
numcores=`nproc --all`
exitcalls=false
i=0
step=0
clear
freeswitch_version=$(fs_cli -x version | grep -oP '\d+\.\d+\.\d+')
echo -e " *****************************************************************************************************"
echo -e "                         Freeswitch (XML), Version: ${freeswitch_version}                             "
echo -e "     Actual Test State (Step: "$call_step_seconds"s, Core: "$numcores", Protocol: SIP(Sofia), Codec: "$codec_name", Recording: "$recording")     "
echo -e " *****************************************************************************************************"
echo -e " -----------------------------------------------------------------------------------------------------"
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
			echo -e "\e[92m -----------------------------------------------------------------------------------------------------"
		fi
		if [ "$cpu" -ge 35 ] && [ "$cpu" -lt 65 ] ;then
			echo -e "\e[93m -----------------------------------------------------------------------------------------------------"
		fi
		if [ "$cpu" -ge 65 ] ;then
			echo -e "\e[91m -----------------------------------------------------------------------------------------------------"
		fi
		printf "%2s %7s %10s %21s %10s %10s %10s %12s %12s\n" "|" " "$step" |" ""$i" |" ""$activecalls" |" ""$cpu"% |" ""$load" |" ""$memory" |" ""$bwtx" |" ""$bwrx" |"
                echo -e "$i, $activecalls, $cpu, $load, $memory, $bwtx, $bwrx, $seconds" >> data.csv

                if [ "$json_output_enabled" = "yes" ]; then
                    timestamp=$(date --iso-8601=seconds)
                    echo "{\"step\": $step, \"calls\": $i, \"active_calls\": $activecalls, \"cpu\": $cpu, \"load\": \"$load\", \"memory\": \"$memory\", \"bw_tx\": $bwtx, \"bw_rx\": $bwrx, \"timestamp\": \"$timestamp\"}" >> /tmp/progress.jsonl
                fi
  
		exitstep=false
		x=1
		while [ $exitstep = 'false' ]  
        	do
			let x=x+1
			if [ "$call_step" -lt $x ] ;then
				exitstep=true
			fi
   
			base_params="ignore_early_media=true,origination_caller_id_number=9600,absolute_codec_string=$codec_name"
                        if [ "$recording" = "yes" ]; then
                            timestamp=$(date +%s%N)
                            recording_file="/tmp/stress_test_${x}_${timestamp}.wav"
			    originate_string="{${base_params},execute_on_answer=record_session:$recording_file}sofia/gateway/call-test-trk/9500 &playback(jonathan.wav)"
                        else
                            originate_string="{${base_params}}sofia/gateway/call-test-trk/9500 &playback(jonathan.wav)"
                        fi
                        fs_cli -x "originate $originate_string" >/dev/null 2>&1

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
		sleep 1
	done
echo -e "\e[39m -----------------------------------------------------------------------------------------------------"
echo -e " *****************************************************************************************************"
echo -e " *                                      Restarting Freeswitch                                        *"
echo -e " *****************************************************************************************************"
systemctl restart freeswitch
ssh -p $ssh_remote_port root@$ip_remote "systemctl restart freeswitch"

echo -e "\n\033[1;32m✅ Test complete. Results saved to data.csv\033[0m"
echo -e " *****************************************************************************************************"
echo -e " *                                         Summary Report                                            *"
echo -e " *****************************************************************************************************"
echo -e "\n\033[1;34mGenerating summary from data.csv...\033[0m"

if [ -f data.csv ]; then
    tail -n +2 data.csv | awk -F',' -v dur="$call_duration" '
    BEGIN {
        max_cpu=0; sum_cpu=0; count=0;
        max_calls=0; sum_calls=0;
        sum_bw_per_call=0;
    }
    {
        cpu = $3 + 0;
        calls = $2 + 0;
        tx = $5 + 0;
        rx = $6 + 0;
        bw_per_call = (calls > 0) ? (tx + rx) / calls : 0;

        if(cpu > max_cpu) max_cpu = cpu;
        if(calls > max_calls) max_calls = calls;

        sum_cpu += cpu;
        sum_calls += calls;
        sum_bw_per_call += bw_per_call;
        count++;
    }
    END {
        avg_cpu = (count > 0) ? sum_cpu / count : 0;
        avg_calls = (count > 0) ? sum_calls / count : 0;
        avg_bw = (count > 0) ? sum_bw_per_call / count : 0;
        est_calls_per_hour = (dur > 0) ? max_calls * (3600 / dur) : 0;

        printf("\n📊 Summary:\n");
        printf("• Max CPU Usage.......: %.2f%%\n", max_cpu);
        printf("• Average CPU Usage...: %.2f%%\n", avg_cpu);
        printf("• Max Concurrent Calls: %d\n", max_calls);
        printf("• Average Calls/Step..: %.2f\n", avg_calls);
        printf("• Average BW/Call.....: %.2f kb/s\n", avg_bw);
        printf("• ➕ Estimated Calls/hour (duration ~%ds): %.0f\n", dur, est_calls_per_hour);
    }'

    # ✅ Append system info
    echo -e "\n🧠 CPU Info:"
    lscpu | grep -E 'Model name|^CPU\(s\)|CPU MHz' | grep -v NUMA

    echo -e "\n💾 RAM Info:"
    free -h | awk '/^Mem:/ {print "Total Memory: " $2}'

else
    echo "❌ data.csv not found."
fi

echo -e "***************************************************************************************************"
echo -e "*                                       Test Complete                                             *"
echo -e "*                                  Result in data.csv file                                        *"
echo -e "***************************************************************************************************"
echo -e "${NC}"
