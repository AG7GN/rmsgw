#! /bin/bash

# Script to tail RMS Gateway log files and provide easy way
# to start and stop ax25.service. 

VERSION="1.0.7"

#LOGFILES=${1:-/var/log/syslog}
LOGFILES="/var/log/ax25-listen.log /var/log/packet.log /var/log/rms.debug"
PIPE=$(mktemp -u --tmpdir ${0##*/}.XXXXXXXX)
mkfifo $PIPE
exec 3<> $PIPE

function OnExit () {
	rm -f $PIPE
	unset CheckDaemon
}

function CheckDaemon () {
	local TITLE="Check RMS Gateway Daemon"
	if systemctl list-unit-files | grep -q "ax25.*enabled"
	then # ax25.service installed and enabled
	   STATUS="Enabled"
	   if systemctl | grep -q "ax25.*running"
	   then
		      STATUS+=" and Running"
				BUTTON_TEXT="Stop"
				COLOR="green"
		else
	         STATUS+=" but Not Running"
				BUTTON_TEXT="Start"
				COLOR="red"
	   fi
   	yad --center --title="$TITLE" \
				--text "<b><big><big>RMS Gateway Status: <span color='$COLOR'>$STATUS</span>\n</big></big></b>" \
     			--borders=20 \
     			--buttons-layout=center \
     			--text-align=center \
     			--align=right \
     			--button="<b>Close</b>":0 --button="<b>$BUTTON_TEXT RMS Gateway</b>":10
		local ANSWER=$?
		case $ANSWER in
	   	10) 
				sudo systemctl ${BUTTON_TEXT,,} ax25.service
				;;
			*)
				;;
		esac			
	else # ax25.service not installed/enabled
		STATUS="<b><big><span color='red'>RMS Gateway is NOT enabled.</span></big>\n\n<i>Operating an RMS Gateway requires that you obtain a 'Sysop' account at winlink.org!</i></b>\n\nThere are other requirements as well.\n\nIf you operate the Pi as an RMS Gateway, I strongly recommend that you don't use the Pi for any other purpose.\n\n If you still want to operate an RMS Gateway, run 'Configure RMS Gateway' in the Hamradio menu to enable and configure it.\n" 
	   echo "$STATUS" | yad --center --title="$TITLE" --skip-taskbar --borders=20 \
			--form --align center --field="$STATUS":RO "*** IMPORTANT ***" \
			--width=300 --height=200 --selectable-labels \
			--buttons-layout=center \
			--button=Close:0 >/dev/null
	fi
}
export -f CheckDaemon

trap OnExit EXIT

yad --text-info --editbale --margins=5 --show-uri --back=black --fore=yellow --width=800 --height=400 \
	--title="Log Viewer $VERSION - Following $LOGFILES" --window-icon=logviewer \
	--tail --center --button="<b>Quit</b>":0 --button="<b>Start/Stop RMS Gateway</b>":"bash -c CheckDaemon" \
	--buttons-layout=center <&3 &
YPID=$!
tail -F --pid=$YPID -q -n 30 $LOGFILES 2>/dev/null | cat -v >&3



