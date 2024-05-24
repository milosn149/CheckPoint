#!/bin/bash

i=0;
date="$1"

if [ $1 -n ]; then
   date=`date +%d\ %b`
   echo "Using \"$date\" because no parameter found!"
   echo
fi

echo "TED statistics for $date per hour:"
echo "============================="
echo -ne "Hour\tScans\tMalware\tClean\n"
echo "============================="

while [ $i -lt 24 ]; do
   echo -ne "$i\t";
   if [ $i -lt 10 ];
      then
         j=" $i";
      else j="$i";
   fi;

   day_sum=`grep "Handling new file" $FWDIR/log/ted.elg* | grep "$date $j" | wc -l;`
   day_drop=`grep "Reporting back action: drop" $FWDIR/log/ted.elg* | grep "$date $j" | wc -l;`
   day_accept=`grep "Reporting back action: accept" $FWDIR/log/ted.elg* | grep "$date $j" | wc -l;`

   echo -ne "$day_sum\t$day_drop\t$day_accept\n"

   i=$((i+1));
done

echo "============================="
echo "Overall TED statistics"
echo "============================="
tecli s t mi
tecli s t h
tecli s t d
tecli s t mo
echo "============================="

# grep -h "Starting periodic update process" $FWDIR/log/ted.elg* | grep "$date" | sort -t\[ -k2
