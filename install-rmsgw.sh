#!/bin/bash

VERSION="1.3.5"

# This script installs the prerequisites as well as the libax25, ax25-tools,
# apps and the rmsgw software.  It also installs Hamlib and Direwolf.
#

function aptError () {
   echo
   echo
   echo
   echo >&2 "ERROR while running '$1'."
   echo
   echo >&2 "This is likely problem with a repository somewhere on the Internet.  Run this script again to retry."
   echo
   echo
   exit 1
}

sudo apt-get update || aptError "sudo apt-get update"
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential autoconf libtool git gcc g++ make cmake psmisc net-tools zlib1g zlib1g-dev libncurses5-dev libncursesw5-dev xutils-dev libxml2 libxml2-dev python-requests mariadb-client libmariadbclient-dev texinfo libasound2-dev libudev-dev unzip extra-xdg-menus gpsd libgps-dev yad iptables-persistent libhamlib2 libhamlib-dev || aptError "sudo apt-get -y install <various packages>"

## Remove multicast advertising protocol
#echo "Remove avahi-daemon and libnss-mdns"
#sudo dpkg -r avahi-daemon libnss-mdns 
#echo "Done."
#sudo apt-get -y autoremove || aptError "apt-get -y autoremove"

echo "Prevent the standard libax25 package from overwriting our version"
sudo apt-mark hold libax25
echo "Install libax25"
sudo dpkg --force-overwrite --install libax25_1.1.3-1_armhf.deb
[[ $? == 0 ]] || { echo >&2 "FAILED.  Aborting installation."; exit 1; }
echo "Done."

echo "Prevent the standard ax25-apps package from overwriting our version"
sudo apt-mark hold ax25-apps
echo "Install ax25-apps"
sudo dpkg --install ax25-apps_2.0.1-1_armhf.deb
[[ $? == 0 ]] || { echo >&2 "FAILED.  Aborting installation."; exit 1; }
echo "Done."

echo "Prevent the standard ax25-tools package from overwriting our version"
sudo apt-mark hold ax25-tools
echo "Install ax25-tools"
sudo dpkg --install ax25-tools_1.0.5-1_armhf.deb
[[ $? == 0 ]] || { echo >&2 "FAILED.  Aborting installation."; exit 1; }
echo "Done."

echo "Add rmsgw user"
sudo useradd -c 'Linux RMS Gateway' -d /etc/rmsgw -s /bin/false rmsgw
echo "Done."

#echo "Prevent the standard hamlib package from overwriting our version"
#sudo apt-get -y remove libhamlib2
#sudo apt-mark hold libhamlib2 libhamlib-dev
#echo "Install hamlib"
#sudo dpkg --install hamlib_4.0-1_armhf.deb
#[[ $? == 0 ]] || { echo >&2 "FAILED.  Aborting installation."; exit 1; }
#echo "Set up symlink for apps that still need access to hamlib via libhamlib.so.2"
#for F in libhamlib libhamlib++
#do
#   if ! [ -L /usr/lib/${F}.so.2 ]
#   then # There's no symlink.  Make one.
#      [ -f /usr/lib/${F}.so.2 ] && sudo mv /usr/lib/${F}.so.2 /usr/lib/${F}.so.2.old
#      sudo ln -s /usr/local/lib/${F}.so.4.0.0 /usr/lib/${F}.so.2
#   fi
#done
sudo ldconfig
#echo "Done."

echo "Install Direwolf"
git clone https://www.github.com/wb2osz/direwolf
cd direwolf
LATEST_VER="$(grep -m1 -i version src/version.h | sed 's/[^0-9.]//g')"
INSTALLED_VER="$(direwolf --version 2>/dev/null | grep -m1 -i "version" | sed 's/(.*)//g;s/[^0-9.]//g')"
[[ $INSTALLED_VER == "" || -f /usr/bin/direwolf ]] && INSTALLED_VER=0  # Development versions were installed in /usr/bin
[ -f /usr/bin/direwolf ] && sudo rm -f /usr/bin/direwolf # Remove older dev version
if [[ $INSTALLED_VER == $LATEST_VER ]]
then
	echo "Direwolf already installed"
else
	mkdir build && cd build
	cmake ..
	make -j4
	sudo make install
	echo "Done."
fi
cd ..
rm -rf direwolf
#make install-conf
#if ! command -v direwolf >/dev/null 2>&1
#then
#   sudo dpkg --install direwolf_1.6C-1_armhf.deb
#   [[ $? == 0 ]] || { echo >&2 "FAILED.  Aborting installation."; exit 1; }
#   sudo cp /usr/share/direwolf/examples/* /etc/ax25/
#   echo "Done."
#else
#   echo "Direwolf already installed"
#fi

echo "Install/update patmail.sh"
wget -q -O patmail.sh https://raw.githubusercontent.com/AG7GN/nexus-utilities/master/patmail.sh
[[ $? == 0 ]] || { echo >&2 "FAILED.  Could not download patmail.sh."; exit 1; }
chmod +x patmail.sh
sudo mv patmail.sh /usr/local/bin/
echo "Done."

