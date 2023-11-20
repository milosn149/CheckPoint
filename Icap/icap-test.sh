#!/bin/sh
#

# shellcheck disable=SC1091
. /etc/profile.d/CP.sh

. ./icap-test.source

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
# Testing the utilization of ICAP processes
#
#
#     top -H -w512 -d5 -b -n2 | awk '/^ *PID +USER +/ {headers++} headers==2'
#

#
# Collect CPU utilization of icap_server to $cpusum
#
top -H -w512 -d5 -b -n2 |
    awk '/^ *PID +USER +/ {headers++} headers==2' |
    grep "$process" | sed -Ee 's/\s+/ /g' | cut -d " " -f9 >"$tmpout"
cpusum=$(echo | awk '{total += $1} END { printf("%.0f\n", total)}' "$tmpout")
#echo $cpusum

if [ "$cpusum" -ge "$overcpu" ]; then
    #echo "Collect debug files and restart ICAP processes..."
    mkdir -p "$workdir/icap-$suffix"
    #echo "Copying support files to dir $workdir/icap-$suffix"
    cp "$FWDIR"/log/c-icap/access* "$workdir"/icap-"$suffix" 
    cp "$FWDIR"/log/c-icap/server* "$workdir"/icap-"$suffix"
    #sleep 3s
    tar cvzf "$workdir/icap-$suffix.tgz" "$workdir/icap-$suffix" >/dev/null 2>&1
    rm -rf "$workdir/icap-$suffix"
    #
    #$FWDIR/bin/icap_server reconf
    #
    "$FWDIR"/bin/icap_server restart
    echo "$timestamp,The icap_server has been restarted. The support files has been collected and archived to $workdir/icap-$suffix.tgz" >>"$logfile"
    #echo "Sending email to xxx"
    #echo "The icap_server has been restarted at $timestamp." | "$send_email" "$moneta_rcpt"
    echo "The icap_server has been restarted at $timestamp. The support files has been collected and archived to $workdir/icap-$suffix.tgz" | $send_email_ntt
    exit 1
else
    #
    # Testing and logging the status of ICAP and AV processes
    #
    #
    #timeout -k5 5 sleep 15
    #echo $?

    #echo "Continue to test AV"
    "$FWDIR"/c-icap/bin/c-icap-client -v -i 10.49.204.45 -f "$eicarfile" -req "$eicarfile" -x "X-Client-IP:10.49.204.45" -x "X-Server-IP:10.49.204.45" -x "X-Authenticated-User: VEVTVC1Vc2Vy" -s sandblast -nopreview >"$icapout" 2>&1

    #icapheader=$(grep -E "^ {8}ICAP" "$icapout" | sed "s/ {8}//g")
    #respmodhdr=$(grep -E "^ {8}HTTP" "$icapout" | sed "s/ {8}//g")
    #icapheader=$(sed -nE "s/^ {8}(ICAP.*)$/\1/p" "$icapout")
    #respmodhdr=$(sed -nE "s/^ {8}(HTTP.*)$/\1/p" "$icapout")
    icapheader=$(sed -nE "s/^\s+(ICAP.*)$/\1/p" "$icapout")
    respmodhdr=$(sed -nE "s/^\s+(HTTP.*)$/\1/p" "$icapout")

    if ! echo "$respmodhdr" | grep -q ' 403 '
        then
            respmodhdr="$respmodhdr,AV is not working as expected. Eicar test file was not detected as malware."
            #echo "AV is not working as expected."
            #echo "Sending email to admins"
            echo "The AV is not working as expected. Eicar test file was not detected as malware. Check the logfiles of icapt_test and $FWDIR/log/ted.elg." | "$send_email" "$ntt_rcpt"
    fi
    echo "$timestamp,$icapheader,$respmodhdr" >>"$logfile"
fi
