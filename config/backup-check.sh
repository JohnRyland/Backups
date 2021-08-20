#!/bin/bash
#
# Backup Script
# Copyright (C) 2020, John Ryland
#
# Made to work from Linux, MacOS and WSL.
#
# Getting started:
# 
# 1) Make sure cron can run on startup.
# For Linux and macOS, this should be the case by default.
# For windows, using WSL, follow these instructions:
#   https://blog.snowme34.com/post/schedule-tasks-using-crontab-on-windows-10-with-wsl/index.html
# 
# 2) Configure directories to include and exclude from the backups by editing the respective
# includes.txt and excludes.txt. This will be a file in the config directory called
# backup-<hostname>-includes.txt and excludes. If those files don't exist, they will be created
# for you the first time the backup script is run.
#
# 3) Add a crontab entry. Edit the crontab with 'crontab -e'. Then add the following:
# SHELL=/bin/bash
# */5 * * * * /bin/bash ~/.backups/backup-check.sh
# (https://crontab.guru/every-5-minutes).
#
# 4) For monthly backups, this can compress and encrypt them for easier offsite transport and storage.
# This requires 7zip to be installed on the backup target host.
# For Linux and WSL use:
#   sudo apt install p7zip-full
# For macOS:
#   brew install p7zip
#
# LOCAL_BACKUPS_DIR=`dirname "$(readlink -f "${0}")"`
LOCAL_BACKUPS_DIR=~/.backups
LOCAL_LOGS_DIR=${LOCAL_BACKUPS_DIR}/logs
LOCAL_CONFIG_DIR=${LOCAL_BACKUPS_DIR}/config
LOG_FILE=${LOCAL_LOGS_DIR}/backup.log
PID_FILE=${LOCAL_LOGS_DIR}/.backup.pid

# Note: --delete-delay is not supported on macOS version of rsync
RSYNC_FLAGS="-ah --delete"
PASSWORD=

# If you want to add a password to the zip files, uncomment and fill in a password after the -p
# PASSWORD=-p<YourPassword>

BACKUP_TARGET_HOST=nuc
BACKUP_TARGET_BASE=/media/Backups/Backups

BACKUP_SOURCE_HOST=$(hostname -s)

BACKUP_INCLUDES=${LOCAL_CONFIG_DIR}/backup-${BACKUP_SOURCE_HOST}-includes.txt
BACKUP_EXCLUDES=${LOCAL_CONFIG_DIR}/backup-${BACKUP_SOURCE_HOST}-excludes.txt

BACKUP_TARGET_ROOT=${BACKUP_TARGET_BASE}/${BACKUP_SOURCE_HOST}
BACKUP_TARGET_LOGS=${BACKUP_TARGET_ROOT}/logs

CURRENT_TIME=$(date -u +%s)
HOUR=$(date +%H)
DAY=$(date +%d)
MONTH=$(date +%m)

mkdir -p ${LOCAL_LOGS_DIR}
mkdir -p ${LOCAL_CONFIG_DIR}
cd ${LOCAL_BACKUPS_DIR}

# Prevent re-entrance for when the backups are taking a long time
if ps -p $(cat ${PID_FILE} 2> /dev/null) > /dev/null 2>&1
then
	echo "Job is already running"
	exit 1
elif ! echo $$ > ${PID_FILE}
then
	echo "Could not create PID file"
	exit 1
fi

# Make sure these files exist
if [ ! -f ${BACKUP_INCLUDES} ]
then
  echo "Not yet configured. Please edit ${BACKUP_INCLUDES}"
  touch ${BACKUP_INCLUDES}
fi
if [ ! -f ${BACKUP_EXCLUDES} ]
then
  echo "Not yet configured. Creating a default ${BACKUP_EXCLUDES}"
  echo "" >> ${BACKUP_EXCLUDES}
  echo "# Default to exclude everything in the root folder" >> ${BACKUP_EXCLUDES}
  echo "/*" >> ${BACKUP_EXCLUDES}
  echo "" >> ${BACKUP_EXCLUDES}
fi      

function hourly_backup
{
	# hourly we sync all the files using the previous hour as our reference.
	rsync ${RSYNC_FLAGS} --include-from=${BACKUP_INCLUDES} --exclude-from=${BACKUP_EXCLUDES} --link-dest ${1}/latest / ${BACKUP_TARGET_HOST}:${1}/${HOUR}/
	# then again in-case our link to latest is screwed
	rsync ${RSYNC_FLAGS} --include-from=${BACKUP_INCLUDES} --exclude-from=${BACKUP_EXCLUDES} / ${BACKUP_TARGET_HOST}:${1}/${HOUR}/
}

