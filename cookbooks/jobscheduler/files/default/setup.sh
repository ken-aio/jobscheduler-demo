#!/bin/sh
# 
# ------------------------------------------------------------
# Company: Software- und Organisations-Service GmbH
# Author : Oliver Haufe <oliver.haufe@sos-berlin.com>
# Dated  : 2011-04-04
# Purpose: starts Job Scheduler installer 
# ------------------------------------------------------------


if [ "$1" = "-h" ] || [ "$1" = "--help" ]
then
  echo "`basename $0` [OPTION]"
  echo "options:"
  echo "  -u, --unprivileged     installer does not ask for root privileges"
  echo ""
  exit 0
fi

JAVABIN=/home/scheduler/jre1.7.0_25/bin

if [ "$USER" = "root" ]
then
  echo "Please don't call this script as root"
  exit 1
fi

which_return="`$JAVABIN/java -version 2>&1`"
last_exit=$?

if [ $last_exit -ne 0 ]
then
  echo "\"$JAVABIN/java\" couldn't be found."
  exit 1
fi

if [ "$JAVABIN" != "" ]
then
  JAVABINPATH="${JAVABIN}/"
fi


if [ "$1" = "-u" ] || [ "$1" = "--unprivileged" ]
then
  shift
  echo "${JAVABINPATH}java -Dizpack.mode=privileged -jar \"`dirname $0`/jobscheduler_linux-x64.jar\" $*"
  ${JAVABINPATH}java -Dizpack.mode=privileged -jar "`dirname $0`/jobscheduler_linux-x64.jar" $*
  exit 0
fi

  
which_return="`which sudo 2>&1`"
sudo_exit=$?
USESU=n 

export DISPLAY
if [ -f "$HOME/.Xauthority" ]
then 
  XAUTHORITY="$HOME/.Xauthority"
  export XAUTHORITY
fi

my_sudo() {
  #Sudo option -E supported since 1.6.9
  sudo_option="-E"
  sudo_version=`sudo -V | head -1 | sed -e 's/.*\([1-9]\{1,\}\)\.\([0-9]\{1,\}\)\.\([0-9]\{1,\}\).*/\1\2\3/'`
  sudo_version_is_number=`echo "$sudo_version" | sed -e 's/[0-9]//g'`
  if [ -z "$sudo_version_is_number" ]
  then
    if [ "$sudo_version" -lt "169" ]
    then
      #Sudo version less than 1.6.9
      sudo_option=""
    fi
  else
    #Sudo version not found
    sudo_option=""
  fi
  echo "sudo $sudo_option $*"
  sudo $sudo_option $*
  sudo_exit=$?
}

if [ $sudo_exit -eq 0 ]
then
  my_sudo ${JAVABINPATH}java -jar "`dirname $0`/jobscheduler_linux-x64.jar" $*
  if [ $sudo_exit -ne 0 ]
  then
    echo "Do you want to use 'su' instead of 'sudo'? (y or n)"
    read USESU
  fi
else
  USESU=y 
fi

if [ "$USESU" = "y" ] || [ "$USESU" = "Y" ]
then
  echo "su root -c \"${JAVABINPATH}java -jar \\\"`dirname $0`/jobscheduler_linux-x64.jar\\\" $*\""
  su root -c "${JAVABINPATH}java -jar \"`dirname $0`/jobscheduler_linux-x64.jar\" $*"
fi
