#!/bin/bash
set -x

logfile=/root/scripts/docker_clean.log

docker ps -a | grep 'day' | while read line; do
     id=$(echo $line | awk '{print $1}');
     echo $line >>$logfile;
     docker rm -f ${id} 2>>$logfile;
done

find /backup -maxdepth 1 -mindepth 1 -type d -name "${id}*" -mtime +2 -exec rm -rf {} \; >>$logfile
