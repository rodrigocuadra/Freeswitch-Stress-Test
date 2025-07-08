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
#
# Version:      1.1 for FreeSWITCH 1.10.12
# Date:         June 28, 2025
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

AUTO_MODE=false
WEB_NOTIFY=false
SKIP_CONFIG=false
for arg in "$@"
do
    case $arg in
        --auto|--no-confirm)
            AUTO_MODE=true
            echo "✅ Auto mode enabled: running with config.txt only, no prompts."
            ;;
        --notify)
            WEB_NOTIFY=true
            echo "📡 Web notify enabled: full reporting to server 5."
            ;;
	--skip-config)
            SKIP_CONFIG=true
            echo "📡 Skip configuration: Go straight to the test."
            ;;
        *)
            echo "⚠️ Unknown argument: $arg"
            ;;
    esac
done

# Read configuration from config.txt if it exists
filename="config.txt"
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
					web_notify_url_base=$line
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
                if [ "$WEB_NOTIFY" = true ]; then
                    echo -e "Web server URL base (e.g., http://192.168.5.5:8000)... >  $web_notify_url_base"
                fi
	fi

if [ "$AUTO_MODE" = false ]; then

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

	if [ "$WEB_NOTIFY" = true ]; then
            while [[ -z $web_notify_url_base ]]; do
                    read -p "Web server URL base (e.g., http://192.168.5.5:8000)... > " web_notify_url_base
            done
        fi
	
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
  
                if [ "$WEB_NOTIFY" = true ]; then
     	            while [[ -z $web_notify_url_base ]]; do
                            read -p "Web server URL base (e.g., http://192.168.5.5:8000)... > " web_notify_url_base
                    done
		fi
         fi
else
    echo "🚀 Skipping confirmation. Proceeding with loaded config."
fi

echo -e "$ip_local" 		> config.txt
echo -e "$ip_remote" 		>> config.txt
echo -e "$ssh_remote_port"	>> config.txt
echo -e "$interface_name" 	>> config.txt
echo -e "$codec" 		>> config.txt
echo -e "$recording" 		>> config.txt
echo -e "$maxcpuload"     	>> config.txt
echo -e "$call_step" 		>> config.txt
echo -e "$call_step_seconds" 	>> config.txt
echo -e "$call_duration" 	>> config.txt
if [ "$WEB_NOTIFY" = true ]; then
    echo -e "$web_notify_url_base"    >> config.txt
else
    echo -e "None" 	              >> config.txt  
fi

test_type="freeswitch"
info_url="${web_notify_url_base}/api/info"
progress_url="${web_notify_url_base}/api/progress"
explosion_url="${web_notify_url_base}/api/explosion"


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

if [ "$AUTO_MODE" = false ]; then
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
for i in {1..15}; do
    if ssh -p $ssh_remote_port root@$ip_remote "fs_cli -x 'status' &>/dev/null"; then
        # echo "✅ FreeSWITCH está operativo en $ip_remote"
        break
    else
        # echo "⏳ Esperando que FreeSWITCH se levante... ($i/15)"
        sleep 1
    fi
done
#sleep 5

# -------------------------------------------------------------
# Create SIP Gateway to remote FreeSWITCH
# -------------------------------------------------------------
echo -e "Creating local SIP gateway configuration..."

cat > /etc/freeswitch/sip_profiles/external/call-test-trk.xml <<EOF
<gateway name="call-test-trk">
  <param name="username" value="calltest"/>
  <param name="password" value="test123"/>
  <param name="proxy" value="$ip_remote:5080"/>
  <param name="register" value="true"/>
  <param name="context" value="default"/>
</gateway>
EOF
fi

echo -e " *******************************************************************************************"
echo -e " *                        Restarting Freeswitch in local Server                            *"
echo -e " *******************************************************************************************"
systemctl restart freeswitch
for i in {1..15}; do
    if fs_cli -x "status" &>/dev/null; then
        # echo "✅ FreeSWITCH está operativo localmente"
        break
    else
        # echo "⏳ Esperando que FreeSWITCH levante... ($i/15)"
        sleep 1
    fi
done
#sleep 5

echo -e "*****************************************************************************************"
echo -e "*                                  Start stress test                                    *"
echo -e "*****************************************************************************************"
numcores=`nproc --all`
exitcalls=false
i=0
step=0
total_elapsed=0
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
# slepcall=$(printf %.2f "$((1000000000 * call_step_seconds / call_step))e-9")
# Convert call_step_seconds to milliseconds
target_ms=$((call_step_seconds * 1000))

