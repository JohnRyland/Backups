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
  
# Copy the required scripts and config files
mkdir -p ~/.backups
cd ~/.backups
rsync -avh ${BACKUP_TARGET_HOST}:${BACKUP_TARGET_BASE}/config ./
cp config/backup-check.sh ./
cp config/push-config.sh ./


# Update crontab if it doesn't already include running the script
crontab -l | grep "~/.backups/backup-check.sh" > /dev/null
if [ $? == 1 ]
then
  (echo "SHELL=/bin/bash"; crontab -l 2>/dev/null; echo "*/5 * * * * /bin/bash ~/.backups/backup-check.sh") | crontab -
fi


