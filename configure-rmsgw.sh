#!/bin/bash

# This script gathers configuration data from the user to set up n RMS Gateway on a Raspberry Pi.
# The data it gathers is used to configure the following files:
# /etc/ax25/ax25-up.new
# /etc/ax25/ax25-up.new2
# /etc/ax25/direwolf.conf
# /etc/ax25/axports
# /etc/rmsgw/banner
# /etc/rmsgw/channels.xml
# /etc/rmsgw/gateway.conf
# /etc/rmsgw/sysop.xml
# 

VERSION="1.0.30"

CONFIG_FILE="$HOME/rmsgw.conf"

trap errorReport INT ERR

function errorReport () {
   echo
   [[ $1 == "" ]] && exit 0 || echo >&2 "$1"
   echo
   read -n 1 -s -r -p "Press any key to exit script"
   echo
   echo 
   [[ $2 == "" ]] && exit 1 || exit $2
}

if [ -s "$CONFIG_FILE" ]
then # There is a config file
   echo "$CONFIG_FILE found."
	source "$CONFIG_FILE"
else # Set some default values in a new config file
   echo "Config file $CONFIG_FILE not found.  Creating a new one with default values."
	echo "declare -A F" > "$CONFIG_FILE"
	echo "F[_CALL_]='N0ONE'" >> "$CONFIG_FILE"
   echo "F[_SSID_]='10'" >> "$CONFIG_FILE"
   echo "F[_PASSWORD_]='password'" >> "$CONFIG_FILE"
   echo "F[_SYSOP_]='John Smith'" >> "$CONFIG_FILE"
   echo "F[_GRID_]='CN88ss'" >> "$CONFIG_FILE"
   echo "F[_ADDR1_]='123 Main Street'" >> "$CONFIG_FILE"
   echo "F[_ADDR2_]=''" >> "$CONFIG_FILE"
   echo "F[_CITY_]='Anytown'" >> "$CONFIG_FILE"
   echo "F[_STATE_]='WA'" >> "$CONFIG_FILE"
   echo "F[_ZIP_]='98225'" >> "$CONFIG_FILE"
   echo "F[_BEACON_]='!4850.00N/12232.27W\$144.920MHzMy RMS Gateway'" >> "$CONFIG_FILE"
   echo "F[_EMAIL_]='n0one@example.com'" >> "$CONFIG_FILE"
   echo "F[_FREQ_]='144920000'" >> "$CONFIG_FILE"
   echo "F[_POWER_]='3'" >> "$CONFIG_FILE"
   echo "F[_HEIGHT_]='2'" >> "$CONFIG_FILE"
   echo "F[_GAIN_]='7'" >> "$CONFIG_FILE"
   echo "F[_DIR_]='0'" >> "$CONFIG_FILE"
   echo "F[_HOURS_]='24/7'" >> "$CONFIG_FILE"
   echo "F[_SERVICE_]='PUBLIC'" >> "$CONFIG_FILE"
   echo "F[_TNC_]='direwolf'" >> "$CONFIG_FILE"
   echo "F[_MODEM_]='1200'" >> "$CONFIG_FILE"
   echo "F[_ADEVICE_CAPTURE_]='null'" >> "$CONFIG_FILE"
   echo "F[_ADEVICE_PLAY_]='null'" >> "$CONFIG_FILE"
   echo "F[_ARATE_]='96000'" >> "$CONFIG_FILE"
   echo "F[_PTT_]='GPIO 23'" >> "$CONFIG_FILE"
   echo "F[_DWUSER_]='$(whoami)'" >> "$CONFIG_FILE"
   echo "F[_BANNER_]='*** My Banner ***'" >> "$CONFIG_FILE"
	source "$CONFIG_FILE"
fi

echo "Loading configuration GUI."

TNCs="tncpi!direwolf"
[[ $TNCs =~ ${F[_TNC_]} ]] && TNCs="$(echo "$TNCs" | sed "s/${F[_TNC_]}/\^${F[_TNC_]}/")" 

MODEMs="1200!9600"
[[ $MODEMs =~ ${F[_MODEM_]} ]] && MODEMs="$(echo "$MODEMs" | sed "s/${F[_MODEM_]}/\^${F[_MODEM_]}/")" 

SERVICEs="PUBLIC!EMCOMM"
[[ $SERVICEs =~ ${F[_SERVICE_]} ]] && SERVICEs="$(echo "$SERVICEs" | sed "s/${F[_SERVICE_]}/\^${F[_SERVICE_]}/")" 

