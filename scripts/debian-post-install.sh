#!/bin/bash
set -eu

# Copyright (c) 2015 Daniel Wayne Armstrong. All rights reserved.
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License (GPLv2) published by
# the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE. See the LICENSE file for more details.

scriptName="debian-post-install.sh"
scriptBlurb="_stable/testing/unstable_ configuration"
scriptProject="https://github.com/vonbrownie/linux-post-install"
scriptSrc="${scriptProject}/blob/master/scripts/${scriptName}"

debStable="jessie"
debTest="stretch"
debUnstable="sid"

echoRed() {
echo -e "\E[1;31m$1"
echo -e '\e[0m'
}

echoGreen() {
echo -e "\E[1;32m$1"
echo -e '\e[0m'
}

echoYellow() {
echo -e "\E[1;33m$1"
echo -e '\e[0m'
}

echoBlue() {
echo -e "\E[1;34m$1"
echo -e '\e[0m'
}

echoMagenta() {
echo -e "\E[1;35m$1"
echo -e '\e[0m'
}

echoCyan() {
echo -e "\E[1;36m$1"
echo -e '\e[0m'
}

penguinista() {
cat << _EOF_

(O<
(/)_
_EOF_
}

scriptDetails() {
echo "$( penguinista ) .: $scriptName -- $scriptBlurb :."
echo "USAGE"
echo -e "\t$scriptName [OPTION] [PACKAGE_LIST]"
echo "OPTIONS"
echo -e "\t-h\t$scriptName details"
echo -e "\t-p\tdeb package list"
}

runOptions() {
while getopts ":hp:" OPT
do
    case $OPT in
        h)
            scriptDetails
            exit 0
            ;;
        p)
            pkgList="$OPTARG"
            break
            ;;
        :)
            echoRed "$( penguinista ) .: Option '-$OPTARG' missing argument."
            exit 1
            ;;
        *)
            echoRed "$( penguinista ) .: Invalid option '-$OPTARG'"
            exit 1
            ;;
    esac
done
}

moreDetails() {
clear
scriptDetails
echo
cat << EOF
Howdy! Ideally this script is run following a fresh installation of Debian.

* Debian Wheezy Minimal Install
  http://www.circuidipity.com/install-debian-wheezy-screenshot-tour.html

* Transform a USB stick into a boot device packing multiple Linux distros
  http://www.circuidipity.com/multi-boot-usb.html

* $scriptName
  $scriptSrc

System will be configured to track a choice of Debian's ${debStable}/stable,
$debTest/testing, or ${debUnstable}/unstable branch. 

EOF
}

invalidReply() {
echoRed "\n'$REPLY' is invalid input...\n"
}

invalidReplyYN() {
echoRed "\n'$REPLY' is invalid input. Please select 'Y(es)' or 'N(o)'...\n"
}

confirmStart() {
while :
do
    read -n 1 -p "Run script now? [yN] > "
    if [[ $REPLY == [yY] ]]
    then
        echoGreen "\nLet's roll then...\n"
        sleep 2
        break
    elif [[ $REPLY == [nN] || $REPLY == "" ]]
    then
        penguinista
        exit
    else
        invalidReplyYN
    fi
done
}

testRoot() {
local message="$scriptName requires ROOT privileges to do its job."
if [[ $UID -ne 0 ]]
then
    echoRed "\n$( penguinista ) .: $message\n"
    exit 1
fi
}

interfaceFound() {
    ip link | awk '/mtu/ {gsub(":",""); printf "\t%s", $2} END {printf "\n"}'
}

testConnect() {
local message="$scriptName requires an active network interface."
if ! $(ip addr show | grep "state UP" &>/dev/null)
then
    echoRed "\n$( penguinista ) .: $message"
    echo -e "\nINTERFACES FOUND\n"
    interfaceFound
    exit 1
fi
}

testConditions() {
testRoot
testConnect
}

outputDone() {
echoGreen "\nDone!"
sleep 2
}

configRoot() {
clear
while :
do
    read -n 1 -p "Change root password? [yN] > "
    if [[ $REPLY == [yY] ]]
    then
        echo
	    passwd
        break
    elif [[ $REPLY == [nN] || $REPLY == "" ]]
    then
        break
    else
        invalidReplyYN
    fi
done
}

configLocales() {
clear
dpkg-reconfigure locales
sleep 2
}

configTimezone() {
clear
dpkg-reconfigure tzdata
sleep 2
}

configAptMain() {
# USAGE: configAptMain [DEBIAN_RELEASE] [APT_SRC_LIST]
local mirror="http://httpredir.debian.org/debian/"
echo -e "\ndeb $mirror $1 main contrib non-free" >> $2
echo -e "#deb-src $mirror $1 main contrib non-free" >> $2
}

configAptSec() {
# USAGE: configAptSec [DEBIAN_RELEASE] [APT_SRC_LIST]
local mirror="http://security.debian.org/"
echo -e "\ndeb $mirror ${1}/updates main contrib non-free" >> $2
echo -e "#deb-src $mirror ${1}/updates main contrib non-free" >> $2
}

