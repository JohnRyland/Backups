# Backups
Script based backup system using rsync

Made to work from Linux, MacOS and WSL.

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

  
