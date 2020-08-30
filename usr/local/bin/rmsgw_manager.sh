#!/bin/bash
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+   ${SCRIPT_NAME} [-hv]
#%
#% DESCRIPTION
#%   This script provides a GUI to configure, start/stop, and 
#%   monitor the RMS Gateway applications.  
#%   It is designed to work on the Nexus image.
#%
#% OPTIONS
#%    -h, --help                  Print this help
#%    -v, --version               Print script information
#%
#================================================================
#- IMPLEMENTATION
#-    version         ${SCRIPT_NAME} 1.0.0
#-    author          Steve Magnuson, AG7GN
#-    license         CC-BY-SA Creative Commons License
#-    script_id       0
#-
#================================================================
#  HISTORY
#     20200428 : Steve Magnuson : Script creation.
#     20200507 : Steve Magnuson : Bug fixes
# 
#================================================================
#  DEBUG OPTION
#    set -n  # Uncomment to check your syntax, without execution.
#    set -x  # Uncomment to debug this shell script
#
#================================================================
# END_OF_HEADER
#================================================================

SYNTAX=false
DEBUG=false
Optnum=$#

#============================
#  FUNCTIONS
#============================

function TrapCleanup() {
   [[ -d "${TMPDIR}" ]] && rm -rf "${TMPDIR}/"
   for P in ${PIDs[@]}
	do
		kill $P >/dev/null 2>&1
	done
	pkill -f "yad --title=Configure RMS Gateway.*" >/dev/null 2>&1
	rm -f $PIPE
	unset CheckDaemon
	unset RestartAX25Service
	unset CheckDaemon 
	unset RestartAX25Service 
	unset ConfigureRMSGateway 
	unset SaveSettings 
	unset UpdateReporting 
	unset SetFormFields 
	unset LoadSettings
	unset RMSGW_CONFIG_FILE
	unset RMSGW_TEMP_CONFIG
	unset PIPEDATA
}

function SafeExit() {
   trap - INT TERM EXIT SIGINT
	TrapCleanup
   exit 0
}

function ScriptInfo() { 
	HEAD_FILTER="^#-"
	[[ "$1" = "usage" ]] && HEAD_FILTER="^#+"
	[[ "$1" = "full" ]] && HEAD_FILTER="^#[%+]"
	[[ "$1" = "version" ]] && HEAD_FILTER="^#-"
	head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "${HEAD_FILTER}" | \
	sed -e "s/${HEAD_FILTER}//g" \
	    -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" \
	    -e "s/\${SPEED}/${SPEED}/g" \
	    -e "s/\${DEFAULT_PORTSTRING}/${DEFAULT_PORTSTRING}/g"
}

function Usage() { 
	printf "Usage: "
	ScriptInfo usage
	exit
}

function Die() {
	echo "${*}"
	SafeExit
}

function clearTextInfo() {
	# Arguments: $1 = sleep time.
	# Send FormFeed character every $1 minutes to clear yad text-info
	local TIMER=$1 
	while sleep $TIMER
	do
		#echo -e "\nTIMESTAMP: $(date)" 
		echo -e "\f"
		echo "$(date) Cleared monitor window. Window is cleared every $TIMER."
	done >$PIPEDATA
}

function CheckDaemon() {
	local TITLE="RMS Gateway Status"
	local STATUS=""
	local T=5
	if systemctl list-unit-files | grep -q "ax25.*enabled"
	then # ax25.service installed and enabled
	   STATUS="<b><big><span color='green'>Enabled"
	   if systemctl | grep -q "ax25.*running"
	   then
			STATUS+=" and Running</span></big></b>"
		else
	      STATUS+="</span><span color='red'> but Not Running</span></big></b>"
	   fi
	else # ax25.service not installed/enabled
		STATUS="<b><big><span color='red'>Not Enabled</span></big></b>"
	fi
  	yad --center --title="$TITLE" --text="$STATUS\nThis window will close in $T seconds" \
  		--width=400 --height=100 \
  		--borders=10 --text-align=center \
  		--timeout=$T --timeout-indicator=bottom \
  		--no-buttons
}