configAptUp() {
# USAGE: configAptUp [DEBIAN_RELEASE] [APT_SRC_LIST]
local mirror="http://httpredir.debian.org/debian/"
echo -e "\ndeb $mirror ${1}-updates main contrib non-free" >> $2
echo -e "#deb-src $mirror ${1}-updates main contrib non-free" >> $2
}

configAptBk() {
# USAGE: configAptBk [DEBIAN_RELEASE] [APT_SRC_LIST]
local mirror="http://httpredir.debian.org/debian/"
echo -e "\ndeb $mirror ${1}-backports main contrib non-free" >> $2
}

configAptMoz() {
# USAGE: configAptMoz [DEBIAN_RELEASE] [APT_SRC_LIST]
local mirror="http://mozilla.debian.net"
local deb="pkg-mozilla-archive-keyring_1.1_all.deb"
local key="${mirror}/${deb}"
wget $key && dpkg -i $deb && rm $deb \
    && echo -e "\ndeb ${mirror}/ ${1}-backports iceweasel-release" >> $2
}

configAptEx() {
# USAGE: configAptEx [APT_SRC_LIST]
local mirror="http://httpredir.debian.org/debian/"
echo -e "\ndeb $mirror experimental main" >> $1
}

configApt() {
# USAGE: configApt [DEBIAN_RELEASE]
local list="/etc/apt/sources.list"
clear
cp $list ${list}.$(date +%FT%H:%M:%S.%N%Z).bak
echo "# $list" > $list
configAptMain $1 $list
if [[ $1 == "$debStable" || $1 == "$debTest" ]]
then
    configAptSec $1 $list
    configAptUp $1 $list
fi
if [[ $1 == "$debStable" ]]
then
    configAptBk $1 $list
    while :
    do
        echo "Track Debian Mozilla Team with the latest iceweasel-release"
        read -n 1 -p "(vs older version in stable)? [yN] > "
        if [[ $REPLY == [yY] ]]
        then
            echo -e "\n\nOK. Will do..."
            sleep 2
            configAptMoz $1 $list
            break
        elif [[ $REPLY == [nN] || $REPLY == "" ]]
	    then
            break
        else
            invalidReplyYN
        fi
    done
fi
if [[ $1 == "$debUnstable" ]]
then
    while :
    do
        read -n 1 -p "Track the experimental archive? [yN] > "
        if [[ $REPLY == [yY] ]]
        then
            echo -e "\n\nOK. Will do..."
            sleep 2
            configAptEx $list
            break
        elif [[ $REPLY == [nN] || $REPLY == "" ]]
	    then
            break
        else
            invalidReplyYN
        fi
    done
fi
apt-get update && apt-get -y dist-upgrade && apt-get -y autoremove
}

configBranch() {
clear
while :
do
cat << EOF
Debian branch to track for packages:

0) ${debStable}/stable
1) ${debTest}/testing
2) ${debUnstable}/unstable

EOF
read -n 1 -p "Your choice? [0-2] > "
case $REPLY in
    0)
        configApt $debStable
        break
        ;;
    1)
        configApt $debTest
        break
        ;;
    2)
        configApt $debUnstable
        break
        ;;
    *)
        invalidReply
        ;;
esac
done
}

addPkgs() {
local pkgs="apt-utils aptitude cowsay htop rsync tmux vim"
clear
echo -e "\nInstalling a few extra packages...\n"
apt-get -y install $pkgs && outputDone
}

addPkgList() {
clear
}

configAlt() {
clear
update-alternatives --config editor
if [ -x /usr/bin/X ]
then
    clear
    update-alternatives --config x-terminal-emulator
fi
}

configSudo() {
# USAGE: configSudo [USERNAME]
clear
while :
do
    read -n 1 -p "Grant $1 sudo privileges? [yN] > "
    if [[ $REPLY == [yY] ]]
    then
	    echo -e "\nOK... Assigning $1 to sudo group...\n"
	    apt-get -y install sudo && usermod -a -G sudo $1 && outputDone
	    break
    elif [[ $REPLY == [nN] || $REPLY == "" ]]
    then
        echo
	    break
    else
	    invalidReplyYN
    fi
done
}

addUser() {
clear
while :
do
    read -n 1 -p "Add another user to $HOSTNAME? [yN] > "
    if [[ $REPLY == [yY] ]]
    then
        echo
        read -p "Username? > " username
        if [ -d "/home/$username" ]
        then
            echo -e "\nERROR: '$username' already exists!\n"
        else
            adduser $username && configSudo $username
        fi
    elif [[ $REPLY == [nN] || $REPLY == "" ]]
    then
        break
    else
        invalidReplyYN
    fi
done
}

auRevoir() {                                                                    
local message="All done!"
local cowsay="/usr/games/cowsay"                                      
clear
if [ -x $cowsay ]                                                     
then                                                                            
    echoGreen "$($cowsay $message)"                                            
else                                                                            
    echoGreen "$message"                                                        
fi                                                                              
}
 
#: START
runOptions "$@"
moreDetails
confirmStart
testConditions
configRoot
configLocales
configTimezone
configBranch
addPkgs
addPkgList
configAlt
addUser
auRevoir
