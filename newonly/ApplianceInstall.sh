#!/bin/bash
HOSTINGREPO="$1"
HOSTINGBRANCH="$2"
INITIALHOSTNAME="$3"
HOSTINGFOLDER="$4"
INITIALHOSTINGREPO="$5"
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TITLE=$(cat /loginvsi/.title)

echo "INITIALHOSTNAME=\"$INITIALHOSTNAME\"" >> /loginvsi/build.conf
echo "TITLE=\"$TITLE\"" >> /loginvsi/build.conf

echo $HOSTINGREPO $HOSTINGBRANCH $HOSTINGFOLDER >/root/.hosting
chmod 700 /root/.hosting

cd / || exit
export DEBIAN_FRONTEND=noninteractive
# get latest versions of packages
apt-get -qq update 2>&1
apt-get -qq -y dist-upgrade 2>&1
# install security updates
#unattended-upgrades &>/dev/null 

# install docker-ce

#apt-get -qq -y remove docker docker-engine | cat
wget -q -O /pdmenu.deb http://ftp.nl.debian.org/debian/pool/main/p/pdmenu/pdmenu_1.3.4+b1_amd64.deb
apt-get -qq -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    /pdmenu.deb \
    software-properties-common \
	htop \
    zip \
    unzip \
    sudo 2>&1
echo "admin ALL = (ALL:ALL) ALL" >>/etc/sudoers
#dpkg -i /pdmenu.deb 2>&1
#pdmenu \

#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - &>/dev/null
#add-apt-repository \
#   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
#   $(lsb_release -cs) \
#   stable" &>/dev/null
#apt-get -qq update &>/dev/null
#apt-get -qq -y install docker-ce &>/dev/null
curl -sSL https://get.docker.com | sh 2>&1

# install docker-compose
curl -s -S -L https://github.com/docker/compose/releases/download/1.17.1/docker-compose-"$(uname -s)-$(uname -m)" > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

#dpkg --configure -a
# clone repo and pull images
if [ -d "/dockerrepo" ]; then
    rm -rf /dockerrepo
fi
git clone -q -b $HOSTINGBRANCH $INITIALHOSTINGREPO /dockerrepo
cd /dockerrepo/ || exit
cp -f $SCRIPT_PATH/../.play /root/.play
chmod 700 /root/.play
base64 -d < /root/.play | docker login -u vsiplayaccount --password-stdin 2>&1
docker pull portainer/portainer 2>&1
docker pull httpd:2.4-alpine 2>&1
docker pull meltwater/docker-cleanup:latest

cd /dockerrepo/$HOSTINGFOLDER || exit
version=$(grep "Version__Number" < docker-compose.yml | cut -d':' -f2 | cut -d"'" -f2 | tail -1)
echo $version >/loginvsi/.version

docker-compose pull 2>&1
docker logout 2>&1





cp -r -f $SCRIPT_PATH/../loginvsi/* /loginvsi/
#mkdir /loginvsi
mkdir /loginvsi/img
wget -q -O /loginvsi/img/logo_alt.png https://www.loginvsi.com/images/logos/login-vsi-company-logo.png
cp /loginvsi/img/logo_alt.png /loginvsi/img/logo.png
cp -r "/dockerrepo/$HOSTINGFOLDER/docker-compose.yml" /loginvsi/

version=$(grep "Version__Number" < /loginvsi/docker-compose.yml | cut -d':' -f2 | cut -d"'" -f2 | tail -1)
applianceversion=$(grep "Appliance_Version" < /loginvsi/docker-compose.yml | cut -d':' -f2 | cut -d"'" -f2 | tail -1)

echo "VERSION=\"$version\"" >> /loginvsi/build.conf



rm -rf /dockerrepo

 
rm /etc/pdmenurc

cp -f $SCRIPT_PATH/../loginvsid /usr/bin/
cp -f $SCRIPT_PATH/../loginvsid.service /etc/systemd/system/
cp -f $SCRIPT_PATH/../docker-cleanup.service /etc/systemd/system/
#cp -f $SCRIPT_PATH/firstrun /loginvsi/
cp -f $SCRIPT_PATH/../daemon.json /etc/docker



echo $INITIALHOSTNAME > /etc/hostname
hostname $INITIALHOSTNAME

echo "127.0.0.1	localhost $INITIALHOSTNAME $INITIALHOSTNAME.local
    127.0.1.1	$INITIALHOSTNAME.local
    # The following lines are desirable for IPv6 capable hosts
    ::1     localhost ip6-localhost ip6-loopback
    ff02::1 ip6-allnodes
    ff02::2 ip6-allrouters
" > /etc/hosts


echo "#!/bin/bash" > /home/admin/.bash_profile
echo "if [ ! -f '/loginvsi/first_run.chk' ]; then"  >> /home/admin/.bash_profile
echo "  echo 'admin' | sudo -S -p '' echo 'Starting LoginVSI configuration tool...'" >> /home/admin/.bash_profile
echo "  sudo /loginvsi/firstrun" >> /home/admin/.bash_profile
echo "fi" >> /home/admin/.bash_profile
chmod +x /home/admin/.bash_profile
chmod +x /loginvsi/firstrun
chmod +x /loginvsi/menu/*
chmod +x /loginvsi/bin/*

echo "admin:admin" | chpasswd

echo "Welcome to $TITLE - version $version ($applianceversion)
This system is not yet configured, please logon with username: admin and password: admin" > /etc/issue

echo '#!/bin/sh
[ -r /etc/lsb-release ] && . /etc/lsb-release

if [ -z "$DISTRIB_DESCRIPTION" ] && [ -x /usr/bin/lsb_release ]; then
        # Fall back to using the very slow lsb_release utility
        DISTRIB_DESCRIPTION=$(lsb_release -s -d)
fi

printf "Welcome to %s\n" "$TITLE"
printf "%s (%s %s %s)\n" "$DISTRIB_DESCRIPTION" "$(uname -o)" "$(uname -r)" "$(uname -m)"

' > /etc/update-motd.d/00-header

echo "[Link]
NamePolicy=kernel database onboard slot path
MACAddressPolicy=none" > /etc/systemd/network/99-default.link

rm /etc/motd

if [ -f '/etc/update-motd.d/10-help-text' ]; then
	rm /etc/update-motd.d/10-help-text
fi
if [ -f '/etc/update-motd.d/90-updates-available' ]; then
	rm /etc/update-motd.d/90-updates-available
fi


if [ -f "/loginvsi/first_run.chk" ]; then
    rm /loginvsi/first_run.chk
fi

echo "
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
" >>/etc/sysctl.conf

passwd -dl root &>/dev/null

netadapters=$(ip -o link show | while read -r num dev fam mtulabel mtusize qlabel queu statelabel state modelabel mode grouplabel group qlenlabel qlen maclabel mac brdlabel brcast; do 
        if [[ ${mac} != brd && ${mac} != 00:00:00:00:00:00 && ${dev} != br-*  && ${dev} != veth* ]]; then
            echo ${dev%/*}; 
        fi     
    done
    )
netadapter=$(echo $netadapters | tail -1 | awk '{split($1,n,":");print n[1]}')


echo "
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto $netadapter
iface $netadapter inet dhcp        
    " > /etc/network/interfaces

# Cleanup
rm -rf /home/admin/*
rm -rf /home/admin/.bash_history
rm -rf /home/admin/.git
rm -rf /root/.bash_history
rm -rf /root/.ssh

