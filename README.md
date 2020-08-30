# Building an RMS Gateway on Raspberry Pi running Debian 10 (Buster)

VERSION 20200830

IMPORTANT: You must obtain a [Sysop Winlink account](https://www.winlink.org/content/join_gateway_sysop_team_sysop_guidelines) in order to operate an RMS Gateway.

IMPORTANT: To install the RMS Gateway, run the __install-rmsgw.sh__ script that is part of this package.  Once that is installed, run the __configure-rmsgw.sh__ script to configure and start the RMS Gateway.

# Installation

Run these commands in a terminal:

	sudo mkdir -p /usr/local/src/nexus
	sudo chown pi:pi /usr/local/src/nexus
	cd /usr/local/src/nexus
	git clone http://github.com/AG7GN/rmsgw
	cd rmsgw
	./install-rmsgw.sh

# Backup Documentation

The following is a summary of most of the steps that the __install-rmsgw.sh__ performs to install the RMS Gateway.  It is for documentation only - __USE THE SCRIPT TO INSTALL__!

## 1. Update package list
	sudo apt-get update
	sudo apt-get install build-essential autoconf libtool git psmisc net-tools

## 2. Install the VE7FET AX.25 packages

The Debian packages below were built for Raspberry Pi Buster using David Ranch's (KI6ZHD) excellent [instructions](http://www.trinityos.com/HAM/CentosDigitalModes/RPi/rpi2-setup.html#18.install-ax25).

### 2.1 libax25
#### 2.1.1 Prerequisites
	sudo apt install zlib1g zlib1g-dev

Prevent overwriting the VE7FET libax25 with the stock version of libax25:

	sudo apt-mark hold libax25
	
#### 2.1.2 Install
	sudo dpkg --install libax25_1.1.3-1_armhf.deb

### 2.2 ax25-apps
#### 2.2.1 Prerequisites
	sudo apt-get install libncurses5-dev libncursesw5-dev

Prevent overwriting the VE7FET ax25-apps with the stock version of ax25-apps:

	sudo apt-mark hold ax25-apps

#### 2.2.2 Install
	sudo dpkg --install ax25-apps_2.0.1-1_armhf.deb

### 2.3 ax25-tools
#### 2.3.1 Prerequisites
Prevent overwriting the VE7FET ax25-tools with the stock version of ax25-tools:
	
	sudo apt-mark hold ax25-tools

#### 2.3.2 Install
	sudo dpkg --install ax25-tools_1.0.5-1_armhf.deb

## 3. Install rmsgw
Adapted from [K4GBB's instructions](http://k4gbb.no-ip.org/docs/rmsgateinst.html).  This section requires you to edit several text files.  "Sudo edit" indicates you must have root privileges to edit the file(s) in that step.  In a terminal, run sudo followed by the name of your text editor of choice.  

Example:

	sudo nano /etc/ax25d/direwolf.conf
	
Or if you prefer an editor similar to Windows Notepad, run this command in the terminal:

	sudo leafpad
Ignore any warning messages that appear in the terminal.  Once Leafpad opens, click __File__ > __Open__ and then click on __File System__ to go the the top level folder. From there, navigate to the file location indicated in the steps below.

### 3.1 Create rmsgw user

	sudo useradd -c 'Linux RMS Gateway' -d /etc/rmsgw -s /bin/false rmsgw

### 3.2 Install Prerequisites

	sudo apt-get install xutils-dev libxml2 python-requests mysql-client libmariadbclient-dev libxml2-dev autoconf

### 3.3 Clone repository and build rmsgw
	
	cd ~
	git clone https://github.com/nwdigitalradio/rmsgw
	cd rmsgw
	./autogen.sh
	./configure
	make
	sudo make install

### 3.4 Make a symlink for /etc/rmsgw

	sudo ln -s /usr/local/etc/rmsgw /etc/rmsgw
	
### 3.5 Copy the default ax25d.conf.dist to /etc/ax25/ax25d.conf

	cd /etc/ax25
	sudo cp ax25d.conf.dist ax25d.conf

### 3.6 Sudo edit /etc/ax25/ax25d.conf.
Locate this line near the top of the file:

	[N0ONE VIA vhfdrop]

Just before that line, add the following lines, replacing `N0ONE` with your call sign.

	[N0ONE-10 VIA vhfdrop]
	NOCALL   * * * * * *  L
	N0CALL   * * * * * *  L
	default  * * * * * *  - rmsgw  /usr/local/bin/rmsgw   rmsgw -l debug -P %d %U
	#

### 3.7 Sudo edit /etc/rmsgw/banner

Add text as desired.  The radio transmits this banner text, so keep it short.  Example:

    **** My RMS Gateway **** 

### 3.8 Sudo edit /etc/rmsgw/channels.xml

Replace `channel name="0"` with `channel name="vhfdrop"`.

Change __basecall, callsign, password, gridquare, frequency__ (in Hz), __baud, power, height, gain, direction, hours, groupreference,__ and __servicecode__ as needed.

	<?xml version="1.0" encoding="UTF-8"?>
	<rmschannels xmlns="http://www.namespace.org"
		xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  		xsi:schemaLocation="file:///etc/rmsgw/channels.xsd">
  		<channel name="0" type="ax25" active="yes">
 		   	<basecall>N0ONE</basecall>
    		<callsign>N0ONE-10</callsign>
    		<password>password</password>
    		<gridsquare>AA00aa</gridsquare>
    		<frequency>144930000</frequency>
    		<mode>0</mode>
    		<autoonly>0</autoonly>
    		<baud>1200</baud>
    		<power>25</power>
    		<height>25</height>
    		<gain>4</gain>
    		<direction>0</direction>
    		<hours>24/7</hours>
    		<groupreference>1</groupreference>
    		<servicecode>PUBLIC</servicecode>
    		<statuschecker>
      			/usr/local/bin/rmschanstat.local $type $name $callsign
    		</statuschecker>
  		</channel>
	</rmschannels>
	
#### 3.8.1 Make a local copy of /usr/local/bin/rmschanstat

	sudo cp /usr/local/bin/rmschanstat /usr/local/bin/rmschanstat.local

#### 3.8.2 Sudo edit /usr/local/bin/rmschanstat.local

Change this line:

	AXPORTS=@axports@

to:

	AXPORTS=/etc/ax25/axports
	
and change this line:

	IP=($(ps ax | grep attach | sed -n -e "s/^.*${NAME} //p" ))

to:

	IP=($(ps ax | grep kissattach | sed -n -e "s/^.*${NAME} //p" ))

### 3.9 Sudo edit /etc/rmsgw/sysop.xml

Change __Callsign, Password, GridSquare, SysopName, StreetAddress1, StreetAddress2, City, State, Country, PostalCode, Email, Phones,	Website, Comments__ as needed.

	<sysops vcsAuthor="$Author: eckertb $" vcsId="$Id: sysop-template.xml 157 2013-12-07 12:29:28Z eckertb $" vcsRevision="$Revision: 157 $">
  		<sysop>
    		<Callsign>N0ONE</Callsign>
    		<Password>password</Password>
    		<GridSquare>AA00aa</GridSquare>
    		<SysopName>No One</SysopName>
    		<StreetAddress1>123 Main Street</StreetAddress1>
    		<StreetAddress2 />
    		<City>Anytown</City>
    		<State>WA</State>
    		<Country>USA</Country>
    		<PostalCode>98225</PostalCode>
    		<Email>N0ONE@example.com</Email>
    		<Phones />
    		<Website />
    		<Comments />
  		</sysop>
	</sysops>

### 3.10 Sudo edit /etc/rmsgw/gateway.conf

Change __GWCALL__ and __GRIDSQUARE__ as needed.

	GWCALL=N0ONE-10
	GRIDSQUARE=AA00aa
	CHANNELFILE=/etc/rmsgw/channels.xml
	BANNERFILE=/etc/rmsgw/banner
	LOGFACILITY=LOCAL0
	LOGMASK=INFO
	PYTHON=/usr/bin/python

## 4. Install Hamlib

### 4.1 Prerequisites
	sudo apt-get install texinfo build-essential autoconf libtool git

### 4.2 Install

	sudo apt-get install libhamlib2 libhamlib-dev
	
## 5. Install Direwolf

### 5.1 Prerequisites
	sudo apt-get install libasound2-dev unzip extra-xdg-menus gpsd libgps-dev
	
### 5.2 Install
	cd ~
	sudo dpkg --install direwolf_1.6C-1_armhf.deb
	sudo cp /usr/share/doc/direwolf/examples/direwolf.conf /etc/ax25/
	
NOTE:  There's lots of good information about Direwolf, it's configuration and operation in the `/usr/share/doc/direwolf/examples` folder.

### 5.3 Configure

Select either the Left or Right radio configuration depending on which port your radio connects to on the DigiLink board, or select Signalink if you are using that audio device.

#### 5.3.1 "Left" Radio on DigiLink/FePi
Sudo edit /etc/ax25/direwolf.conf and change __MYCALL__:

	ADEVICE fepi-capture-left fepi-playback-left
	ACHANNELS 1
	CHANNEL 0
	ARATE 96000
	MODEM 1200
	MYCALL N0ONE
	PTT GPIO 12

#### 5.3.2 "Right" Radio on DigiLink/FePi
Sudo edit /etc/ax25/direwolf.conf and change __MYCALL__:

	ADEVICE fepi-capture-right fepi-playback-right
	ACHANNELS 1
	CHANNEL 0
	ARATE 96000
	MODEM 1200
	MYCALL N0ONE
	PTT GPIO 23

#### 5.3.3 Signalink
Sudo edit /etc/ax25/direwolf.conf and change __MYCALL__:

	ADEVICE plughw:CARD=1,DEV=0
	ACHANNELS 1
	CHANNEL 0
	ARATE 48000
	MODEM 1200
	MYCALL N0ONE

## 6. Install RMS Gateway Monitor script

### 6.1 Prerequisites
	sudo apt install yad extra-xdg-menus

### 6.2 Install
Create the `/usr/local/share/applications/rmsgw_monitor.desktop` file with this text:
	[Desktop Entry]
	Name=RMS Gateway Monitor
	GenericName=RMS Gateway Monitor
	Comment=RMS Gateway Monitor
	Exec=bash -c /usr/local/bin/rmsgw_monitor.sh
	Icon=/usr/share/raspberrypi-artwork/raspitr.png
	Terminal=false
	Type=Application
	Categories=HamRadio;
	Comment[en_US]=RMS Gateway Monitor

Install the `rmsgw_monitor.sh` script in `/usr/local/bin/`:
	sudo cp usr/local/bin/rmsgw_monitor.sh /usr/local/bin/





