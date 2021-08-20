#!/bin/bash
#
# Copy and then run this script on a new machine to establish backups
# Then update the corresponding config files and then run push-config.sh when updated
#

if [ ! -f ./config.sh ]
then
  echo "Please enter the hostname of the backup server:"
  read BACKUP_TARGET_HOST
  echo "Please enter the root directory of backups on the backup server:"
  read BACKUP_TARGET_BASE
  echo "#!/bin/bash" > ./config.sh
  echo "BACKUP_TARGET_HOST=${BACKUP_TARGET_HOST}" >> ./config.sh
  echo "BACKUP_TARGET_BASE=${BACKUP_TARGET_BASE}" >> ./config.sh
fi

. ./config.sh

LOCAL_BACKUPS_DIR=~/.backups
BACKUP_SOURCE_HOST=$(hostname -s)

LOCAL_CONFIG_DIR=${LOCAL_BACKUPS_DIR}/config
BACKUP_INCLUDES=${LOCAL_CONFIG_DIR}/backup-${BACKUP_SOURCE_HOST}-includes.txt
BACKUP_EXCLUDES=${LOCAL_CONFIG_DIR}/backup-${BACKUP_SOURCE_HOST}-excludes.txt

# Copy this hosts config files
scp ${BACKUP_INCLUDES} ${BACKUP_EXCLUDES} ${BACKUP_TARGET_HOST}:${BACKUP_TARGET_BASE}/config/


