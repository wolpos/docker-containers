#!/bin/bash
### VARIABLES ###
USERFILE="/config/groups.json"
TEMPDIR="/tmp/workdir"

mkdir -p $TEMPDIR
rm -rf $TEMPDIR/*
SCRIPTDIR="/root/json-parser"

# test database isn't rebuilding
echo "Testing whether database is ready"
until [ "$(python3 /opt/pynab/pynab.py user list 2>&1 >/dev/null | grep -ci Fatal:)" = "0" ]
do
echo "waiting....."
sleep 3s
done
echo "database appears ready, proceeding"

# Get current list of groups
/opt/pynab/pynab.py group list | sed 's/\s.*$//' > $TEMPDIR/current-groups
#  Convert the user file to something far easier to work with
cat "$USERFILE" | $SCRIPTDIR/json.sh -b > $TEMPDIR/myUser.json
# Go through the list and enable / disable as required
ENTRY=0
while :
do
if ! cat $TEMPDIR/myUser.json | grep -i "\[$ENTRY,\"name\"]" > /dev/null
then
break
fi
GROUP=$(cat $TEMPDIR/myUser.json | grep -i "\[$ENTRY,\"name\"" | sed 's/^.*name/name/' | sed 's/^......//' | sed -e 's/^[ \t]*//' | sed 's/\"//g' )
ACTIVE=$(cat $TEMPDIR/myUser.json | grep -i "\[$ENTRY,\"active\"" | sed 's/^.*active/active/' | sed 's/^........//' | sed -e 's/^[ \t]*//' | sed 's/\"//g' | tr '[:upper:]' '[:lower:]' )
if [ $ACTIVE == "true" ]
then
python3 /opt/pynab/pynab.py group add $GROUP  >/dev/null 2>&1
else
python3 /opt/pynab/pynab.py group disable $GROUP >/dev/null 2>&1
fi
# get current user list of groups
echo $GROUP >> $TEMPDIR/user-groups
ENTRY=$((ENTRY + 1))
done

comm -13 <(sort $TEMPDIR/user-groups) <(sort $TEMPDIR/current-groups) > $TEMPDIR/delete-groups
cat "$TEMPDIR/delete-groups" | while read LINE

do
python3 /opt/pynab/pynab.py group remove $LINE >/dev/null 2>&1
done

rm -rf $TEMPDIR/*
