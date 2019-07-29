#!/bin/bash

# Version 1.0.18

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
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential autoconf libtool git psmisc net-tools zlib1g zlib1g-dev libncurses5-dev libncursesw5-dev xutils-dev libxml2 libxml2-dev python-requests mariadb-client libmariadbclient-dev texinfo libasound2-dev unzip extra-xdg-menus gpsd libgps-dev yad iptables-persistent libhamlib2 libhamlib-dev || aptError "sudo apt=get -y install <various  packages>"

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
if ! which direwolf >/dev/null
then
   sudo dpkg --install direwolf_1.6C-1_armhf.deb
   [[ $? == 0 ]] || { echo >&2 "FAILED.  Aborting installation."; exit 1; }
   sudo cp /usr/share/direwolf/examples/* /etc/ax25/
   echo "Done."
else
   echo "Direwolf already installed"
fi

echo "Get the latest rmsgw software using git"
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

echo "Make 'Configure RMS Gateway' menu item for the 'Ham Radio' menu"
cat > $HOME/.local/share/applications/configure-rmsgw.desktop << EOF
[Desktop Entry]
Name=Configure RMS Gateway
GenericName=Configure RMS Gateway
Comment=Configure RMS Gateway and supporting apps
Exec=lxterminal --geometry=90x30 -t "Configure RMS Gateway" -e "$HOME/rmsgw/configure-rmsgw.sh"
Icon=/usr/share/raspberrypi-artwork/raspitr.png
Terminal=false
Type=Application
Categories=HamRadio;
Comment[en_US]=Configure RMS Gateway
EOF
echo "Done."

echo "Installing scripts, firewall rules and logrotate files."
sudo cp -f usr/local/bin/rmschanstat.local /usr/local/bin/
chmod +x etc/ax25/ax25-down
sudo cp -f etc/ax25/ax25-down /etc/ax25/
sudo cp -f etc/logrotate.d/* /etc/logrotate.d/
sudo cp -f /etc/iptables/rules.v4 /etc/iptables/rules.v4.previous
sudo cp -f /etc/iptables/rules.v6 /etc/iptables/rules.v6.previous
sudo cp -f etc/iptables/rules* /etc/iptables/
sudo chown root:root /etc/iptables/rules*
echo "Done."

echo
echo
echo "Installation complete."
echo
echo "Select 'Configure RMS Gateway' from the Ham Radio Raspberry"
echo "Pi menu to configure and activate the RMS Gateway."
echo
echo "You might have to edit the Raspberry Pi menus to make the Ham Radio menu visible."
echo "Click Raspberry > Preferences > Main Menu Editor, then select 'Hamradio' in the"
echo "left pane.  Check/uncheck menu items as desired in the middle pane."
echo
echo "CAUTION: NEVER click \"Cancel\" in the Main Menu editor!  Doing so will revert the"
echo "menus to the default configuration without warning."  
echo
echo