# Obtains information about the Freeswitch version and hardware characteristics.
if [ "$web_notify_url_base" != "" ] && [ "$WEB_NOTIFY" = true ]; then

    # Get FreeSWITCH version number only (e.g., 1.10.12)
    FREESWITCH_VERSION=$(fs_cli -x 'version' | awk '{print $3}' | cut -d'-' -f1)

    # Get the total number of logical CPU cores
    CPU_CORES=$(lscpu | grep "^CPU(s):" | awk '{print $2}')

    # Get the CPU model and speed (e.g., Intel(R) Xeon(R) CPU E5-2630 v4 @ 2.20GHz)
    CPU_MODEL=$(lscpu | grep "BIOS Model name:" | sed -E 's/BIOS Model name:\s+//')

    # Get total system memory (RAM) in human-readable format (e.g., 32G)
    TOTAL_RAM=$(free -h | awk '/^Mem:/ {print $2}')

    # Sends information about the hardware features and Freswitch version
    curl --silent --output /dev/null --write-out '' -X POST "$info_url" \
        -H "Content-Type: application/json" \
        -d "{
	    \"test_type\": \"$test_type\",
            \"freeswitch_version\": \"$FREESWITCH_VERSION\",
            \"core_cpu\": \"$CPU_CORES\",
            \"cpu_model\": \"$CPU_MODEL\",
            \"total_ram\": \"$TOTAL_RAM\",
            \"timestamp\": \"$(date --iso-8601=seconds)\"
        }" &
fi

sleep 1
echo -e "step, calls, active calls, cpu load (%), memory (%), bwtx (kb/s), bwrx (kb/s), delay (ms)" > data.csv

while [ "$exitcalls" = "false" ]; do
    R2=$(cat /sys/class/net/"$interface_name"/statistics/rx_bytes)
    T2=$(cat /sys/class/net/"$interface_name"/statistics/tx_bytes)
    date2=$(date +"%s")
    diff=$((date2 - date1))
    seconds=$((diff % 60))
    T2=$((T2 + 128))
    R2=$((R2 + 128))
    TBPS=$((T2 - T1))
    RBPS=$((R2 - R1))
    TKBPS=$((TBPS / 128))
    RKBPS=$((RBPS / 128))
    bwtx=$((TKBPS / seconds))
    bwrx=$((RKBPS / seconds))
    activecalls=$(fs_cli -x "show channels count" | grep total | awk '{print $1}')
    load=$(cat /proc/loadavg | awk '{print $1}')
    cpu=`top -n 1 | awk 'FNR > 7 {s+=$10} END {print s}'`
    cpuint=${cpu%.*}
    cpu="$((cpuint/numcores))"
    memory=$(free | awk '/Mem:/ {used=$3; total=$2} END {if (total>0) printf("%.2f%%", used/total*100); else print "N/A"}')

    # Color-code output based on CPU load
    if [ "$cpu" -le 34 ]; then
        echo -e "\e[92m  ---------------------------------------------------------------------------------------------------"
    elif [ "$cpu" -ge 35 ] && [ "$cpu" -lt 65 ]; then
        echo -e "\e[93m  ---------------------------------------------------------------------------------------------------"
    else
        echo -e "\e[91m  ---------------------------------------------------------------------------------------------------"
    fi
    printf "%2s %7s %10s %21s %10s %10s %10s %12s %12s\n" "|" " "$step" |" ""$i" |" ""$activecalls" |" ""$cpu"% |" ""$load" |" ""$memory" |" ""$bwtx" |" ""$bwrx" |"
    echo -e "$i, $activecalls, $cpu, $load, $memory, $bwtx, $bwrx, $total_elapsed" >> data.csv
    
    if [ "$web_notify_url_base" != "" ] && [ "$WEB_NOTIFY" = true ]; then
        curl --silent --output /dev/null --write-out '' -X POST "$progress_url" \
            -H "Content-Type: application/json" \
            -d "{
                \"test_type\": \"$test_type\",
                \"ip\": \"$ip_local\",
                \"step\": $step,
                \"calls\": $i,
                \"active_calls\": $activecalls,
                \"cpu\": $cpu,
                \"load\": \"$load\",
                \"memory\": \"$memory\",
		\"total_elapsed\": \"$total_elapsed\",
                \"bw_tx\": $bwtx,
                \"bw_rx\": $bwrx,
                \"timestamp\": \"$(date --iso-8601=seconds)\"
            }" &
    fi
  
    exitstep=false
    x=1
    total_elapsed=0
    while [ $exitstep = 'false' ] ; do
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
        call_start=$(date +%s%3N)
        fs_cli -x "originate $originate_string" >/dev/null 2>&1
	call_end=$(date +%s%3N)
        call_elapsed=$((call_end - call_start))
        total_elapsed=$((total_elapsed + call_elapsed))
    done

    # Calculate how much sleep you need if necessary
    if [ "$total_elapsed" -lt "$target_ms" ]; then
        sleep_ms=$((target_ms - batch_elapsed_ms))
        sleep_sec=$(awk "BEGIN { printf(\"%.3f\", $sleep_ms / 1000) }")
        sleep "$sleep_sec"
    fi
    
    let step=step+1
    let i=i+"$call_step"
    if [ "$cpu" -gt "$maxcpuload" ] ;then
        exitcalls=true
        if [ "$web_notify_url_base" != "" ] && [ "$WEB_NOTIFY" = true ]; then
            # echo "🔥 Threshold reached ($cpu%). Notifying control server..."
            curl --silent --output /dev/null --write-out '' -X POST "$explosion_url" \
                 -H "Content-Type: application/json" \
                 -d "{
                 \"test_type\": \"$test_type\",
                 \"ip\": \"$ip_local\",
                 \"cpu\": $cpu,
                 \"active_calls\": $activecalls,
                 \"step\": $step,
                 \"timestamp\": \"$(date --iso-8601=seconds)\"
                 }" &
 	         # echo "📤 Explosion request sent for $test_type (CPU: $cpu%, Active Calls: $activecalls)"
        fi
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
for i in {1..15}; do
    if fs_cli -x "status" &>/dev/null; then
        echo "✅ FreeSWITCH está operativo localmente"
        break
    else
        echo "⏳ Esperando que FreeSWITCH levante... ($i/15)"
        sleep 1
    fi
