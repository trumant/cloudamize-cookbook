#!/bin/bash

##################################################################################################
#
# This Script Install and configure the Cloudamize Agent
#
##################################################################################################

PUBLICIP_FILE=public-ipv4
CUSTOMER_KEY=/usr/local/cloudamize/bin/customer_key
ONPREM_STATUS=/usr/local/cloudamize/bin/onprem_status

setVars()
{
  SERVERIP="agent.cloudamize.com"
  DEBUG=0
  if [ "x"$2 = "xdebug" ]; then
    DEBUG=1
  fi
  TMPDIR=/tmp/.cconfdloads
}

checkOS()
{
  OSNAME=linux
  uname -a | grep -i ubuntu >> /dev/null
  if [ $? -eq 0 ]; then
    OSNAME=ubuntu
  else
    lsb_release -a | grep -i ubuntu >> /dev/null
        if [ $? -eq 0 ]; then
            OSNAME=ubuntu
      updateAptSourceList
        else
      uname -a | grep -i suse >> /dev/null
      if [ $? -eq 0 ]; then
        OSNAME=SUSE
      else
      uname -a | grep -i gentoo >> /dev/null
      if [ $? -eq 0 ]; then
        OSNAME=GENTOO
      fi
      fi
    fi
  fi
  echo $OSNAME
}

echodebug()
{
  if [ $DEBUG -eq 1 ];then
    echo "DEBUG: $1"
  fi
}

echoError()
{
  if [ $1 -ne 0 ]; then
    echo "ERROR: $2"
  fi
}

echoInfo()
{
  echo "INFO: $1"
}

updateAptSourceList()
{
  grep 'deb http://archive.ubuntu.com/ubuntu/ hardy main universe' /etc/apt/sources.list > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "deb http://archive.ubuntu.com/ubuntu/ hardy main universe" >> /etc/apt/sources.list
  fi

  grep 'deb-src http://archive.ubuntu.com/ubuntu/ hardy main universe' /etc/apt/sources.list > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "deb-src http://archive.ubuntu.com/ubuntu/ hardy main universe" >> /etc/apt/sources.list
  fi

  grep 'deb http://archive.ubuntu.com/ubuntu/ hardy-updates main universe' /etc/apt/sources.list > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "deb http://archive.ubuntu.com/ubuntu/ hardy-updates main universe" >> /etc/apt/sources.list
  fi

  grep 'deb-src http://archive.ubuntu.com/ubuntu/ hardy-updates main universe' /etc/apt/sources.list > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "deb-src http://archive.ubuntu.com/ubuntu/ hardy-updates main universe" >> /etc/apt/sources.list
  fi
}


installSTAP()
{
  if [ "$OSNAME" = "ubuntu" ] ; then
    apt-get -y install systemtap >> $LOGFILE 2>&1
    echoError $? "Installation of systemtap Failed"
  else
    conf_file="./yum.conf_tmp"
    sudo cp /etc/yum.conf $conf_file
    sed -i "s/releasever=/#releasever=/" $conf_file  # comment releasever
    sudo yum clean all >> $LOGFILE 2>&1              # clear the cache
    sudo yum -y install systemtap kernel-devel-`uname -r` -c $conf_file >> $LOGFILE 2>&1
    echoError $? "Installation of systemtap Failed"
    rm -f $conf_file
  fi
}




uninstallCCAgent()
{
# Check if process CCAgent is runing, kill it
pidof CCAgent >/dev/null 2>&1

if [ $? -eq 0 ]; then
      kill -9 `pidof CCAgent` >/dev/null 2>&1
    echo "CCAgent Stopped"
fi

# Check if process CCAgent is runing, kill it
pidof COOFLAgent >/dev/null 2>&1

if [ $? -eq 0 ]; then
      kill -9 `pidof COOFLAgent` >/dev/null 2>&1
    echo "COOFLAgent Stopped"
fi

# Check if process COCLAgent is runing, kill it
pidof COCLAgent >/dev/null 2>&1

if [ $? -eq 0 ]; then
      kill -9 `pidof COCLAgent` >/dev/null 2>&1
    echo "COCLAgent Stopped"
fi

# Check if process cloudamized is runing, kill it
pidof cloudamized >/dev/null 2>&1

if [ $? -eq 0 ]; then
  kill -9 `pidof cloudamized` >/dev/null 2>&1
fi
#check_cloudamized
#pidof cloudamized >/dev/null 2>&1
PID=`ps -ef | grep "check_cloudamized" | grep -v grep | awk {'print $2'}|wc -l`
if [ $PID -gt 0 ]; then
  for i in `ps -ef | grep "check_cloudamized" | grep -v grep | awk {'print $2'}`; do  kill -9 $i; done
fi

# Remove cloudamize enrty rc.local if exists
if [ -f /etc/rc.local ]; then
grep -w check_cloudamized /etc/rc.local |grep cloudamize > /dev/null 2>&1

if [ $? -eq 0 ]; then
        sed -i '/check_cloudamized/ d' /etc/rc.local
fi
fi

# Remove port 5106 from service if exist
grep -w cloudamized /etc/services |grep 5106 > /dev/null 2>&1
if [ $? -eq 0 ]; then
        sed -i '/cloudamized / d' /etc/services
fi

# Delete old agent if exists
if [ -d /usr/local/CloudConfidence ]; then
        rm -rf /usr/local/CloudConfidence > /dev/null 2>&1

fi

# Delete  agent if exists
if [ -e /usr/local/cloudamize/ ]; then
        rm -rf  /usr/local/cloudamize/ > /dev/null 2>&1
fi

}


