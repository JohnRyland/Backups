# Backups
Script based backup system using rsync


## Introduction

This is based on a few scripts which use some basic UNIX commands to schedule and sync files from
clients to a backup server. The scheduling is using cron, and the syncing is using rsync.

The script periodically checks to see if it needs to do an hourly, daily or monthly backup depending
when it last did one of these. The backups are rsynced to the server and stored using hardlinks between
backup sets to avoid duplicate files.

Because of the hardlinks, don't attempt to change the files on the backup server where the backups are
stored else it may corrupt the other daily, weekly, monthly backups. It's fine to restore files from the
backups by copying them.


## Requirements

Linux based machine as the backup server. Filesystem where backups stored should support hardlinks.

Made to work for Linux, MacOS and WSL clients.

Assumes can ssh between client and backup server and that this has been configured to not use passwords
but rather the backup server's authorized_keys contains the public keys of the clients. Refer to online
guides such as this https://linuxize.com/post/how-to-setup-passwordless-ssh-login/ to configure this.


## Getting started:

1) Make sure cron can run on startup.
   For Linux and macOS, this should be the case by default.

   For windows, using WSL, follow these instructions:
    https://blog.snowme34.com/post/schedule-tasks-using-crontab-on-windows-10-with-wsl/index.html
    A summary of the steps involved:
    1. Make sure the start command can run without root privilege, run `sudo visudo`
       and add the following line:
       ```
         %sudo ALL=NOPASSWD: /etc/init.d/cron start
       ```
       Save and quit and fix any problem if prompted.
    2. Type `shell:startup` in the Run dialog and explorer will open the startup folder.
       Create a shortcut to wsl.exe and edit the properties as following:
       ```
         C:\Windows\System32\wsl.exe sudo /etc/init.d/cron start
       ```

2) Configure directories to include and exclude from the backups by editing the respective
includes.txt and excludes.txt. This will be a file in the config directory called
`backup-<hostname>-includes.txt` and `backup-<hostname>-excludes.txt`. If those files don't
exist, they will be created for you the first time the backup script is run.

3) Add a crontab entry. Edit the crontab with `crontab -e`. Then add the following:
```
SHELL=/bin/bash
*/5 * * * * /bin/bash ~/.backups/backup-check.sh
```
(https://crontab.guru/every-5-minutes).

4) For monthly backups, this can compress and encrypt them for easier offsite transport and storage.
This requires 7zip to be installed on the backup target host.
For Linux and WSL use:
```
  sudo apt install p7zip-full
```
For macOS:
```
  brew install p7zip
```


## HARDLINKS used to de-duplicate files:

The backups contain hardlinks to avoid duplicate files using additional disk space.

Hardlinks are similar to symlinks depending how applications modify the file.

If the application re-writes the file out after modifying it, then the hardlink will
be broken and it will not modify the other 'copies'.

However if it writes to the file in a way that updates it without creating a new
file to replace the existing one, then the contents of the hardlink are modified which
changes it for all the 'copies', just like a symlink.


## How to use these backups:

DO NOT MODIFY the backup files in the backup folders.

You can safely copy the files to your machine. Whilst doing a restore, it would be
advisable to pause backups for the given machine. This can be done by editing
the crontab with 'crontab -e' and deleting the appropriate line(s).

Remember to add them back to crontab after.

A full restore procedure is not currently worked out yet. The backups are designed
to copy just the important files, not for complete backup/restore of entire drives.

The monthly zipped backups are meant to be appropriate for upload to cloud storage.

To add backups to another computer, copy the setup.sh script and run it there. The
default is that it will backup the entire drive, however first thing to do immediately
is to configure the include and exclude lists in the config files for the given
machine to only select the most important files.