function RestartAX25Service() {
	if systemctl list-unit-files | grep enabled | grep -q ax25
	then # ax25 service is enabled.
		if systemctl | grep running | grep -q ax25.service
		then # ax25 is running.  Restart it.
			echo "Restarting ax25 service..." >$PIPEDATA
			sudo systemctl restart ax25 2>$PIPEDATA || echo -e "\n\n*** ERROR restarting: Is RMS Gateway configured?" >$PIPEDATA
		else # ax25 is stopped. Start it.
			echo "Starting ax25 service..." >$PIPEDATA
   		sudo systemctl start ax25 2>$PIPEDATA || echo -e "\n\n*** ERROR starting: Is RMS Gateway configured?" >$PIPEDATA
  		fi
	else # ax25 service is not enabled.  Create it.
   	echo -e "\n\n*** ERROR: RMS Gateway is not enabled. Click 'Configure' to set it up." >$PIPEDATA
	fi
	return 0
}

function LoadSettings() {
	if [ -s "$RMSGW_CONFIG_FILE" ]
	then # There is a config file
   	echo "Configuration file $RMSGW_CONFIG_FILE found." >$PIPEDATA
	else # Set some default values in a new config file
   	echo "Configuration file $RMSGW_CONFIG_FILE not found.  Creating a new one with default values."  >$PIPEDATA
		echo "declare -A F" > "$RMSGW_CONFIG_FILE"
		echo "F[_CALL_]='N0CALL'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_SSID_]='10'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_PASSWORD_]='password'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_SYSOP_]='John Smith'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_GRID_]='CN88ss'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_ADDR1_]='123 Main Street'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_ADDR2_]=''" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_CITY_]='Anytown'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_STATE_]='WA'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_ZIP_]='98225'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_BEACON_]='!4850.00N/12232.27W]144.920MHzMy RMS Gateway'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_EMAIL_]='n0one@example.com'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_FREQ_]='144920000'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_POWER_]='3'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_HEIGHT_]='2'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_GAIN_]='7'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_DIR_]='0'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_HOURS_]='24/7'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_SERVICE_]='PUBLIC'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_TNC_]='direwolf'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_MODEM_]='1200'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_ADEVICE_CAPTURE_]='null'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_ADEVICE_PLAY_]='null'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_ARATE_]='96000'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_PTT_]='GPIO 23'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_DWUSER_]='$(whoami)'" >> "$RMSGW_CONFIG_FILE"
  		echo "F[_BANNER_]='*** My Banner ***'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_REPORTS_]='FALSE'" >> "$RMSGW_CONFIG_FILE"
	fi
}

function SetFormFields () {
	
	# Set YAD variables
	TNCs="tncpi~direwolf"
	[[ $TNCs =~ ${F[_TNC_]} ]] && TNCs="$(echo "$TNCs" | sed "s/${F[_TNC_]}/\^${F[_TNC_]}/")" 

	MODEMs="1200~9600"
	[[ $MODEMs =~ ${F[_MODEM_]} ]] && MODEMs="$(echo "$MODEMs" | sed "s/${F[_MODEM_]}/\^${F[_MODEM_]}/")" 

	SERVICEs="PUBLIC~EMCOMM"
	[[ $SERVICEs =~ ${F[_SERVICE_]} ]] && SERVICEs="$(echo "$SERVICEs" | sed "s/${F[_SERVICE_]}/\^${F[_SERVICE_]}/")" 

	if pgrep pulseaudio >/dev/null 2>&1
	then # There may be pulseaudio ALSA devices.  Look for them.
		CAPTURE_IGNORE="$(pacmd list-sinks 2>/dev/null | grep name: | tr -d '\t' | cut -d' ' -f2 | sed 's/^<//;s/>$//' | tr '\n' '\|' | sed 's/|/\\|/g')"
		ADEVICE_CAPTUREs="$(arecord -L | grep -v "$CAPTURE_IGNORE^ .*\|^dsnoop\|^sys\|^default\|^dmix\|^hw\|^usbstream\|^jack\|^pulse" | tr '\n' '~' | sed 's/~$//')"
		PLAYBACK_IGNORE="$(pacmd list-sources 2>/dev/null | grep name: | tr -d '\t' | cut -d' ' -f2 | sed 's/^<//;s/>$//' | tr '\n' '\|' | sed 's/|/\\|/g')"
		ADEVICE_PLAYBACKs="$(aplay -L | grep -v "$PLAYBACK_IGNORE^ .*\|^dsnoop\|^sys\|^default\|^dmix\|^hw\|^usbstream\|^jack\|^pulse" | tr '\n' '~' | sed 's/~$//')"
	else  # pulseaudio isn't running.  Check only for null and plughw devices
   	ADEVICE_CAPTUREs="$(arecord -L | grep "^null\|^plughw" | tr '\n' '~' | sed 's/~$//')"
   	ADEVICE_PLAYBACKs="$(aplay -L | grep "^null\|^plughw" | tr '\n' '~' | sed 's/~$//')"
	fi
	[[ $ADEVICE_CAPTUREs =~ ${F[_ADEVICE_CAPTURE_]} ]] && ADEVICE_CAPTUREs="$(echo "$ADEVICE_CAPTUREs" | sed "s/${F[_ADEVICE_CAPTURE_]}/\^${F[_ADEVICE_CAPTURE_]}/")"
	[[ -z $ADEVICE_CAPTUREs ]] && ADEVICE_CAPTUREs="null"
	[[ $ADEVICE_PLAYBACKs =~ ${F[_ADEVICE_PLAY_]} ]] && ADEVICE_PLAYBACKs="$(echo "$ADEVICE_PLAYBACKs" | sed "s/${F[_ADEVICE_PLAY_]}/\^${F[_ADEVICE_PLAY_]}/")"
	[[ -z $ADEVICE_PLAYBACKs ]] && ADEVICE_PLAYBACKs="null"

	ARATEs="44100~48000~96000"
	[[ $ARATEs =~ ${F[_ARATE_]} ]] && ARATEs="$(echo "$ARATEs" | sed "s/${F[_ARATE_]}/\^${F[_ARATE_]}/")" 

	PTTs="GPIO 12~GPIO 23"
	if [[ $PTTs =~ ${F[_PTT_]} ]]
	then
		PTTs="$(echo "$PTTs" | sed "s/${F[_PTT_]}/\^${F[_PTT_]}/")" 
	else
		PTTs+="~^${F[_PTT_]}"
	fi

}

