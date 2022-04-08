
# Backups
Script based backup system using rsync


## Introduction

This is based on a few scripts which use some basic UNIX commands to schedule and sync files from
clients to a backup server. The scheduling is using cron, and the syncing is using rsync.

This is designed for backups on a local area network. 

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

Another assumption is that your backup server and your clients have fixed hostnames and are on the same
local area network. Potentially this might work over the internet, but it has not been tested or intended
for this purpose. The idea is that it backs up to a backup server on your LAN.


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


## Script output:

The script is designed to output most of its output to log files located in ~/.backups/log

However if something goes wrong or needs attention then the script outputs to stdout which
when the script is run from cron will result in the output being sent as an email.

The default configuration of a linux system will result in these emails being delivered to
a local mailbox. When running a terminal you may see a notification such as:

```
You have new mail in /var/mail/YourUserName
```

These can be read using the `mail` command at the commandline.


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


## Configuring the include/exclude files:

These files are read by rsync, so the best explaination is the rsync documentation.
The files are passed to the --include-from and --exclude-from parameters to rsync.
Here is the explaination from the rsync man page of these options:

```
       --exclude=PATTERN
              This option is a simplified form of the --filter option that defaults to
              an exclude rule and does not allow the full rule-parsing syntax of normal
              filter rules.

              See the FILTER RULES section for detailed information on this option.

       --exclude-from=FILE
              This  option  is  related to the --exclude option, but it specifies a FILE
              that contains exclude patterns (one per line).  Blank lines in the file and
              lines starting with ';' or '#' are ignored.  If FILE is -, the list will be
              read from standard input.

       --include=PATTERN
              This option is a simplified form of the --filter option that defaults to an
              include rule and does not allow the full rule-parsing syntax of normal filter
              rules.

              See the FILTER RULES section for detailed information on this option.

       --include-from=FILE
              This option is related to the --include option, but it specifies a FILE that
              contains include patterns (one per line).  Blank lines in the file and lines
              starting with ';' or '#'  are  ignored.   If FILE is -, the list will be read
              from standard input.
```

If both files are empty, then the default will be that nothing is excluded so it will include everything.
It will backup everything from '/' down. The include rules basically override any exclude rules in this
case.

So the very first thing you will probably want to do is exclude everything unless you want to do
entire drive backups which is probably not recommended as there are plenty of files which change frequently
that don't require backing up or system files that can be easily restored in other ways like a OS
reinstall. Backing up these files will just delay backing up your important files. So to exclude everything:

edit backup-YourClientHostName-excludes.txt to contain:
```
# Default to exclude everything in the root folder
/*
```

Now if you want to add your home directory to the backups assuming your home directory is /home/YourUserName
then if there are other users and we want to exclude their home directories you would need to edit the
includes and excludes as follows:

edit backup-YourClientHostName-excludes.txt to contain:
```
# Default to exclude everything in the root folder
/*

# Now specifically exclude everything from the home directory
/home/*
```

edit backup-YourClientHostName-includes.txt to contain:
```
# Include home directory
/home/
/home/YourUserName/
```

This is a bit confusing. It first excludes everything from the root directory, then the include rules override
this for the home directory. However we don't want to include everything from home, so we exclude everything
subfolder of /home with the /home/* exclude rule, then we make an exception to this with the include override
rule to say we do want to include /home/YourUserName/.

We can further refine the excludes, this is an example of excluding specific folders from your home directory.

edit backup-YourClientHostName-excludes.txt to contain:
```
# Default to exclude everything in the root folder
/*

# Now specifically exclude everything from the home directory
/home/*
/home/YourUserName/.backups
/home/YourUserName/.cache
/home/YourUserName/.backups
/home/YourUserName/Downloads
/home/YourUserName/Music
/home/YourUserName/Old/Files/Saved
```

More directories could be added to this list. As with the last directory there which is not in the root of the
home directory, you can add excludes in subfolders without needing to edit the includes folder. We have already
specified to include everything in /home/YourUserName/, so the excludes are a filter pattern over this.

