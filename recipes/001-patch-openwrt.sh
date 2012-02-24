#!/bin/sh
# Apply every patch on the recipies/patches directory to the the confine-dist root
#
# HOWTO:
# 1. Modify whatever you need from the src/ directory or packages/openwrt/ directories.
# 2. If you create any new file, you need to add it first to the working copy
#       $ svn add [new dir or file]
# 3. From the confine-dist root directory do:
#       $ svn diff [modified dir or file] > recipes/patches/00x-nameofpatch.patch
# 4. Enjoy your patcha with a cup of coffee

for file in recipes/patches/*.patch; do
    echo "----- Applying patch $file"
    patch -p0 -Nr - < $file
done