if pgrep pulseaudio >/dev/null 2>&1
then # There may be pulseaudio ALSA devices.  Look for them.
	CAPTURE_IGNORE="$(pacmd list-sinks 2>/dev/null | grep name: | tr -d '\t' | cut -d' ' -f2 | sed 's/^<//;s/>$//' | tr '\n' '\|' | sed 's/|/\\|/g')"
	ADEVICE_CAPTUREs="$(arecord -L | grep -v "$CAPTURE_IGNORE^ .*\|^dsnoop\|^sys\|^default\|^dmix\|^hw\|^usbstream\|^jack\|^pulse" | tr '\n' '!' | sed 's/!$//')"
	PLAYBACK_IGNORE="$(pacmd list-sources 2>/dev/null | grep name: | tr -d '\t' | cut -d' ' -f2 | sed 's/^<//;s/>$//' | tr '\n' '\|' | sed 's/|/\\|/g')"
	ADEVICE_PLAYBACKs="$(aplay -L | grep -v "$PLAYBACK_IGNORE^ .*\|^dsnoop\|^sys\|^default\|^dmix\|^hw\|^usbstream\|^jack\|^pulse" | tr '\n' '!' | sed 's/!$//')"
else  # pulseaudio isn't running.  Check only for null and plughw devices
   ADEVICE_CAPTUREs="$(arecord -L | grep "^null\|^plughw" | tr '\n' '!' | sed 's/!$//')"
   ADEVICE_PLAYBACKs="$(aplay -L | grep "^null\|^plughw" | tr '\n' '!' | sed 's/!$//')"
fi
[[ $ADEVICE_CAPTUREs =~ ${F[_ADEVICE_CAPTURE_]} ]] && ADEVICE_CAPTUREs="$(echo "$ADEVICE_CAPTUREs" | sed "s/${F[_ADEVICE_CAPTURE_]}/\^${F[_ADEVICE_CAPTURE_]}/")"
[[ $ADEVICE_CAPTUREs == "" ]] && ADEVICE_CAPTUREs="null"
[[ $ADEVICE_PLAYBACKs =~ ${F[_ADEVICE_PLAY_]} ]] && ADEVICE_PLAYBACKs="$(echo "$ADEVICE_PLAYBACKs" | sed "s/${F[_ADEVICE_PLAY_]}/\^${F[_ADEVICE_PLAY_]}/")"
[[ $ADEVICE_PLAYBACKs == "" ]] && ADEVICE_PLAYBACKs="null"

ARATEs="48000!96000"
[[ $ARATEs =~ ${F[_ARATE_]} ]] && ARATEs="$(echo "$ARATEs" | sed "s/${F[_ARATE_]}/\^${F[_ARATE_]}/")" 

PTTs="GPIO 12!GPIO 23"
if [[ $PTTs =~ ${F[_PTT_]} ]]
then
	PTTs="$(echo "$PTTs" | sed "s/${F[_PTT_]}/\^${F[_PTT_]}/")" 
else
	PTTs+="!^${F[_PTT_]}"
fi

ANS=""
ANS="$(yad --title="Configure RMS Gateway version $VERSION" \
  --text="<b><big><big>RMS Gateway Configuration Parameters</big></big></b>\n \
See http://www.aprs.net/vm/DOS/PROTOCOL.HTM for power, height, gain, dir and beacon message format.\n \
<b>CAUTION:</b> Do not use the vertical bar '|' character in any field below.\n" \
  --item-separator="!" \
  --center \
  --buttons-layout=center \
  --columns=2 \
  --text-align=center \
  --align=right \
  --borders=20 \
  --form \
  --field="Call Sign" "${F[_CALL_]}" \
  --field="SSID":NUM "${F[_SSID_]}!1..15!1!" \
  --field="Winlink Password" "${F[_PASSWORD_]}" \
  --field="Sysop Name" "${F[_SYSOP_]}" \
  --field="Grid Square" "${F[_GRID_]}" \
  --field="Street Address1" "${F[_ADDR1_]}" \
  --field="Street Address2" "${F[_ADDR2_]}" \
  --field="City" "${F[_CITY_]}" \
  --field="State" "${F[_STATE_]}" \
  --field="ZIP" "${F[_ZIP_]}" \
  --field="Beacon message" "${F[_BEACON_]}" \
  --field="Email" "${F[_EMAIL_]}" \
  --field="Frequency (Hz)" "${F[_FREQ_]}" \
  --field="Power SQR(P)":NUM "${F[_POWER_]}!0..9!1!" \
  --field="Antenna Height LOG2(H/10)":NUM "${F[_HEIGHT_]}!0..9!1!" \
  --field="Antenna Gain (dB)":NUM "${F[_GAIN_]}!0..9!1!" \
  --field="Direction (D/45)":NUM "${F[_DIR_]}!0..9!1!" \
  --field="Hours" "${F[_HOURS_]}" \
  --field="Service Code":CB "$SERVICEs" \
  --field="TNC Type":CB "$TNCs" \
  --field="MODEM":CB "$MODEMs" \
  --field="Direwolf Capture ADEVICE":CB "$ADEVICE_CAPTUREs" \
  --field="Direwolf Playback ADEVICE":CB "$ADEVICE_PLAYBACKs" \
  --field="Direwolf ARATE":CB "$ARATEs" \
  --field="Direwolf PTT":CBE "$PTTs" \
  --field="Direwolf User" "${F[_DWUSER_]}" \
  --field="Banner Text (keep it short!)" "${F[_BANNER_]}" \
  --focus-field 1 \
   )"

