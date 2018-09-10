#!/bin/bash
set -x
period=$1
date=$(date '+%d-%m-%Y')
timeslot=$(date '+%d/%m/%Y %H:%M:%S')
logfile="/storage/its_backup/logs/mng.log"  
backup_dir="/storage/its_backup/dumps/mongo"
rmt_dir="/tmp/dumps"
dbhost="10.20.15.10"
dumpname="fbi_${date}.${period}"
mongodump="/usr/bin/mongodump"
ssh="user@10.20.15.10"
connect="ssh -t user@10.20.15.10"

die() {
  exitcode=$?
  echo ${timeslot} $1 exitcode $exitcode >>${logfile}
  exit 1
}

mkdir -p ${backup_dir}
touch $logfile  

echo "Backup fbi started at $timeslot" >> $logfile
${connect} "mongodump -v -o ${rmt_dir}" >>$logfile 2>&1 || die
${connect} "tar -czf ${rmt_dir}/${dumpname}.tgz ${rmt_dir}/*" >>$logfile 2>&1 || die
echo "Backup fbi finished at $timeslot" >> $logfile
rsync -a ${ssh}:/${rmt_dir}/${dumpname}.tgz ${backup_dir} >>$logfile 2>&1

rm -rvf ${rmt_dir}/* >>$logfile 2>&1

echo "Cleaning files" >> $logfile
/usr/bin/find  ${backup_dir}/ -type f -name '*daily.tgz' -mtime +2 -delete >>$logfile 2>&1
/usr/bin/find  ${backup_dir}/ -type f -name '*weekly.tgz' -mtime +90 -delete >>$logfile 2>&1
/usr/bin/find  ${backup_dir}/ -type f -name '*monthly.tgz' -mtime +1095 -delete >>$logfile 2>&1
