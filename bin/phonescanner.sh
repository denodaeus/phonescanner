#!/bin/bash

PSPATH=/usr/local/phonescanner

DATE=`date '+%Y%m%d%H%M'`
HOSTS="$@"
USER=nagios
FILE=$PSPATH/output/polyscan-results.csv
SCRIPT=$PSPATH/polyscan.rb
USERS="bobby.smith@vocalocity.com drew.phebus@vocalocity.com"
LOG=$PSPATH/logs/polyscan.log.$DATE
USERNAME=root

execute_script() {
    nohup ./$SCRIPT 2>&1 > $PSPATH/logs/$ULDUMP-output.log &
}

fetch_userdump() {
    echo "fetch_userdump() :: fetching user loc data for $HOSTS" >> $LOG
    FILES=()
    for host in $HOSTS
    do
        echo "Fetching file for $host to $host-$DATE ..." >> $LOG
        ULDUMP=$PSPATH/dumps/$host-$DATE
        ssh $USERNAME@$host "/usr/local/opensips/sbin/opensipsctl fifo ul_dump" > $ULDUMP
        FILES+=( "$ULDUMP" )
    done
    echo "captured ${FILES[@]} ul's" >> $LOG
}

process_ul() {
    for file in ${FILES[@]}
    do
        echo "process_ul() :: processing file $file into uldumptocsv format ..." >> $LOG
        $PSPATH/uldumptocsv.rb $file
    done
}

merge_files() {
	$PSPATH/proxymerge.rb
}

generate_html() {
	$PSPATH/makehtml.rb
}

prepare_results() {
    sort -u -t, -k6,6 $FILE | sort -t, -k1,1 > $FILE-$DATE-unique.csv
    cp $PSPATH/output/$FILE-$DATE-unique.csv $PSPATH/output/polyscan-results.csv
    generate_html
    tar cvzf $PSPATH/output/results-$DATE.tar.gz $PSPATH/output/polyscan*
}

publish_results() {
    mutt -s "Polyscan Results $HOSTS $DATE" -a $PSPATH/output/results-$DATE.tar.gz $USERS < "Polyscan Results $HOSTS $DATE:\n Scanned: $HOSTS\n TIME: \nresults.tar.gz attached"
}

main() {
    echo "Executing run for $LOG ..." >> $LOG
    fetch_userdump
    process_ul
    merge_files
    execute_script
    prepare_results
    publish_results
}

main