function UpdateReporting () {
	PAT_DIR="$HOME/.wl2kgw"
	WHO="$USER"
	SCRIPT="$(command -v rmsgw-activity.sh)"
	PAT="$(command -v pat) --config $PAT_DIR/config.json --mbox $PAT_DIR/mailbox --send-only --event-log /dev/null connect telnet"
	CLEAN="find $PAT_DIR/mailbox/${F[_CALL_]}/sent -type f -mtime +30 -exec rm -f {} \;"
# remove old style pat cron job, which used the default config.json pat configuration
	OLDPAT="$(command -v pat) --send-only --event-log /dev/null connect telnet"
	cat <(fgrep -i -v "$OLDPAT" <(sudo crontab -u $WHO -l)) | sudo crontab -u $WHO -
	if [[ ${F[_REPORTS_]} == "TRUE" ]]
	then # Daily email reports requested
		if [[ ${F[_EMAIL_]} =~ ^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:].]{2,4}$ ]]
		then # user has supplied a well-formed Sysop email address
      	echo "Setting up reporting." >$PIPEDATA
			if command -v pat >/dev/null 2>&1
			then
				# Check for pat's config file, config.json.  Create it if missing or corrupted.
				if $(command -v jq) . $PAT_DIR/config.json >/dev/null 2>&1
				then
					echo "$PAT_DIR/config.json exists." >$PIPEDATA
				else # config.json missing or corrupted.  Make a new one.
            	echo "Making new $PAT_DIR/config.json file." >$PIPEDATA
					[[ -f $PAT_DIR/config.json ]] && rm -f $PAT_DIR/config.json
            	mkdir -p $PAT_DIR
					cd $HOME
					export EDITOR=ed
					echo -n "" | pat --config $PAT_DIR/config.json configure >/dev/null 2>&1
				fi
 				cat $PAT_DIR/config.json | jq \
					--arg C "${F[_CALL_]}" \
					--arg P "${F[_PASSWORD_]}" \
					--arg L "${F[_GRID_]}" \
						'.mycall = $C | .secure_login_password = $P | .locator = $L' | sponge $PAT_DIR/config.json
				echo "Installing cron job for report generation and email for user $WHO" >$PIPEDATA
				WHEN="1 0 * * *"
				WHAT="$SCRIPT ${F[_EMAIL_]} $PAT_DIR >/dev/null 2>&1"
				JOB="$WHEN PATH=\$PATH:/usr/local/bin; $WHAT"
				cat <(fgrep -i -v "$SCRIPT" <(sudo crontab -u $WHO -l)) <(echo "$JOB") | sudo crontab -u $WHO -
				WHEN="3 * * * *"
				WHAT="$PAT >/dev/null 2>&1"
				JOB="$WHEN PATH=\$PATH:/usr/local/bin; $WHAT"
				cat <(fgrep -i -v "$PAT" <(sudo crontab -u $WHO -l)) <(echo "$JOB") | sudo crontab -u $WHO -
				# Purge sent messages older than 30 days
				echo "Installing cron to purge sent messages older than 30 days" >$PIPEDATA
				WHEN="7 0 * * *"
				WHAT="$CLEAN"
				JOB="$WHEN $WHAT"
				cat <(fgrep -i -v "$WHAT" <(sudo crontab -u $WHO -l)) <(echo "$JOB") | sudo crontab -u $WHO -
				echo "Done." >$PIPEDATA
				echo "Reporting setup complete." >$PIPEDATA
		else
				echo "pat not found but is needed to email reports. Reporting will not be enabled." >$PIPEDATA
				F[_REPORTS_]=FALSE
			fi
		else
			echo "Invalid or missing Sysop email address.  Reporting will not be enabled." >$PIPEDATA
			F[_REPORTS_]=FALSE
		fi
	else # Reporting disabled. Remove report cron job if present
		echo "Remove Reporting" >$PIPEDATA
		cat <(fgrep -i -v "$SCRIPT" <(sudo crontab -u $WHO -l)) | sudo crontab -u $WHO -
		cat <(fgrep -i -v "$PAT" <(sudo crontab -u $WHO -l)) | sudo crontab -u $WHO -
		cat <(fgrep -i -v "$CLEAN" <(sudo crontab -u $WHO -l)) | sudo crontab -u $WHO -
	fi
}

