#!/bin/sh

echo "                confine-project.eu" >> /etc/banner
BRANCH=$(cat /etc/confine.version  | head -n2 | tail -n 1)
REV=$(cat /etc/confine.version  | head -n3 | tail -n 1 | head -c 7)
echo "Version: http://redmine.confine-project.eu/projects/confine/repository/show?branch=${BRANCH:-"???"}&rev=${REV:-"???"}" >> /etc/banner

echo "----------------------------------------------------" >> /etc/banner
