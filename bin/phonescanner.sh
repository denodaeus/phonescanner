#!/bin/bash

PSPATH=/usr/local/phonescanner

DATE=`date '+%Y%m%d%H%M'`
HOSTS="$@"
USER=nagios
FILE=$PSPATH/output/polyscan-results.csv
SCRIPT=$PSPATH/polyscan.rb
USERS="TSLeaders@vocalocity.com,bobby.smith@vocalocity.com,randy.layman@vocalocity.com,neo-internal@vocalocity.com"
LOG=$PSPATH/logs/polyscan.log.$DATE
USERNAME=root

function echo {
  /bin/echo `hostname` `date` $* >> $LOG
}

execute_script() {
    cd $PSPATH
    echo "running polyscan ..."
    $SCRIPT 2>&1 > $PSPATH/logs/$ULDUMPNAME-output.log &
    wait
}

fetch_userdump() {
    echo "fetch_userdump() :: fetching user loc data for $HOSTS"
    FILES=()
    for host in $HOSTS
    do
        echo "Fetching file for $host to $host-$DATE ..."
        ULDUMPNAME=$host-$DATE
        ULDUMP=$PSPATH/dumps/$ULDUMPNAME
        ssh $USERNAME@$host "/usr/local/opensips/sbin/opensipsctl fifo ul_dump" > $ULDUMP
        FILES+=( "$ULDUMP" )
    done
    echo "captured ${FILES[@]} ul's"
}

process_ul() {
    PARSED_FILES=()
    for file in ${FILES[@]}
    do
        echo "process_ul() :: processing file $file into uldumptocsv format ..."
        $PSPATH/uldumptocsv.rb $file
        PARSED_FILES+=("$file-parsed.csv")
    done
    echo "process_ul() :: processing files completed, parsed files= ${PARSED_FILES[@]}"
}

merge_files() {
  echo "merge_files() :: executing script $PSPATH/proxymerge.rb ${PARSED_FILES[@]}"
	$PSPATH/proxymerge.rb ${PARSED_FILES[@]}
}

generate_html() {
	$PSPATH/makehtml.rb
}

prepare_results() {
    sort -u -t, -k6,6 $FILE | sort -t, -k1,1 > $FILE-$DATE-unique.csv
    cp $FILE-$DATE-unique.csv $PSPATH/output/polyscan-results.csv
    generate_html
    tar cvzf $PSPATH/output/results-$DATE.tar.gz $PSPATH/output/polyscan*
    echo "prepare_results() :: results are contained in : `ls -ltr $PSPATH/output/results-$DATE.tar.gz`"
}

publish_results() {

    echo -e "Polyscan Results $HOSTS $DATE:\n Scanned: $HOSTS\n TIME: \nresults.tar.gz attached" | mutt -s "Polyscan Results $HOSTS $DATE" -a $PSPATH/output/results-$DATE.tar.gz $USERS 
}

main() {
    echo "Executing run for $LOG ..."
    fetch_userdump
    process_ul
    merge_files
    execute_script
    prepare_results
    publish_results
}

main