function SaveSettings () {
	IFS='~' read -r -a TF < "$RMSGW_TEMP_CONFIG"
	F[_CALL_]="${TF[0]^^}"
	F[_SSID_]="${TF[1]}"
	F[_PASSWORD_]="${TF[2]}"
	F[_SYSOP_]="${TF[3]}"
	F[_GRID_]="${TF[4]}"
	F[_ADDR1_]="${TF[5]}"
	F[_ADDR2_]="${TF[6]}"
	F[_CITY_]="${TF[7]}"
	F[_STATE_]="${TF[8]}"
	F[_ZIP_]="${TF[9]}"
	F[_BEACON_]="${TF[10]}"
	F[_EMAIL_]="${TF[11]}"
	F[_FREQ_]="${TF[12]}"
	F[_POWER_]="${TF[13]}"
	F[_HEIGHT_]="${TF[14]}"
	F[_GAIN_]="${TF[15]}"
	F[_DIR_]="${TF[16]}"
	F[_HOURS_]="${TF[17]}"
	F[_SERVICE_]="${TF[18]}"
	F[_TNC_]="${TF[19]}"
	F[_MODEM_]="${TF[20]}"
	F[_ADEVICE_CAPTURE_]="${TF[21]}"
	F[_ADEVICE_PLAY_]="${TF[22]}"
	F[_ARATE_]="${TF[23]}"
	F[_PTT_]="${TF[24]}"
	F[_DWUSER_]="${TF[25]}"
	F[_BANNER_]="$(echo "${TF[26]}" | sed "s/'//g")" # Strip out single quotes
	F[_REPORTS_]="${TF[27]}"

	# Do some minimal error checking
	if [[ ${F[_CALL_]} =~ ^N0(CALL|ONE)$ || \
			${F[_PASSWORD_]} == "" || \
			${F[_EMAIL_],,} =~ @example.com$ || \
			! ${F[_EMAIL_],,} =~ ^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:].]{2,4}$ ]]
	then
		echo -e "\n**** CONFIGURATION ERROR ****: Invalid Sysop call sign or empty password or\ninvalid email address." >$PIPEDATA
		return 1
	fi

	UpdateReporting

	# Update the configuration file
	echo "declare -A F" > "$RMSGW_CONFIG_FILE"
	for I in "${!F[@]}"
	do
		echo "F[$I]='${F[$I]}'" >> "$RMSGW_CONFIG_FILE"
	done

	# Update the various RMS gateway configuration files
	TEMPF=$RMSGW_TEMP_CONFIG
	cd /usr/local/src/hampi/rmsgw/

	FNAME="etc/rmsgw/channels.xml"
	sed "s|_CALL_|${F[_CALL_]}|g;s|_SSID_|${F[_SSID_]}|;s|_PASSWORD_|${F[_PASSWORD_]}|;s|_GRID_|${F[_GRID_]}|;s|_FREQ_|${F[_FREQ_]}|;s|_MODEM_|${F[_MODEM_]}|;s|_POWER_|${F[_POWER_]}|;s|_HEIGHT_|${F[_HEIGHT_]}|;s|_GAIN_|${F[_GAIN_]}|;s|_DIR_|${F[_DIR_]}|;s|_HOURS_|${F[_HOURS_]}|;s|_SERVICE_|${F[_SERVICE_]}|" "$FNAME" > "$TEMPF" 
	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
	sudo cp -f "$TEMPF" "/$FNAME"
	echo "/$FNAME configured." >$PIPEDATA

	FNAME="etc/rmsgw/banner"
	echo "${F[_BANNER_]}" > "$TEMPF"
	sudo cp -f "$TEMPF" "/$FNAME"
	echo "/$FNAME configured." >$PIPEDATA

	FNAME="etc/rmsgw/gateway.conf"
	sed "s|_CALL_|${F[_CALL_]}|g;s|_SSID_|${F[_SSID_]}|;s|_GRID_|${F[_GRID_]}|" "$FNAME" > "$TEMPF"
	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
	sudo cp -f "$TEMPF" "/$FNAME"
	echo "/$FNAME configured." >$PIPEDATA

	FNAME="etc/rmsgw/sysop.xml"
	sed "s|_CALL_|${F[_CALL_]}|g;s|_PASSWORD_|${F[_PASSWORD_]}|;s|_GRID_|${F[_GRID_]}|;s|_SYSOP_|${F[_SYSOP_]}|;s|_ADDR1_|${F[_ADDR1_]}|;s|_ADDR2_|${F[_ADDR2_]}|;s|_CITY_|${F[_CITY_]}|;s|_STATE_|${F[_STATE_]}|;s|_ZIP_|${F[_ZIP_]}|;s|_EMAIL_|${F[_EMAIL_]}|" "$FNAME" > "$TEMPF"
	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
	sudo cp -f "$TEMPF" "/$FNAME"
	echo "/$FNAME configured." >$PIPEDATA

	FNAME="etc/ax25/axports"
	sed -i '/^[[:space:]]*$/d' $FNAME
	sed "s|_CALL_|${F[_CALL_]}|g;s|_SSID_|${F[_SSID_]}|g;s|_FREQ_|${F[_FREQ_]}|g;s|_MODEM_|${F[_MODEM_]}|g" "$FNAME" > "$TEMPF"
	[[ $? == 0 ]] || echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA
	# Check for a client wl2k line and save it if found
	if [ -f /$FNAME ]
	then
		SAVE="$(grep "^wl2k[[:space:]]" /$FNAME || [[ $? == 1 ]] 2>&1)"
		[[ $SAVE =~ wl2k ]] && echo -e "\n$SAVE" >> "$TEMPF"
	fi
	sudo cp -f "$TEMPF" "/$FNAME"
	sudo chmod ugo+r "/$FNAME"
	echo "/$FNAME configured." >$PIPEDATA

	FNAME="etc/ax25/ax25d.conf"
	sed "s|_CALL_|${F[_CALL_]}|g;s|_SSID_|${F[_SSID_]}|g" "$FNAME" > "$TEMPF"
	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
	sudo cp -f "$TEMPF" "/$FNAME"
	sudo chmod ugo+r "/$FNAME"
	echo "/$FNAME configured." >$PIPEDATA

	FNAME="etc/ax25/ax25-up.new"
	sed "s|_DWUSER_|${F[_DWUSER_]}|;s|_TNC_|${F[_TNC_]}|;s|_MODEM_|${F[_MODEM_]}|" "$FNAME" > "$TEMPF"
	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
	sudo cp -f "$TEMPF" "/$FNAME"
	sudo chmod +x "/$FNAME"
	echo "/$FNAME configured." >$PIPEDATA

	FNAME="etc/ax25/ax25-up.new2"
	sed "s|_BEACON_|${F[_BEACON_]}|" "$FNAME" > "$TEMPF"
	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
	sudo cp -f "$TEMPF" "/$FNAME"
	sudo chmod +x "/$FNAME"
	echo "/$FNAME configured." >$PIPEDATA

	FNAME="etc/ax25/direwolf.conf"
	sed "s|_CALL_|${F[_CALL_]}|g;s|_PTT_|${F[_PTT_]}|;s|_MODEM_|${F[_MODEM_]}|;s|_ARATE_|${F[_ARATE_]}|;s|_ADEVICE_CAPTURE_|${F[_ADEVICE_CAPTURE_]}|;s|_ADEVICE_PLAY_|${F[_ADEVICE_PLAY_]}|" "$FNAME" > "$TEMPF"
	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
	sudo cp -f "$TEMPF" "/$FNAME"
	sudo chmod ugo+r "/$FNAME"
	echo "/$FNAME configured." >$PIPEDATA

	echo "Setting up symlink for /etc/ax25/ax25-up if needed" >$PIPEDATA
	if ! [ -L /etc/ax25/ax25-up ]
	then # There's no symlink for /etc/ax25/ax25-up
   	[ -f /etc/ax25/ax25-up ] && sudo mv /etc/ax25/ax25-up /etc/ax25/ax25-up.previous
   	sudo ln -s /etc/ax25/ax25-up.new /etc/ax25/ax25-up
	fi
	echo "Done." >$PIPEDATA

	# Set permissions
	sudo chown -R rmsgw:rmsgw /etc/rmsgw/*
	return 0
}

function ConfigureRMSGateway () {
	CONFIGURE_TEXT="<b><big><big>RMS Gateway Configuration Parameters</big></big></b>\n \
<span color='blue'>See http://www.aprs.net/vm/DOS/PROTOCOL.HTM for power, height, gain, dir and beacon message format.</span>\n \
<b><span color='red'>CAUTION:</span></b> Do not use the tilde '<b>~</b>' character in any field below.\n"

	while true
	do
		# Retrieve saved settings or defaults if there are no saved settings
		LoadSettings
		source "$RMSGW_CONFIG_FILE"
		if ! [[ -n "${F[_REPORTS_]}" ]]
		then # Older versions of config file didn't have REPORTS. Add if necessary.
			F[_REPORTS_]='FALSE'
			echo "F[_REPORTS_]='FALSE'" >> "$RMSGW_CONFIG_FILE"
		fi
		SetFormFields
	
		> $RMSGW_TEMP_CONFIG
		# Start the Configure RMSGW tab
		CMD=(
			yad --title="Configure RMS Gateway $VERSION" --width=1000 --height=750	
  			--text="$CONFIGURE_TEXT"
  			--item-separator="~"
			--separator="~" 
  			--center
  			--buttons-layout=center
  			--columns=2
  			--text-align=center
  			--align=right
  			--borders=20
  			--form
  			--field="Call Sign" 
  			--field="SSID":NUM 
  			--field="Winlink Password":H 
  			--field="Sysop Name" 
  			--field="Grid Square" 
  			--field="Street Address1" 
  			--field="Street Address2" 
  			--field="City" 
  			--field="State" 
  			--field="ZIP" 
  			--field="Beacon message\n(Empty disables beacon)" 
  			--field="Sysop Email" 
  			--field="Frequency (Hz)" 
  			--field="Power SQR(P)":NUM 
  			--field="Antenna Height LOG2(H/10)":NUM 
  			--field="Antenna Gain (dB)":NUM 
  			--field="Direction (D/45)":NUM 
  			--field="Hours" 
  			--field="Service Code":CB 
  			--field="TNC Type":CB 
  			--field="MODEM":CB 
  			--field="Direwolf Capture ADEVICE":CB 
  			--field="Direwolf Playback ADEVICE":CB 
  			--field="Direwolf ARATE":CB 
  			--field="Direwolf PTT":CBE 
  			--field="Direwolf User" 
  			--field="Banner Text (keep it short!)" 
  			--field="Send daily activity reports to Sysop email address":CHK 
			--button="<b>Close</b>":1 \
			--button="<b>Save</b>":0 \
			--
			"${F[_CALL_]}"
			"${F[_SSID_]}~1..15~1~"
			"${F[_PASSWORD_]}"
			"${F[_SYSOP_]}"
			"${F[_GRID_]}"
			"${F[_ADDR1_]}"
			"${F[_ADDR2_]}"
			"${F[_CITY_]}"
			"${F[_STATE_]}"
			"${F[_ZIP_]}"
			"${F[_BEACON_]}"
			"${F[_EMAIL_]}"
			"${F[_FREQ_]}"
			"${F[_POWER_]}~0..9~1~"
			"${F[_HEIGHT_]}~0..9~1~"
			"${F[_GAIN_]}~0..9~1~"
			"${F[_DIR_]}~0..9~1~"
			"${F[_HOURS_]}"
			"$SERVICEs"
			"$TNCs"
			"$MODEMs"
			"$ADEVICE_CAPTUREs"
			"$ADEVICE_PLAYBACKs"
			"$ARATEs"
			"$PTTs"
			"${F[_DWUSER_]}"
			"${F[_BANNER_]}"
			"${F[_REPORTS_]}"
		)
		"${CMD[@]}" > $RMSGW_TEMP_CONFIG
		
		case $? in
			0) # Save changes and [re]start.
				[[ -s $RMSGW_TEMP_CONFIG ]] || Die "Unexpected input from configuration tab"
				if SaveSettings
				then # Configuration looks OK
					if ! systemctl list-unit-files | grep enabled | grep -q ax25
					then # No ax25 service exists. Create it.
	   				echo "Creating ax25 service..." >$PIPEDATA
				   	cat > "${TMPDIR}/ax25.service" << EOF
[Unit]
Description=AX.25 interface
After=network.target

[Service]
ExecStartPre=/bin/sleep 10
#EnvironmentFile=/etc/ax25
Type=forking
Restart=no
TimeoutSec=0
IgnoreSIGPIPE=no
KillMode=process
GuessMainPID=no
RemainAfterExit=yes
#SysVStartPriority=12
ExecStart=/etc/ax25/ax25-up
ExecStop=/etc/ax25/ax25-down

[Install]
WantedBy=default.target
EOF
	   				sudo cp -f "${TMPDIR}/ax25.service" /lib/systemd/system/ax25.service
	   				rm -f "${TMPDIR}/ax25.service"
	   				sudo systemctl enable ax25 >$PIPEDATA
	   				echo "Done." >$PIPEDATA
	   				echo -e "\n\nClick 'Start' to start the RMS Gateway" >$PIPEDATA
					fi

					# Add Auto-Check-in script to cron
					#    Generate 2 numbers between 1 and 59, M minutes apart to use for the cron job
					echo "Updating crontab for user rmsgw to run Winlink Auto Check-in" >$PIPEDATA
					M=30
					N1=$(( $RANDOM % 59 + 1 ))
					N2=$(( $N1 + $M ))
					(( $N2 > 59 )) && N2=$(( $N2 - 60 ))
					INTERVAL="$(echo "$N1 $N2" | xargs -n1 | sort -g | xargs | tr ' ' ',')"
					WHO="rmsgw"
					WHEN="$INTERVAL * * * *"
					WHAT="/usr/local/bin/rmsgw_aci >/dev/null 2>&1"
					JOB="$WHEN PATH=\$PATH:/usr/local/bin; $WHAT"
					cat <(fgrep -i -v "$WHAT" <(sudo crontab -u $WHO -l)) <(echo "$JOB") | sudo crontab -u $WHO -
					echo "Done." >$PIPEDATA
					echo -e "\nConfiguration is OK. Click '[Re]start' button below to activate." >$PIPEDATA
					break
				else # Error in configuration
					echo >$PIPEDATA
					#echo -e "\n***ERROR: Configuration is invalid. Re-check your settings." >$PIPEDATA
				fi
				;;
			*) # User cancelled. Exit.
				#echo "Configuration dialog closed." >$PIPEDATA
				break
				;;
		esac
done
}

#============================
#  FILES AND VARIABLES
#============================

# Set Temp Directory
# -----------------------------------
# Create temp directory with three random numbers and the process ID
# in the name.  This directory is removed automatically at exit.
# -----------------------------------
TMPDIR="/tmp/${SCRIPT_NAME}.$RANDOM.$RANDOM.$RANDOM.$$"
(umask 077 && mkdir "${TMPDIR}") || {
  Die "Could not create temporary directory! Exiting."
}

  #== general variables ==#
SCRIPT_NAME="$(basename ${0})" # scriptname without path
SCRIPT_DIR="$( cd $(dirname "$0") && pwd )" # script directory
SCRIPT_FULLPATH="${SCRIPT_DIR}/${SCRIPT_NAME}"
SCRIPT_ID="$(ScriptInfo | grep script_id | tr -s ' ' | cut -d' ' -f3)"
SCRIPT_HEADSIZE=$(grep -sn "^# END_OF_HEADER" ${0} | head -1 | cut -f1 -d:)
VERSION="$(ScriptInfo version | grep version | tr -s ' ' | cut -d' ' -f 4)" 

TITLE="RMS Gateway Manager $VERSION"
RMSGW_CONFIG_FILE="$HOME/rmsgw.conf"
LOGFILES="/var/log/rms.debug /var/log/ax25-listen.log /var/log/packet.log"
TEXT="<b><big><span color='blue'>RMS Gateway Manager</span></big></b>\nFollowing $LOGFILES"

PIPE=$TMPDIR/pipe
mkfifo $PIPE
exec 9<> $PIPE

export -f CheckDaemon RestartAX25Service ConfigureRMSGateway SaveSettings UpdateReporting SetFormFields LoadSettings
export PIPEDATA=$PIPE
export RMSGW_CONFIG_FILE
export RMSGW_TEMP_CONFIG=$TMPDIR/CONFIGURE_RMSGW.txt

#============================
#  PARSE OPTIONS WITH GETOPTS
#============================
  
#== set short options ==#
SCRIPT_OPTS=':hv-:'

#== set long options associated with short one ==#
typeset -A ARRAY_OPTS
ARRAY_OPTS=(
	[help]=h
	[version]=v
)

LONG_OPTS="^($(echo "${!ARRAY_OPTS[@]}" | tr ' ' '|'))="

# Parse options
while getopts ${SCRIPT_OPTS} OPTION
do
	# Translate long options to short
	if [[ "x$OPTION" == "x-" ]]
	then
		LONG_OPTION=$OPTARG
		LONG_OPTARG=$(echo $LONG_OPTION | egrep "$LONG_OPTS" | cut -d'=' -f2-)
		LONG_OPTIND=-1
		[[ "x$LONG_OPTARG" = "x" ]] && LONG_OPTIND=$OPTIND || LONG_OPTION=$(echo $OPTARG | cut -d'=' -f1)
		[[ $LONG_OPTIND -ne -1 ]] && eval LONG_OPTARG="\$$LONG_OPTIND"
		OPTION=${ARRAY_OPTS[$LONG_OPTION]}
		[[ "x$OPTION" = "x" ]] &&  OPTION="?" OPTARG="-$LONG_OPTION"
		
		if [[ $( echo "${SCRIPT_OPTS}" | grep -c "${OPTION}:" ) -eq 1 ]]
		then
			if [[ "x${LONG_OPTARG}" = "x" ]] || [[ "${LONG_OPTARG}" = -* ]]
			then 
				OPTION=":" OPTARG="-$LONG_OPTION"
			else
				OPTARG="$LONG_OPTARG";
				if [[ $LONG_OPTIND -ne -1 ]]
				then
					[[ $OPTIND -le $Optnum ]] && OPTIND=$(( $OPTIND+1 ))
					shift $OPTIND
					OPTIND=1
				fi
			fi
		fi
	fi

	# Options followed by another option instead of argument
	if [[ "x${OPTION}" != "x:" ]] && [[ "x${OPTION}" != "x?" ]] && [[ "${OPTARG}" = -* ]] 		
	then 
		OPTARG="$OPTION" OPTION=":"
	fi

	# Finally, manage options
	case "$OPTION" in
		h) 
			ScriptInfo full
			exit 0
			;;
		v) 
			ScriptInfo version
			exit 0
			;;
		:) 
			Die "${SCRIPT_NAME}: -$OPTARG: option requires an argument"
			;;
		?) 
			Die "${SCRIPT_NAME}: -$OPTARG: unknown option"
			;;
	esac
done
shift $((${OPTIND} - 1)) ## shift options

# Ensure only one instance of this script is running.
pidof -o %PPID -x $(basename "$0") >/dev/null && Die "$(basename $0) already running."

# Check for required apps.
for A in yad jq sponge pat patmail.sh
do 
	command -v $A >/dev/null 2>&1 || Die "$A is required but not installed."
done

#============================
#  MAIN SCRIPT
#============================

# Trap bad exits with cleanup function
trap SafeExit EXIT INT TERM SIGINT

# Exit on error. Append '||true' when you run the script if you expect an error.
#set -o errexit

# Check Syntax if set
$SYNTAX && set -n
# Run in debug mode, if set
$DEBUG && set -x 

PIDs=()
# Uncomment the following 2 lines to purge yad text-info periodically.
#clearTextInfo 120m &
#PIDs=( $! )

# Start the log file monitor
yad --title="$TITLE" --text-align="center" --window-icon=logviewer \
	--text="$TEXT" --back=black --fore=yellow --text-info \
	--posx=10 --posy=45 --width=1000 --height=500 \
	--tail --listen --buttons-layout=center \
	--button="<b>Close</b>":0 \
	--button="<b>Status</b>":"bash -c CheckDaemon" \
	--button="<b>Stop</b>":"bash -c 'sudo systemctl stop ax25.service 2>/dev/null'" \
	--button="<b>[Re]start</b>":"bash -c RestartAX25Service" \
	--button="<b>Configure</b>":"bash -c ConfigureRMSGateway" <&9 &
monitor_PID=$!
PIDs+=( $monitor_PID )
tail -F --pid=$monitor_PID -q -n 30 $LOGFILES 2>/dev/null | cat -v >&9
SafeExit