[[ $? == 1 || $? == 252 ]] && errorReport  # User has cancelled.

[[ $ANS == "" ]] && errorReport "Error." 1

IFS='|' read -r -a TF <<< "$ANS"

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

echo "declare -A F" > "$CONFIG_FILE"
for I in "${!F[@]}"
do
	echo "F[$I]='${F[$I]}'" >> "$CONFIG_FILE"
done

TEMPF="$(mktemp)"

cd /usr/local/share/hampi/rmsgw/

FNAME="etc/rmsgw/channels.xml"
sed "s|_CALL_|${F[_CALL_]}|g;s|_SSID_|${F[_SSID_]}|;s|_PASSWORD_|${F[_PASSWORD_]}|;s|_GRID_|${F[_GRID_]}|;s|_FREQ_|${F[_FREQ_]}|;s|_MODEM_|${F[_MODEM_]}|;s|_POWER_|${F[_POWER_]}|;s|_HEIGHT_|${F[_HEIGHT_]}|;s|_GAIN_|${F[_GAIN_]}|;s|_DIR_|${F[_DIR_]}|;s|_HOURS_|${F[_HOURS_]}|;s|_SERVICE_|${F[_SERVICE_]}|" "$FNAME" > "$TEMPF" 
[[ $? == 0 ]] || errorReport "ERROR updating $FNAME" 1
sudo cp -f "$TEMPF" "/$FNAME"

FNAME="etc/rmsgw/banner"
echo "${F[_BANNER_]}" > "$TEMPF"
sudo cp -f "$TEMPF" "/$FNAME"

FNAME="etc/rmsgw/gateway.conf"
sed "s|_CALL_|${F[_CALL_]}|g;s|_SSID_|${F[_SSID_]}|;s|_GRID_|${F[_GRID_]}|" "$FNAME" > "$TEMPF"
[[ $? == 0 ]] || errorReport "ERROR updating $FNAME" 1
sudo cp -f "$TEMPF" "/$FNAME"

FNAME="etc/rmsgw/sysop.xml"
sed "s|_CALL_|${F[_CALL_]}|g;s|_PASSWORD_|${F[_PASSWORD_]}|;s|_GRID_|${F[_GRID_]}|;s|_SYSOP_|${F[_SYSOP_]}|;s|_ADDR1_|${F[_ADDR1_]}|;s|_ADDR2_|${F[_ADDR2_]}|;s|_CITY_|${F[_CITY_]}|;s|_STATE_|${F[_STATE_]}|;s|_ZIP_|${F[_ZIP_]}|;s|_EMAIL_|${F[_EMAIL_]}|" "$FNAME" > "$TEMPF"
[[ $? == 0 ]] || errorReport "ERROR updating $FNAME" 1
sudo cp -f "$TEMPF" "/$FNAME"

FNAME="etc/ax25/axports"
sed -i '/^[[:space:]]*$/d' $FNAME
sed "s|_CALL_|${F[_CALL_]}|g;s|_SSID_|${F[_SSID_]}|g;s|_FREQ_|${F[_FREQ_]}|g;s|_MODEM_|${F[_MODEM_]}|g" "$FNAME" > "$TEMPF"
[[ $? == 0 ]] || errorReport "ERROR updating $FNAME" 1
# Check for a client wl2k line and save it if found
if [ -f /$FNAME ]
then
	SAVE="$(grep "^wl2k[[:space:]]" /$FNAME || [[ $? == 1 ]] 2>&1)"
	[[ $SAVE =~ wl2k ]] && echo -e "\n$SAVE" >> "$TEMPF"
