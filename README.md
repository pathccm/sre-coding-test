# sre-coding-test

Files to help with test

## create-files-to-backup.sh

Small script that generates a folder structure of files with random content in them so we have something to back up.

This script supports CLI args and env vars. Both settings are defined below:
* -r/--root-dir/ROOT_DIR
    * set the folder we'll create all files/etc. under (defaults to ./folders)
* --days/DAYS
    * the number of days to create files/etc. for (defaults to 35)
* -d/--dirs/DIR_RAND_ROOT
    * the random seed for the number of directories to create per day (defaults to 10)
* -f/--files/FILE_RAND_ROOT
    * the random seed for the number of files to create per directory (defaults to 5)
* -h/--help
    * Help for the script

While each folder (and the files within it) will get different modification times, users _can_ just treat the generated files as a folder structure to back up.
