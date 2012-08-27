#!/bin/bash

PSPATH=/usr/local/phonescanner

DATE=`date '+%Y%m%d'`
HOSTS=$ARGV
USER=nagios
FILE=$PSPATH/output/polyscan-results.csv
SCRIPT=$PSPATH/polyscan.rb
USERS="bobby.smith@vocalocity.com drew.phebus@vocalocity.com"

execute_script() {
    nohup ./$SCRIPT 2>&1 > $PSPATH/logs/$ULDUMP-output.log &
}

fetch_userdump() {
    FILES=""
    for host in $HOSTS
    do
        ULDUMP=$PSPATH/dumps/$host-$DATE
        ssh $USERNAME@$host "/usr/local/opensips/sbin/opensipsctl fifo ul_dump" > $ULDUMP
        $FILES+=" $ULDUMP"
    done
}

process_ul() {
    for file in $FILES
    do
        $PSPATH/uldumptocsv.rb $file
    done
}

prepare_results() {
    sort -u -t, -k6,6 $FILE | sort -t, -k1,1 > $FILE-$DATE-unique.csv
    cp $PSPATH/output/$FILE-$DATE-unique.csv $PSPATH/output/polyscan-results.csv
    tar cvzf $PSPATH/output/results-$DATE.tar.gz $PSPATH/output/polyscan*
}

publish_results() {
    mutt -s "Polyscan Results $HOSTS $DATE" -a $PSPATH/output/results-$DATE.tar.gz $USERS < "Polyscan Results $HOSTS $DATE:\n Scanned: $HOSTS\n TIME: \nresults.tar.gz attached"
}

main() {
    fetch_userdump
    process_ul
    execute_script
    prepare_results
    publish_results
}

main