fi
sudo cp -f "$TEMPF" "/$FNAME"
sudo chmod ugo+r "/$FNAME"

FNAME="etc/ax25/ax25d.conf"
sed "s|_CALL_|${F[_CALL_]}|g;s|_SSID_|${F[_SSID_]}|g" "$FNAME" > "$TEMPF"
[[ $? == 0 ]] || errorReport "ERROR updating $FNAME" 1
sudo cp -f "$TEMPF" "/$FNAME"
sudo chmod ugo+r "/$FNAME"

FNAME="etc/ax25/ax25-up.new"
sed "s|_DWUSER_|${F[_DWUSER_]}|;s|_TNC_|${F[_TNC_]}|;s|_MODEM_|${F[_MODEM_]}|" "$FNAME" > "$TEMPF"
[[ $? == 0 ]] || errorReport "ERROR updating $FNAME" 1
sudo cp -f "$TEMPF" "/$FNAME"
sudo chmod +x "/$FNAME"

FNAME="etc/ax25/ax25-up.new2"
sed "s|_BEACON_|${F[_BEACON_]}|" "$FNAME" > "$TEMPF"
[[ $? == 0 ]] || errorReport "ERROR updating $FNAME" 1
sudo cp -f "$TEMPF" "/$FNAME"
sudo chmod +x "/$FNAME"

FNAME="etc/ax25/direwolf.conf"
sed "s|_CALL_|${F[_CALL_]}|g;s|_PTT_|${F[_PTT_]}|;s|_MODEM_|${F[_MODEM_]}|;s|_ARATE_|${F[_ARATE_]}|;s|_ADEVICE_CAPTURE_|${F[_ADEVICE_CAPTURE_]}|;s|_ADEVICE_PLAY_|${F[_ADEVICE_PLAY_]}|" "$FNAME" > "$TEMPF"
[[ $? == 0 ]] || errorReport "ERROR updating $FNAME" 1
sudo cp -f "$TEMPF" "/$FNAME"
sudo chmod ugo+r "/$FNAME"

echo "Setting up symlink for /etc/ax25/ax25-up if needed"
if ! [ -L /etc/ax25/ax25-up ]
then # There's no symlink for /etc/ax25/ax25-up
   [ -f /etc/ax25/ax25-up ] && sudo mv /etc/ax25/ax25-up /etc/ax25/ax25-up.previous
   sudo ln -s /etc/ax25/ax25-up.new /etc/ax25/ax25-up
fi
echo "Done."

# Set up ax25.service if necessary and (re)start it.

if systemctl list-unit-files | grep enabled | grep -q ax25
then # ax25 service is enabled.
   echo "Restarting ax25 service"
   if systemctl | grep running | grep -q ax25.service
   then # ax25 is running.  Restart it.
   	sudo systemctl restart ax25 || errorReport "ERROR: ax25 failed to restart" 1 }
   else # ax25 is stopped. Start it.
   	sudo systemctl start ax25 || errorReport "ERROR: ax25 failed to start" 1
   fi  
   echo "Done."
else # ax25 service is not enabled.  Create it.
   cat > "$TEMPF" << EOF
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
   sudo cp -f "$TEMPF" /lib/systemd/system/ax25.service
   echo "Creating ax25 service"
   sudo systemctl enable ax25 || errorReport "ERROR enabling ax25" 1
   echo "Done."
   echo "Starting ax25 service"
   sudo systemctl start ax25 || errorReport "ERROR: ax25 failed to start" 1
   echo "Done."
fi

echo "Installing crontab for user rmsgw"
WHO="rmsgw"
WHEN="17,47 * * * *"
WHAT="/usr/local/bin/rmsgw_aci >/dev/null 2>&1"
JOB="$WHEN $WHAT"
cat <(fgrep -i -v "$WHAT" <(sudo crontab -u $WHO -l)) <(echo "$JOB") | sudo crontab -u $WHO -
echo "Done."

rm "$TEMPF"

zenity --title="Configure RMS Gateway" --question --no-wrap --ellipsize --text="RMS Gateway is operational.\n\nYou should reboot now to make sure that the ax25 service (and direwolf, if selected) starts automatically.\n" --ok-label="Reboot Now" --cancel-label="Cancel"
[[ $? == 0 ]] && sudo shutdown -r +0 || exit 0








