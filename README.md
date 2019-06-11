# Building an RMS Gateway on Raspberry Pi Stretch

IMPORTANT: You must obtain a [Sysop Winlink account](https://www.winlink.org/content/join_gateway_sysop_team_sysop_guidelines) in order to operate an RMS Gateway.

## 1. Update package list
	sudo apt-get update
	sudo apt-get install git

## 2. Install the VE7FET AX.25 packages

The DEB packages below were built for Raspberry Pi Stretch using David Ranch's (KI6ZHD) excellent [instructions](http://www.trinityos.com/HAM/CentosDigitalModes/RPi/rpi2-setup.html#18.install-ax25).

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

Prevent overwriting the VE7FET libax25 with the stock version of ax25-apps:

	sudo apt-mark hold ax25-apps

#### 2.2.2 Install
	sudo dpkg --install ax25-apps_2.0.1-1_armhf.deb
    sudo cp -n /usr/share/doc/ax25apps/conf/ax25ipd.conf.dist /etc/ax25/ax25ipd.conf
    sudo cp -n /usr/share/doc/ax25apps/conf/ax25mond.conf.dist /etc/ax25/ax25mond.conf
    sudo cp -n /usr/share/doc/ax25apps/conf/ax25rtd.conf.dist /etc/ax25/ax25rtd.conf

### 2.3 ax25-tools
#### 2.3.1 Prerequisites
Prevent overwriting the VE7FET libax25 with the stock version of ax25-tools:
	
	sudo apt-mark hold ax25-tools

#### 2.3.2 Install
	sudo dpkg --install ax25-tools_1.0.5-1_armhf.deb
    sudo cp -n /usr/share/doc/ax25tools/conf/ax25d.conf.dist /etc/ax25/ax25d.conf
    sudo cp -n /usr/share/doc/ax25tools/conf/axports.dist /etc/ax25/axports
    sudo cp -n /usr/share/doc/ax25tools/conf/axspawn.conf.dist /etc/ax25/axspawn.conf
    sudo cp -n /usr/share/doc/ax25tools/conf/nrbroadcast.dist /etc/ax25/nrbroadcast
    sudo cp -n /usr/share/doc/ax25tools/conf/nrports.dist /etc/ax25/nrports
    sudo cp -n /usr/share/doc/ax25tools/conf/rsports.dist /etc/ax25/rsports
    sudo cp -n /usr/share/doc/ax25tools/conf/rxecho.conf.dist /etc/ax25/rxecho.conf
    sudo cp -n /usr/share/doc/ax25tools/conf/ttylinkd.conf.dist /etc/ax25/ttylinkd.conf

## 3. Install rmsgw
Adapted from [K4GBB's instructions](http://k4gbb.no-ip.org/docs/rmsgateinst.html).  You must be root to edit the files in the steps that follow.  In a terminal, run sudo followed by the name of your text editor of choice. 

### 3.1 Create rmsgw user

	sudo adduser rmsgw --no-create-home --disabled-password

### 3.2 Install Prerequisites

	sudo apt-get install xutils-dev libxml2 python-requests mysql-client libmariadbclient-dev libxml2-dev

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
	
### 3.5 Configure /etc/ax25/ax25d.conf

Replace N0ONE with your call sign.

	[N0ONE-10 VIA 0]
	NOCALL   * * * * * *  L
	N0CALL   * * * * * *  L
	default  * * * * * *  - rmsgw  /usr/local/bin/rmsgw   rmsgw -l debug -P %d %U

### 3.6 Configure /etc/rmsgw/banner

Add text as desired.  The radio transmits this banner text, so keep it short.  Example:

    **** My RMS Gateway **** 

### 3.7 Configure /etc/rmsgw/channels.xml

Change basecall, callsign, password, gridquare, frequency, baud, power, height, gain, direction, hours, groupreference, and servicecode as needed.

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
	
#### 3.7.1 Make a local copy of /usr/local/bin/rmschanstat

sudo cp /usr/local/bin/rmschanstat /usr/local/bin/rmschanstat.local

#### 3.7.2 Edit /usr/local/bin/rmschanstat.local

Change this line:

	AXPORTS=%axports%

to:

	AXPORTS=/etc/ax25/axports
	
and change this line:

	IP=($(ps ax | grep attach | sed -n -e "s/^.*${NAME} //p" ))

to:

	IP=($(ps ax | grep kissattach | sed -n -e "s/^.*${NAME} //p" ))

### 3.8 Configure /etc/rmsgw/sysop.xml

Change as needed.

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

### 3.9 Configure /etc/rmsgw/gateway.conf

Change GWCALL and GRIDSQUARE as needed.

	GWCALL=N0ONE-10
	GRIDSQUARE=AA00aa
	CHANNELFILE=/etc/rmsgw/channels.xml
	BANNERFILE=/etc/rmsgw/banner
	LOGFACILITY=LOCAL0
	LOGMASK=INFO
	PYTHON=/usr/bin/python

## 4. Install Hamlib

### 4.1 Prerequisites
	sudo apt-get install texinfo

### 4.2 Install
	cd ~
	sudo dpkg --install hamlib_3.3-1_armhf.deb
	
## 5. Install Direwolf

### 5.1 Prerequisites
	sudo apt-get install libasound2-dev unzip
	sudo apt-get install gpsd libgps-dev
	
### 5.2 Install
	cd ~
	sudo dpkg --install direwolf_1.5-1_armhf.deb
	sudo cp ~/direwolf.conf /etc/ax25/

### 5.3 Configure

Select either the Left or Right radio configuration depending on which port your radio connects to on the DigiLink board, or select Signalink if you are using that device.

#### 5.3.1 "Left" Radio on DigiLink Board
Create or edit /etc/ax25/direwolf.conf and change MYCALL:

	ADEVICE fepi-capture-left fepi-playback-left
	ACHANNELS 1
	CHANNEL 0
	ARATE 96000
	MODEM 1200
	MYCALL N0ONE
	MODEM 1200
	PTT GPIO 12

#### 5.3.2 "Right" Radio on DigiLink Board
Create or edit /etc/ax25/direwolf.conf and change MYCALL:

	ADEVICE fepi-capture-right fepi-playback-right
	ACHANNELS 1
	CHANNEL 0
	ARATE 96000
	MODEM 1200
	MYCALL N0ONE
	MODEM 1200
	PTT GPIO 23

#### 5.3.3 Signalink
Create or edit /etc/ax25/direwolf.conf and change MYCALL:

	ADEVICE plughw:CARD=1,DEV=0
	ACHANNELS 1
	CHANNEL 0
	ARATE 48000
	MODEM 1200
	MYCALL N0ONE
	MODEM 1200





