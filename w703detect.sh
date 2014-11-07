#!/bin/sh

TARGET=${1:-192.168.1.1}
INDICES=localdata/indices

if ! [ -s $INDICES ]; then
	echo "The file $INDICES is missing or empty, cannot proceed"
	exit 1
fi

echo "Target IPv4 address is $TARGET."
while true; do
	if ! ping -n -q -c2 -W2 -t1 $TARGET >/dev/null; then
		echo 'Not yet...'
		sleep 5
		continue
	fi
	macaddr=`ip ne show $TARGET | cut -d' ' -f5`
	echo "$TARGET on line with MAC address $macaddr"
	index=`grep $macaddr $INDICES | cut -d' ' -f2`
	if [ "$index" != "" ]; then
		echo "Using index $index"
		./w703config.sh $index $TARGET
	fi
done
