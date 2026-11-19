#!/bin/bash
# Copies new and changed files from the shared EFS folder to S3.
#
# Installed on each file server as /usr/local/bin/efs-s3-sync.sh by the
# CloudFormation UserData and run by cron (default: every 5 minutes).
# Settings come from /etc/efs-s3-sync.conf (see config/efs-s3-sync.conf.example).
#
# Safe to run on both servers at the same time: S3 uploads are idempotent and
# flock stops a slow run from overlapping with the next one on the same host.
set -euo pipefail

set -a; . /etc/efs-s3-sync.conf; set +a
LOG=/var/log/efs-s3-sync.log

exec 9>/run/efs-s3-sync.lock
if ! flock -n 9; then
  echo "$(date -Is) previous sync still running - skipping" >> "$LOG"
  exit 0
fi

# Never sync an empty local directory if the EFS mount has dropped.
if ! mountpoint -q "$MOUNT_POINT"; then
  echo "$(date -Is) ERROR: $MOUNT_POINT is not mounted - nothing synced" >> "$LOG"
  exit 1
fi

echo "$(date -Is) sync $SOURCE_DIR -> s3://$BUCKET/$PREFIX/" >> "$LOG"
# No --delete: S3 is a backup, so files removed from EFS are kept in S3.
aws s3 sync "$SOURCE_DIR" "s3://$BUCKET/$PREFIX/" --no-progress >> "$LOG" 2>&1
