#!/bin/bash
#set -x
logger "backup-incremental runs now ($1)"
DATUM="$(date +%Y-%m-%d)"
BASEDATUM=$DATUM
echo "$(date): This is backup-incremental. Running pre-backup-script.."
/root/backupscripts/pre-backup.sh
echo "$(date): pre-backup-script complete."

BACKUPDIR=backup/con #consolidated
TSMONTHNAME=$BACKUPDIR/timestamp-month.snar
TSWEEKNAME=$BACKUPDIR/timestamp-week.snar
TSTMPNAME=$BACKUPDIR/timestamp-temp.snar
TSNAME=$TSTMPNAME

EXCLUDE="--exclude=backup --exclude=proc --exclude=sys --exclude=dev --exclude=media --exclude=mnt --exclude=run --exclude=tmp --exclude=var/share --exclude=var/spool/postfix/private --exclude=var/spool/postfix/public --exclude=home/dst"

cd /
mkdir -p $BACKUPDIR

DAY="$(date +%d)"
echo "$(date): Day is $DAY"

MODE="normal"
if [[ "$1" == "monthly" || "$DAY" == "01" ]]; then
	MODE="monthly"
	echo "$(date): Monthly backup - performing complete backup"
	rm -f $TSMONTHNAME $TSWEEKNAME
	DATUM="complete-$DATUM"
	TSNAME=$TSMONTHNAME
elif [[ "$1" == "weekly" || "02 08 15 22" =~ "$DAY" ]]; then
	MODE="weekly"
	echo "$(date): Weekly backup - incremental backup to the last monthly"
	rm -f $TSWEEKNAME
	cp $TSMONTHNAME $TSWEEKNAME
	TSNAME=$TSWEEKNAME
	DATUM="weekly-$DATUM"
else
	echo "$(date): Daily backup - incremental backup to the last weekly"
	rm -f $TSTMPNAME
	cp $TSWEEKNAME $TSTMPNAME
fi

TFILENAME="$DATUM.tar.gz"
TMD5NAME="$TFILENAME.md5"
TARGETFILE="$BACKUPDIR/$TFILENAME" 
TARGETMD5="$BACKUPDIR/$TMD5NAME" 

echo "$(date): Files: snapshot=$TSNAME backup=$TARGETFILE"

echo "$(date): Preparations complete. Target is $TARGETFILE Backup starts now.."

tar -czpf $TARGETFILE -g $TSNAME / $EXCLUDE
TARRETURN=$?
echo "$(date): Backup complete with tar exit code $TARRETURN. Running post-backup-script.."

/root/backupscripts/post-backup.sh
echo "$(date): post-backup-script complete. Creating hash value now.."

md5sum $TARGETFILE | cut -d" " -f1 > $TARGETMD5
echo "$(date): Hash value completed. Mode is $MODE"

if [ "$MODE" != "normal" ]; then
	echo "$(date): Creating symlinks for download.."
	cd $BACKUPDIR
	ln -s $TFILENAME $BASEDATUM.tar.gz
	ln -s $TMD5NAME $BASEDATUM.tar.gz.md5
fi


if [ "$TARRETURN" -ne "0" && "$TARRETURN" -ne "1" ]; then
	FAILMSG="$(date): Server Backup failed: tar returned with exit code $TARRETURN."
	>&2 echo $FAILMSG
	logger $FAILMSG
	echo $FAILMSG | mail -s 'Creating backup failed' root
    exit 1
else
	echo "$(date): tar backup successful"
fi

logger "backup-incremental is done"

