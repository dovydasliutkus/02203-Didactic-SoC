#!/bin/bash

getopts f: FLAG
FILE="$OPTARG"

echo $FILE

if [ $FLAG != "f" ]
then
  echo "Please provide -f option to run_kactus2_script.sh." >&2
  exit 1
fi

# Local kactus2 install
KACTUSPATH="${KACTUSPATH:=/home/dovli/tools/kactus2/executable}"
PYTHONAPIPATH=/home/dovli/tools/kactus2/PythonAPI
CONFPATH=~/.config/TUT
CONFFILE=Kactus2.ini

# Copy the default config file, if no config file found
if [ ! -f $CONFPATH/$CONFFILE ]; then
  echo "Creating default settings"
  mkdir -p $CONFPATH
fi

KACTUS2='LD_LIBRARY_PATH=$KACTUSPATH:$PYTHONAPIPATH:$LD_LIBRARY_PATH PYTHONPATH="$PYTHONAPIPATH" kactus2'


eval "$KACTUS2 -c < $FILE"
