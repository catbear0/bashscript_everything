#!/bin/bash
set -x
USERNAME="user"
PASSWORD="password"
SERVER="222.111.11.2"
DATE="$(date +%Y-%m-%d)"
BACKUPDIR="/${DATE}/"
SRC_DIR="/home/bitrix/www/bitrix/backup/"

cd $SRC_DIR
#FILES=$(find "${SRC_DIR}" -mtime -1 -mmin +59 -type f -name "*.tar.gz*" -exec basename \{} . \;)
FILES=$(find "${SRC_DIR}" -type f -name "*$(date +%Y%m%d)*tar.gz*" -exec basename \{} . \;)

for file in ${FILES}; do
    /bin/ftp -inv $SERVER >> /tmp/ftp.log <<EOF
user $USERNAME $PASSWORD
mkdir $BACKUPDIR
cd $BACKUPDIR
put $file
EOF

done
