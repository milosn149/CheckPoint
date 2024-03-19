#!/bin/bash

#backup_dir=/mnt/nfs/b-chkptdc
#deletion_log=mazani_backup.log
backup_dir=tmp/b-chkptdc
deletion_log=tmp/mazani_backup.log

# Delete files older then 365 days
find "$backup_dir" -type f -mtime +365 -delete -print >> "$deletion_log" 2>&1

# Delete files older than 30 days and leave only Monday's files
find "$backup_dir" -type f -mtime +30 \
    -exec sh -c 'test "$(LC_ALL=C date +%a -r "{}")" != Mon' \; -delete -print >> "$deletion_log" 2>&1
