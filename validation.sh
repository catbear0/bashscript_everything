#!/bin/bash
set -x

IPS_MAIN=(192.168.0.2 192.168.0.3)
IPS_0=(192.168.1.2 192.168.1.4)
WORKDIR="/backup/check_dir"
REMOTE_DIR="/opt/db/backup/"
DATE=`date +"%Y%m%d"`
DATADIR="/opt/db/mysql"
REMOTE_DATADIR="/opt/db/mysql"
#REMOTE_DATADIR=$(grep -R datadir /etc/my.cnf | awk '{ print $3 }')
socket=/var/www/mysql/data/mysql.sock

GZ_LIST="find $REMOTE_DIR -type f -name '*.sql.gz' -mtime -1"
SSH_LOG="ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no -o ConnectionAttempts=3 root@192.168.0.4"
MYSQL_CMD="mysql --defaults-extra-file=/root/.my.cnf -Nse "
CHECK_LOG=/backup/check_mysqldump.txt
LOG_DB_SIZE=/backup/check_mysqldump_size.txt

main () {
  cd $WORKDIR
  ulimit -n 102400

  for ip in ${IPS_MAIN[@]}; do
    transfer
    create_dump
    run_test
  done
}

transfer () {
    for gz in $(ssh root@$ip "$GZ_LIST"); do
      rsync root@${ip}:${gz} $WORKDIR/
    done
}

create_dump () {
    for sql in $(ls -1 $WORKDIR); do
      printf "####### STARTING JOB #######\n"
      gzip -dc $WORKDIR/${sql} > $(ls -1 "$WORKDIR/$sql" | sed 's/\./ /g' | awk '{print $1}') 2>>$CHECK_LOG
      sed -i '/^$/d' $CHECK_LOG
      rm -f $WORKDIR/$sql
    done
}

run_test () {
    for dump in $(ls -1 $WORKDIR); do
      $MYSQL_CMD "RESET MASTER;" #fast way to clean gtid_executed
      $MYSQL_CMD "DROP DATABASE IF EXISTS ${dump};"
      $MYSQL_CMD "CREATE DATABASE ${dump};"
      mysql $dump < $dump

      R_SIZE=$(${MYSQL_CMD} 'SELECT table_schema ,sum(data_length)/1024 FROM information_schema.TABLES GROUP BY table_schema;' | grep ${dump} | awk '{print $2}')
      S_SIZE=$(${SSH_LOG} "cat /var/backup/mysql-dump/${dump}.txt" | sed -n '1p')

      if [ -n "${S_SIZE}" ]; then
        DIFF_PERCENT=$(echo "scale=2; (${R_SIZE}/${S_SIZE}*100)-100" | bc | cut -d . -f 1)
        MOD_DIFF_PERCENT=$(echo ${DIFF_PERCENT} | sed 's/-//')
        if [ "$MOD_DIFF_PERCENT" -gt 30 ] && [ "$R_SIZE" != 0 ]; then
          echo "[`date`] ${dump}: Databases diff size is more than 30 % (src_size: $S_SIZE Kb, restored_size: $R_SIZE Kb, diff: $MOD_DIFF_PERCENT%)" >> $LOG_DB_SIZE
        fi
      fi

      MYSQL_TBL=$(${MYSQL_CMD} "SHOW TABLES FROM ${dump};" | head -n1)
      MYSQL_TBL_CNT=$(${MYSQL_CMD} "SHOW TABLES FROM ${dump};" | wc -l)
      MYSQL_TBL_SELECT_CNT=$(${MYSQL_CMD} "USE ${dump}; SELECT * FROM ${MYSQL_TBL};" | wc -l)

      MYSQL_REMOTE_TBL_CNT=$(${SSH_LOG} "cat /var/backup/mysql-dump/${dump}.txt" | sed -n '2p')
      MYSQL_REMOTE_TBL_SELECT_CNT=$(${SSH_LOG} "cat /var/backup/mysql-dump/${dump}.txt" | sed -n '3p')

      if [ "${MYSQL_TBL_CNT}" != "${MYSQL_REMOTE_TBL_CNT}" ]; then
        echo "[`date`] ${dump}: Tables count did not match in database" >> $CHECK_LOG
      fi

      if [ "${MYSQL_TBL_SELECT_CNT}" != "${MYSQL_REMOTE_TBL_SELECT_CNT}" ]; then
        echo "[`date`] ${dump}: Columns count did not match at least at table ${MYSQL_TBL}" >> $LOG_DB_SIZE
      fi

      $MYSQL_CMD "DROP DATABASE ${dump};"
      rm -vf $WORKDIR/$dump 
      printf "\n####### END LOGGING $dump #######\n\n\n\n"
    done
}

custom () {
    ulimit -n 102400
    
    if [ "$(ip)" = "192.168.1.2" ] ; then
	R_DATADIR="/opt/db/mysql"
	
	elif [ "$(ip)" = "192.168.1.4" ] ; then
	R_DATADIR="/var/lib/mysql/data/"
	
	fi
    
    for ip in ${IPS_0[@]}; do
      systemctl stop mysqld.service
      rm -r $DATADIR
      mkdir -p $DATADIR
      rsync -I root@${ip}:${R_DATADIR}/ $DATADIR/
      chown -R mysql:mysql $DATADIR/
      \cp /root/scripts/${ip}.cnf /root/.my.cnf
      \cp /root/scripts/my_${ip}.cnf /etc/my.cnf
      systemctl start mysqld.service
      
      transfer
      create_dump
      run_test
    done
       
    systemctl stop mysqld.service
    \cp /etc/my.cnf.back /etc/my.cnf
    systemctl start mysqld.service
}

test -d "/tmp" || {
  echo "/tmp" is not a directory
  exit
}

test -f "/tmp/script.lock" && lsof -n "/tmp/script.lock" | awk '{ print $2 }' >$0 || {
  echo $0 is already running in "/tmp" directory
  exit
}
> "/tmp/script.lock"

main "/tmp"

custom "/tmp"

rm -f "/tmp/script.lock"