installCCAgent()
{
  mkdir -p /usr/local/cloudamize/bin
  mkdir -p /usr/local/cloudamize/cl-out
  mkdir -p /usr/local/cloudamize/ofl-out
  mkdir -p /usr/local/cloudamize/out
  mkdir -p /usr/local/cloudamize/logs

  rm -rf $TMPDIR/ccagent-v2
  mkdir -p $TMPDIR/ccagent-v2
  cd $TMPDIR/ccagent-v2
  isOnPrem=0
  #Check if the machine is on AWS
  wget -T 2 -t 1 -q -O - http://169.254.169.254/latest/meta-data/instance-id >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    isOnPrem=0
  else
    isOnPrem=1
  fi

  chmod 755 /usr/local/cloudamize/bin
  chmod 777 /usr/local/cloudamize/out /usr/local/cloudamize/logs /usr/local/cloudamize/cl-out /usr/local/cloudamize/ofl-out

  echo $customerKey > $CUSTOMER_KEY
  echo $isOnPrem > $ONPREM_STATUS

  wget http://$SERVERIP/cxf/downloadFile/ccagent-v2.tgz >> $LOGFILE 2>&1
  tar -zxf ccagent-v2.tgz >> $LOGFILE 2>&1
  cp -f ccagent-v2/* /usr/local/cloudamize/bin >> $LOGFILE 2>&1

  uname -r| grep .el5 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    uname -m |grep "64" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      cp -f ccagent-v2/cpu_32/* /usr/local/cloudamize/bin >> $LOGFILE 2>&1
    else
      cp -f ccagent-v2/cpu_64/* /usr/local/cloudamize/bin >> $LOGFILE 2>&1
    fi
  else
    uname -m |grep "64" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      cp -f ccagent-v2/cpu_el5_32/* /usr/local/cloudamize/bin >> $LOGFILE 2>&1
    else
      cp -f ccagent-v2/cpu_el5_64/* /usr/local/cloudamize/bin >> $LOGFILE 2>&1
    fi

  fi
  chmod 755 /usr/local/cloudamize/bin/* >> $LOGFILE 2>&1
}

configure()
{

  cd /usr/local/cloudamize/bin
  if  [ -f /etc/rc.local ];
  then
  grep "^exit 0" /etc/rc.local
  if [ $? -eq 0 ]; then
    sed -i '/^exit 0/c\/usr/local/cloudamize/bin/check_cloudamized &\nexit 0' /etc/rc.local
    if [ $? -ne 0 ]; then
      echo "Failed - Updation of rc.local" >> $LOGFILE
    fi
  else
    grep "^cat <<EOL >> /etc/ssh/sshd_config" /etc/rc.local
    if [ $? -eq 0 ]; then
      sed -i '/^cat <<EOL >> \/etc\/ssh\/sshd_config/c\/usr/local/cloudamize/bin/check_cloudamized &\ncat <<EOL >> /etc/ssh/sshd_config' /etc/rc.local
      if [ $? -ne 0 ]; then
        echo "Failed - Updation of rc.local" >> $LOGFILE
      fi
    else
      echo "/usr/local/cloudamize/bin/check_cloudamized &" >> /etc/rc.local
      echoError $? "Failed - Updation of rc.local" >> $LOGFILE 2>&1
    fi
  fi
  else
  if [ -d /etc/local.d ]
  then
    cp /usr/local/cloudamize/bin/cloudamized.start /etc/local.d/
  fi
  fi

  /usr/local/cloudamize/bin/check_cloudamized &

}


#####################################
#Main

# Usage

#read -p "Enter customer key: " customerKey

customerKey=$CLOUDAMIZE_CUSTOMER_KEY

if [ `whoami` != "root" ] ; then
    echo "ERROR: $0 must be run as user 'root'."
    exit 1
fi


# Set Base Variables
setVars

GB_MEMORY=1048576

if [ ! -x /usr/bin/wget ] ; then
    # some extra check if wget is not installed at the usual place
    command -v wget >/dev/null 2>&1 || { echo >&2 "Please install wget or set it in your path and run this command again. Aborting."; exit 1; }
fi

LOGFILE="/usr/local/cloudamize/logs/install.log"
echoInfo "Downloading Cloudamize Monitor"
uninstallCCAgent
installCCAgent
echoInfo "Done."

# Determine OS
checkOS >> $LOGFILE 2>&1

if [ $isOnPrem -eq 0 ]; then
  # Check and install reguired packages
  echoInfo "Checking and installing dependencies...this may take a few minutes."
  if [ `cat /proc/meminfo | grep MemTotal | awk {'print $2'}` -ge $GB_MEMORY ]; then
    installSTAP
  fi
fi
echoInfo "Done Checking Dependencies"

rm -rf $TMPDIR



echoInfo "Configuring Cloudamize Monitor"
configure>> $LOGFILE 2>&1

echoInfo "Cloudamize Monitor Installed Successfully"
exit 0
