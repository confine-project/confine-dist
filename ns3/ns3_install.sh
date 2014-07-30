#!/bin/bash

PATCHPATH="/home/vct/confine-dist/ns3/patch/"

echo "Installing necessary tools..." 

sudo apt-get update > apt.log
sudo apt-get install uml-utilities vtun mercurial gcc g++ python patch >> apt.log

echo $?

echo "Downloading NS3..."

cd
mkdir ns3
ret=$?
if [ $ret -ne 0 ] ; then 
  echo "Error: directory ns3 exists. If you wish to reinstall ns3, please remove the directory first."
  exit $ret
fi
cd ns3
hg clone http://code.nsnam.org/ns-3-allinone -r 2c860e2e968f

ret=$?
if [ $ret -ne 0 ] ; then 
  echo "Error: Failed to download NS3. Aborting..."
  exit $ret
fi

echo $ret

echo "Installing and patching NS3..."

cd ns-3-allinone
./download.py
./build.py --enable-examples --enable-tests
cd ns-3-dev
./test.py
patch -p1 < $PATCHPATH"ns3-rice-propagation-v3.diff"
patch -p0 < $PATCHPATH"tap-bridge-cc.diff"
patch -p0 < $PATCHPATH"tap-bridge-h.diff"
cd
