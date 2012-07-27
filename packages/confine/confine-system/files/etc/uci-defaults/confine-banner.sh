#!/bin/sh

echo "                confine-project.eu" >> /etc/banner
[ $BRANCH ] && [ $REV ] && echo "Version: http://redmine.confine-project.eu/projects/confine/repository/show?branch=$BRANCH&rev=$REV" >> /etc/banner
echo "----------------------------------------------------" >> /etc/banner
