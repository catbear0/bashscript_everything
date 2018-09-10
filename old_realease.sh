#!/bin/sh -x
###################################################################
############|  ATTENTION!!! This file wasn't generated automatically.  |############
############|     Because ansible doesn't like old FreeBSD releases    |############
############|          Editable copies recide in /home/itsumma         |############
###################################################################
export TZ=Europe/Moscow
DT=$(date +"%Y-%m-%d-%H%M%S")
LOG=/backup/files_default.log
ERROR_LOG=/backup/error.log
FN=files_default_${DT}.tgz
DIR=/backup/files
RPATH=/backup/files
SSH="${PROJECT}@111.201.11.113" 
CONNECT="ssh -o StrictHostKeyChecking=no -o ConnectionAttempts=3 ${SSH}"
lockdir=/var/tmp/files_default_backup
pidfile=${lockdir}/pid

die() {
  exitcode=$?
  echo `date +"%Y-%m-%d-%H%M%S"` $1 rsync exitcode $exitcode >>${ERROR_LOG}
  exit 1
}

if ( mkdir ${lockdir} ) 2> /dev/null; then
  echo $$ > $pidfile
  trap 'rm -rf "$lockdir"; exit $?' INT TERM EXIT

  ${CONNECT} "/bin/mkdir -p ${RPATH}" >> /dev/null 2>&1

  /bin/getfacl /home/data/www/* > /home/acls.txt

  echo "[`date`] backup files default started" >>$LOG

  /usr/local/bin/rsync -a --exclude '/home/data/mod-tmp/*' --exclude 'sess_*' /home/data/www ${SSH}:${RPATH} --delete >>$LOG 2>&1 || die

  ${CONNECT} -t "cd ${RPATH}; /bin/tar --exclude-from='exclude-list.txt' -cvzf ${FN} data/" >>$LOG 2>&1 || die if_tar_failed

  echo "[`date`] backup files default finished" >>$LOG

  rm -rf "$lockdir"
  trap - INT TERM EXIT
else
  echo "Lock Exists: $lockdir owned by $(cat $pidfile)" >>$LOG && die files_default_lock
fi