done
ssh -p $ssh_remote_port root@$ip_remote "systemctl restart freeswitch"
for i in {1..15}; do
    if ssh -p $ssh_remote_port root@$ip_remote "fs_cli -x 'status' &>/dev/null"; then
        echo "✅ FreeSWITCH está operativo en $ip_remote"
        break
    else
        echo "⏳ Esperando que FreeSWITCH se levante... ($i/15)"
        sleep 1
    fi
done

echo -e "\n\033[1;32m✅ Test complete. Results saved to data.csv\033[0m"
echo -e "***************************************************************************************************"
echo -e "*                                     Summary Report                                              *"
echo -e "***************************************************************************************************"
echo -e "\n${BLUE}Generating summary from data.csv...${NC}"

if [ -f data.csv ]; then
    tail -n +2 data.csv | awk -F',' -v dur="$call_duration" '
    BEGIN {
        max_cpu=0; sum_cpu=0; count=0;
        max_calls=0; sum_calls=0;
        sum_bw_per_call=0;
        total_batch_delay = 0;
        total_calls = 0;
    }
    {
        cpu = $3 + 0;
        calls = $2 + 0;
        tx = $6 + 0;
        rx = $7 + 0;
        elapsed = $8 + 0;

        # Bandwidth per call (includes both legs: TX + RX)
        bw_per_call = (calls > 0) ? (tx + rx) / calls : 0;

        if(cpu > max_cpu) max_cpu = cpu;
        if(calls > max_calls) max_calls = calls;

        sum_cpu += cpu;
        sum_calls += calls;
        sum_bw_per_call += bw_per_call;
        total_batch_delay = total_batch_delay + elapsed;
        count++;
    }
    END {
        avg_cpu = (count > 0) ? sum_cpu / count : 0;
        avg_calls = (count > 0) ? sum_calls / count : 0;
        avg_bw = (count > 0) ? sum_bw_per_call / count : 0;
        est_calls_per_hour = (dur > 0) ? max_calls * (3600 / dur) : 0;
        avg_delay_per_call = (total_batch_delay > 0) ? total_batch_delay / max_calls : 0;

        printf("\n📊 Summary:\n");
        printf("• Max CPU Usage..................: %.2f%%\n", max_cpu);
        printf("• Average CPU Usage..............: %.2f%%\n", avg_cpu);
        printf("• Max Concurrent Calls...........: %d\n", max_calls);
        printf("• Average Bandwidth/Call.........: %.2f kb/s (TX + RX)\n", avg_bw);
        printf("• ⏱️ Total Originate Delay........: %.0f ms\n", total_batch_delay);
        printf("• ⌛ Avg Delay per Call..........: %.2f ms\n", avg_delay_per_call);
	printf("• ➕ Estimated Calls/Hour (~%ds): %.0f\n", dur, est_calls_per_hour);
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