function daily_backup
{
	# daily we take a snapshot of the last hourly backup that was made.
	ssh ${BACKUP_TARGET_HOST} mkdir -p ${1}/${DAY}
	ssh ${BACKUP_TARGET_HOST} cp -al ${BACKUP_TARGET_ROOT}/hourly/latest/* ${1}/${DAY}/
	# then rsync again in to that in-case our link to latest is not fresh
	rsync ${RSYNC_FLAGS} --include-from=${BACKUP_INCLUDES} --exclude-from=${BACKUP_EXCLUDES} / ${BACKUP_TARGET_HOST}:${1}/${DAY}/
}

function monthly_backup
{
	# monthly we take a snapshot of the last daily backup.
	ssh ${BACKUP_TARGET_HOST} mkdir -p ${1}/${MONTH}
	ssh ${BACKUP_TARGET_HOST} cp -al ${BACKUP_TARGET_ROOT}/daily/latest/* ${1}/${MONTH}/
	# then rsync again in to that in-case our link to latest is not fresh
	rsync ${RSYNC_FLAGS} --include-from=${BACKUP_INCLUDES} --exclude-from=${BACKUP_EXCLUDES} / ${BACKUP_TARGET_HOST}:${1}/${MONTH}/

	# now we compress up this (on the backup server, in the background)
	ssh ${BACKUP_TARGET_HOST} mkdir -p ${BACKUP_TARGET_BASE}/archives
	ssh ${BACKUP_TARGET_HOST} "nohup nice -n13 7za a -t7z -mx1 -mhe ${PASSWORD} ${BACKUP_TARGET_BASE}/archives/backup_$(date +%Y-%m-%d)_${BACKUP_SOURCE_HOST}.7z ${1}/${MONTH} > /dev/null 2>&1 &"
}

function backup_wrapper
{
	echo "$(date) ${SHELL} $(whoami)@$(hostname -s):$(pwd) Starting ${1} backup plan"
	BACKUP_TARGET_DIRECTORY=${BACKUP_TARGET_ROOT}/${1}
	ssh ${BACKUP_TARGET_HOST} mkdir -p ${BACKUP_TARGET_DIRECTORY}/${2}
	${1}_backup ${BACKUP_TARGET_DIRECTORY}
	ssh ${BACKUP_TARGET_HOST} "echo last synced: $(date) > ${BACKUP_TARGET_DIRECTORY}/last-synced.txt"
	ssh ${BACKUP_TARGET_HOST} "rm ${BACKUP_TARGET_DIRECTORY}/latest"
	ssh ${BACKUP_TARGET_HOST} "ln -s ${BACKUP_TARGET_DIRECTORY}/${2} ${BACKUP_TARGET_DIRECTORY}/latest"
	echo "$(date) ${SHELL} $(whoami)@$(hostname -s):$(pwd) Finished ${1} backup plan"
}

function backup_worker
{
	LAST_BACKUP_TIME="0"
	if [ -f ${LOCAL_LOGS_DIR}/.last-${1}-backup ]
	then
		LAST_BACKUP_TIME=$(cat ${LOCAL_LOGS_DIR}/.last-${1}-backup)
	fi
	ELAPSED_SINCE_LAST_BACKUP="$((${CURRENT_TIME}-${LAST_BACKUP_TIME}))"
	if [ $((${ELAPSED_SINCE_LAST_BACKUP} > ${2})) != 0 ]
	then
		echo ${CURRENT_TIME} > ${LOCAL_LOGS_DIR}/.last-${1}-backup
		echo "$(date) ${SHELL} $(whoami)@$(hostname -s):$(pwd) running ${1} backup plan" >> ${LOG_FILE}
		backup_wrapper ${1} ${3}
	fi
}

# This ensures all output from backup_worker can be redirected to a log
function backup_exec
{
	backup_worker ${1} ${2} ${3} >> ${LOCAL_LOGS_DIR}/backup-${1}.log 2>&1
}

# These are deliberately in order from hourly to daily to monthly.
# Even if the computer is used only for say 30 minutes at a time and then turned off or put to sleep, this should still work
# if this script is called once every 5 or 10 minutes from cron. If it was 3 cron jobs scehduled hourly, daily and monthly,
# some of these may be missed during sleep, and if it did catch up, the order might not be guarenteed, whereas this kind of
# polling technique can ensure when the computer is woken and it needs to do a new hourly and a new daily backup, it can do
# then in the correct order that ensures the syncing is done efficiently.
backup_exec hourly  60*60       ${HOUR}
backup_exec daily   60*60*24    ${DAY}
backup_exec monthly 60*60*24*31 ${MONTH}

# Sync the logs
rsync ${RSYNC_FLAGS} ${LOCAL_LOGS_DIR}/ ${BACKUP_TARGET_HOST}:${BACKUP_TARGET_LOGS}/ > /dev/null 2>&1

# Allow the backup task to be run again
rm ${PID_FILE}

