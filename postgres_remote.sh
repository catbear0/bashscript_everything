#!/bin/bash
set -x
period=$1
timeslot=$(date +"%Y-%m-%d-%H%M%S")
logfile="/storage/its_backup/logs/production.log"
backup_dir="/storage/its_backup/dumps/postgres"
rmt_dir="/tmp/dumps"
dbhost="10.20.15.100"
dbuser="postgres"
database="production"
pg_bin_folder="/usr/lib/postgresql/9.6/bin"
pgdump="${pg_bin_folder}/pg_dump"
ssh="ssh root@10.20.15.100 -o StrictHostKeyChecking=no -o ConnectionAttempts=3"
connect="ssh -t root@10.20.15.100"

die() {
  exitcode=$?
  echo ${timeslot} $1 exitcode $exitcode >>${logfile}
  exit 1
}

mkdir -p ${backup_dir}
touch $logfile

echo "Backup production started at $timeslot" >> $logfile
${connect} "su postgres -c vacuumdb -z -h ${dbhost} -U ${dbuser} -D ${database}" >/dev/null 2>&1
${connect} "su postgres -c '${pgdump} -U ${dbuser} ${database}' | gzip > ${rmt_dir}/${database}-${timeslot}_${period}.sql.gz" || die
echo "Backup production finished at $timeslot" >> $logfile
rsync -a -e ${ssh}:/${rmt_dir}/${database}-${timeslot}_${period}.sql.gz ${backup_dir}

echo "Cleaning files" >>${logfile}
${connect} "/usr/bin/find  ${rmt_dir}/ -type f -name '*.sql.gz' -mtime +15 -delete"
/usr/bin/find  ${backup_dir}/ -type f -name '*daily.sql.gz' -mtime +2 -delete
/usr/bin/find  ${backup_dir}/ -type f -name '*weekly.sql.gz' -mtime +90 -delete
/usr/bin/find  ${backup_dir}/ -type f -name '*monthly.sql.gz' -mtime +1095 -delete