echo "Install/update pat"
if ! command -v pat >/dev/null 2>&1
then # Install pat
   PAT_GIT_URL="$GITHUB_URL/la5nta/pat/releases"
   cd $HOME
   echo "============= pat installation requested from $PAT_GIT_URL ============="
   PAT_REL_URL="$(wget -qO - $PAT_GIT_URL | grep -m1 _linux_armhf.deb | grep -Eoi '<a [^>]+>' | grep -Eo 'href="[^\"]+"' | cut -d'"' -f2)"
   [[ $PAT_REL_URL == "" ]] && { echo >&2 "======= $PAT_GIT_URL download failed with $? ========"; exit 1; }
   #PAT_URL="${GITHUB_URL}${PAT_REL_URL}"
   PAT_URL="${PAT_REL_URL}"
   PAT_FILE="${PAT_URL##*/}"
   echo "============= Downloading $PAT_URL ============="
   wget -q -O $PAT_FILE $PAT_URL || { echo >&2 "======= $PAT_URL download failed with $? ========"; exit 1; }
   [ -s "$PAT_FILE" ] || { echo >&2 "======= $PAT_FILE is empty ========"; exit 1; }
  	sudo dpkg -i $PAT_FILE || { echo >&2 "======= pat installation failed with $? ========"; exit 1; }
   echo "============= pat installed ============="
	rm -f $PAT_FILE
else # pat already installed
   echo "pat already installed"
fi

echo "Retrieve the latest rmsgw software"
sudo mkdir -p /etc/rmsgw
[ -d /usr/local/etc/rmsgw ] && sudo rm -rf /usr/local/etc/rmsgw
sudo ln -s /etc/rmsgw /usr/local/etc/rmsgw 
rm -rf rmsgw/
git clone https://github.com/nwdigitalradio/rmsgw
[[ $? == 0 ]] || { echo >&2 "FAILED.  Aborting installation."; exit 1; }
echo "Install rmsgw"
cd rmsgw
./autogen.sh
./configure
make && sudo make install
[[ $? == 0 ]] || { echo >&2 "FAILED.  Aborting installation."; exit 1; }
cd ..
#sudo chown rmsgw /etc/rmsgw/gateway.conf
#sudo chown rmsgw /etc/rmsgw/*.xml
sudo chown -R rmsgw:rmsgw /etc/rmsgw/*

echo "Get the pitnc_setparams and pitnc_getparams software"
wget -q -O pitnc9K6params.zip http://www.tnc-x.com/pitnc9K6params.zip
if [[ $? == 0 ]]
then 
   unzip -o pitnc9K6params.zip
   chmod +x pitnc_*
   sudo cp -f pitnc_* /usr/local/bin/
   echo "Done."
else
   echo >&2 "WARNING: Could not download pitnc software."
fi

echo "Get nexus-iptables from github.com/AG7GN/iptables"
rm -rf nexus-iptables/
git clone https://github.com/AG7GN/nexus-iptables
[[ $? == 0 ]] || { echo >&2 "FAILED.  Aborting installation."; exit 1; }
echo "Done."

sudo rm -f /usr/local/share/applications/configure-rmsgw.desktop
sudo rm -f /usr/local/share/applications/rmsgw_monitor.desktop

echo "Make 'RMS Gateway Manager' menu item for the 'Ham Radio' menu"
cat > /tmp/rmsgw_config_monitor.desktop << EOF
[Desktop Entry]
Name=RMS Gateway Manager
GenericName=RMS Gateway Manager
Comment=RMS Gateway Manager
Exec=bash -c /usr/local/bin/rmsgw_manager.sh
Icon=/usr/share/raspberrypi-artwork/raspitr.png
Terminal=false
Type=Application
Categories=HamRadio;
Comment[en_US]=RMS Gateway Manager
EOF
sudo mv -f /tmp/rmsgw_config_monitor.desktop /usr/local/share/applications/

echo "Done."

echo "Installing scripts, firewall rules and logrotate files."
sudo cp -f usr/local/bin/rmschanstat.local /usr/local/bin/
# Remove old, now unused rmsgw_monitor.sh
sudo rm -f /usr/local/bin/rmsgw_monitor.sh
sudo cp -f usr/local/bin/rmsgw_manager.sh /usr/local/bin/
sudo cp -f etc/ax25/ax25-* /etc/ax25/
sudo cp -f etc/logrotate.d/* /etc/logrotate.d/
sudo cp -f etc/rsyslog.d/* /etc/rsyslog.d/
sudo systemctl restart rsyslog
sudo cp -f /etc/iptables/rules.v4 /etc/iptables/rules.v4.previous
sudo cp -f /etc/iptables/rules.v6 /etc/iptables/rules.v6.previous
sudo cp -f nexus-iptables/rules* /etc/iptables/
sudo chown root:root /etc/iptables/rules*
sudo cp -f rmsgw-activity.sh /usr/local/bin/
echo "Done."

echo
echo
echo "Installation complete."
echo
echo "Select 'Configure RMS Gateway' from the Ham Radio Raspberry"
echo "Pi menu to configure and activate the RMS Gateway."
echo
echo "Select 'RMS Gateway Monitor' to monitor the relevant log files"
echo "and to start/stop the RMS Gateway service (ax25.service)."
echo

