#!/bin/sh
#
# version 0.71
#

# shellcheck disable=SC1091
. /etc/profile.d/CP.sh

# shellcheck source=etc/icap-test.conf
. etc/icap-test.conf

#
# Test and create working environment
#
if [ ! -d "$workdir" ]
    then
        mkdir -p "$workdir"
fi

if [ ! -d "$logdir" ]
    then
        mkdir -p "$logdir"
fi

exit_clean() {
    rm -f "$lock_file"
    exit 0
}

if [ -f "$lock_file" ]; then
    echo "$timestamp, Lock file exists, exiting" >>"$logfile"
    exit 0
else
    trap exit_clean EXIT
    touch "$lock_file"
fi

#
# Functions
#
collect_files() {
    #echo "Collect debug files and restart ICAP processes..."
    mkdir -p "$workdir/icap-$suffix"
    #echo "Copying support files to dir $workdir/icap-$suffix"
    cp "$FWDIR"/log/c-icap/access* $workdir/icap-"$suffix" 
    cp "$FWDIR"/log/c-icap/server* $workdir/icap-"$suffix"
    cp $cpu_top $workdir/icap-"$suffix"
    cp /var/log/messages $workdir/icap-"$suffix"
    cp "$FWDIR"/c-icap/etc/c-icap.conf $workdir/icap-"$suffix"
    cp "$FWDIR"/state/local/AMW/local.set $workdir/icap-"$suffix"
    cp "$FWDIR"/state/__tmp/AMW/local.set $workdir/icap-"$suffix"
    tar cvzf "$workdir/icap-$suffix.tgz" "$workdir/icap-$suffix" >/dev/null 2>&1
    rm -rf "$workdir/icap-$suffix"
    #
    # Only copy for 1st look when troubleshooting
    #
    cp $cpu_top $cpu_top."$suffix"
}


#
# Collect CPU utilization of icap_server to $cpusum
#
top -H -w512 -d10 -b -n2 |
    awk '/^ *PID +USER +/ {headers++} headers==2' |
    grep "$process" >"$cpu_top"
sed -Ee 's/\s+/ /g' "$cpu_top" | cut -d " " -f9 >"$tmpout"

#
# Testing the utilization of ICAP processes
#
while read line; do
    icap_pid=$(echo "$line" | sed -Ee 's/\s+/ /g' | cut -d " " -f1)
    icap_cpu=$(echo "$line" | sed -Ee 's/\s+/ /g' | cut -d " " -f9 |
               awk '{total += $1} END { printf("%.0f\n", total) }')
    #echo "$icap_pid,$icap_cpu"
    if [ "$icap_cpu" -gt "90" ]; then
	echo "$timestamp,The $icap_cpu is higher than 90, send kill signal 9 to process with PID $icap_pid. Thread states are in $cpu_top.$suffix" >>$logfile
	kill "$icap_pid"; sleep 2; kill -9 "$icap_pid"
	icap_killed=true
	collect_files
	echo "The $icap_cpu is higher than 90, send kill signal 9 to process with PID $icap_pid. The support file has been collected and archived to $workdir/icap-$suffix.tgz" | $send_email_ntt
	echo "The $icap_cpu is higher than 90, send kill signal 9 to process with PID $icap_pid. The support file has been collected and archived to $workdir/icap-$suffix.tgz" | $send_email_moneta
    fi
done<$cpu_top

if [ -n "$icap_killed" ]; then
    exit 1
fi

cpusum=$(echo | awk '{total += $1} END { printf("%.0f\n", total)}' "$tmpout")
#echo $cpusum

if [ "$cpusum" -ge "$overcpu" ]; then
    collect_files
    #
    # $FWDIR/bin/icap_server reconf
    #
    "$FWDIR"/bin/icap_server restart
    #
    echo "$timestamp,The icap_server has been restarted. The support files has been collected and archived to $workdir/icap-$suffix.tgz" >>"$logfile"
    #
    # echo "Sending email to xxx"
    #
    echo "The icap_server has been restarted at $timestamp. The support files has been collected and archived to $workdir/icap-$suffix.tgz" | $send_email_ntt
    echo "The icap_server has been restarted at $timestamp. The support files has been collected and archived to $workdir/icap-$suffix.tgz" | $send_email_moneta
    exit 1
else
    #
    # Testing and logging the status of ICAP and AV processes
    #

    #
    # Run c-icap-client and when no response during 20 seconds, kill it.
    #
    timeout -k9 20 "$FWDIR"/c-icap/bin/c-icap-client -v -i "$icap_server" -f "$eicarfile" -req "$eicarfile" -x "X-Client-IP:$icap_server" -x "X-Server-IP:$icap_server" -x "X-Authenticated-User: VEVTVC1Vc2Vy" -s sandblast -nopreview >$icapout 2>&1

    if [ $? -eq 124 ]
	then
	    echo "$timestamp,The c-icap-client timeouted and killed." >>"$logfile"
    fi

    icapheader=$(sed -nE "s/^\s+(ICAP.*)$/\1/p" "$icapout")
    respmodhdr=$(sed -nE "s/^\s+(HTTP.*)$/\1/p" "$icapout")

    if ! echo "$respmodhdr" | grep -q ' 403 '
        then
            respmodhdr="$respmodhdr,AV is not working as expected. Eicar test file was not detected as malware."
            #echo "AV is not working as expected."
            #echo "Sending email to admins"
	    #
	    if [ ! -f "$email_malware_lock" ]
    		then
		    #
		    # Send notification email only once and collect support file when will be known
		    #
            	echo "The AV is not working as expected. Eicar test file was not detected as malware. Check the logfiles of icapt_test and $FWDIR/log/ted.elg." | $send_email_ntt
            	echo "The AV is not working as expected. Eicar test file was not detected as malware. Check the logfiles of icapt_test and $FWDIR/log/ted.elg." | $send_email_moneta
		        touch "$email_malware_lock"
                collect_files
	    fi
	else
            if [ -f "$email_malware_lock" ]
                then
                    #
                    # Send notification email only once if AV runs well again
                    #
	    	    echo "The AV is now working as expected." | $send_email_ntt
	    	    echo "The AV is now working as expected." | $send_email_moneta
	    	    rm "$email_malware_lock"
	    fi
    fi

    echo "$timestamp,$icapheader,$respmodhdr" >>$logfile
fi
