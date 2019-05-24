#! /bin/bash

# VERSION=0.0.1
UPDATE_MENU_URL="https://www.ietf.org/rfc/rfc3339.txt"   # <------------ TODO
SCRIPT_PATH=$HOME/scripts/raspi-menu.sh
OPENBOX_AUTOSTART=/etc/xdg/openbox/autostart
BASH_PROFILE=$HOME/.bash_profile
BASH_RC=$HOME/.bashrc

clear

calc_windows_size() {
  LINES=17
  COLUMNS=$(tput cols)

  if [ -z "$COLUMNS" ] || [ "$COLUMNS" -lt 60 ]; then
    COLUMNS=80
  fi
  if [ "$COLUMNS" -gt 178 ]; then
    COLUMNS=120
  fi
  MENU_LINES=$((LINES-7))
}

calc_windows_size

# Check if the user is a root user
if [ "$(whoami)" != "root" ]; then
        whiptail --msgbox "Sorry you are not root. You must type: 'sudo $USER' \nand restart this script." "$LINES" "$COLUMNS"
        exit
fi

#TODO
#do_change_timezone
#TODO
#do_configure_keyboard

goToMainMenu() {
	SEL="<--- "
}

drawMenu() {
	local SUB_TITLE=$GLOBAL_SUB_TITLE
	local TITLE=$1
	shift
	local MENU_ITEM=("$@")
	SEL=$(
		whiptail --title "$TITLE" --menu "$SUB_TITLE" "$LINES" "$W_T_WIDTH" "$MENU_LINES" --cancel-button Finish --ok-button Select --clear "${MENU_ITEM[@]}" 3>&2 2>&1 1>&3
	)
	GLOBAL_SUB_TITLE=""
}

networkMenu() {
	NET_TIT='Set Network configuration'
  declare -a NET_ARR=(
		'<--- ' 'Back to Main Menu'
		'1.1' 'Add/Modify a '$USER' hostname'
		'1.2' 'Set wi-fi interface with a tool' 
		'1.3' 'Set manually wi-fi/ethernet interface'
	);
	drawMenu "$NET_TIT" "${NET_ARR[@]}"
}

setAutomaticWifi() {
  if [ $(which wicd-curses) ];
  then
    whiptail --msgbox "After click on OK button, you can choose the Wifi from a list. \n
    With the keyboard key '->' you will be able to set the parameters of the wifi interface. \n
    With the keyboard key 'Q' you will be able to quit.
    " "$LINES" "$COLUMNS"
    wicd-curses
  else
    whiptail --msgbox "Tool for set wifi automatically not-found (wicd-curses)." "$LINES" "$COLUMNS"
  fi
  goToMainMenu
}

setHostname() {
	whiptail --msgbox "\
	Please note: \n
	hostname's labels	may contain only the ASCII letters 'a' through 'z' (case-insensitive), \
	the digits '0' through '9', and the hypen '-'.\
	Hostname labels cannot begin or end with a hypen '-'. \
	No other symbols, punctuation characters, or blank spaces are permitted.\
	" 20 70 1
  CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
  NEW_HOSTNAME=$(whiptail --inputbox "Please enter a hostname" 20 60 "$CURRENT_HOSTNAME" 3>&1 1>&2 2>&3)

  if [ $? -eq 0 ]; then
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
  fi
  if [ $? -eq 0 ]; then
    whiptail --msgbox "Hostname changed succesfull." 20 70 1
  else
    whiptail --msgbox "Something went wrong. Try again." 20 70 1
  fi
  goToMainMenu
}

writeIP(){
	local IP_ADDR=$(whiptail --inputbox "Insert a rasberry IP address like XXX.XXX.XXX.XXX" 8 78 Blue --title "Insert static IP" 3>&1 1>&2 2>&3)
	local IP_ROUTER=$(whiptail --inputbox "Insert RouterIP address like XXX.XXX.XXX.XXX" 8 78 Blue --title "Insert router IP" 3>&1 1>&2 2>&3)
	local IP_DNS=$(whiptail --inputbox "Insert the IP address for DNS, if are multiple DNS you can divide it by a space \" \"" 8 78 Blue --title "Insert DNS IP" 3>&1 1>&2 2>&3)
	echo "interface $INTERFACE" >> /etc/dhcpcd.conf
	echo "static ip_address=$IP_ADDR" >> /etc/dhcpcd.conf
	echo "static routers=$IP_ROUTER" >> /etc/dhcpcd.conf
	echo "static domain_name_servers=$IP_DNS" >> /etc/dhcpcd.conf
}

setIPNetwork() {
	# Scan interfaces
	local counter=0
	local LIST_INTERF=$(ls /sys/class/net)
	while IFS=' ' read -ra CUTTED_INTERF ; do
		for i in "${CUTTED_INTERF[@]}"; do
 		local INTERF_MENU_LIST=("${INTERF_MENU_LIST[@]}" "$i" "     Interfaccia $counter   " )
		done
		counter=$((counter+1))
	done <<< "$LIST_INTERF"

	#INTERFACE=$(whiptail --radiolist "Select an Interface" --title "Select an Interface" $LINES $COLUMNS $counter "${INTERF_MENU_LIST[@]}")
	SET_NET_TIT="Set Network"
	GLOBAL_SUB_TITLE="Select one interface to configure it:"
	drawMenu "$SET_NET_TIT" "${INTERF_MENU_LIST[@]}"

	INTERFACE=$SEL

	# Search the world but exclude the line that starts with '#'
	$(grep $INTERFACE /etc/dhcpcd.conf | grep -v "#")
	if [ $? = 0 ];
	then
		whiptail --yesno "Attention! The interface is already set.\nClear and reinsert it?" --title "" 10 60 2
		if [ $? = 0 ];
		then
			writeIP
		else
			goToMainMenu
		fi
	else
		writeIP
	fi
	goToMainMenu
}

setCrontab() {
	echo ""
}

changeSiteURL() {
  if [ -e $OPENBOX_AUTOSTART && -e $BASH_RC && -e $BASH_PROFILE ]];
  then
		whiptail --title "Activate URL Browser" --msgbox "With this option you'are activating a kiosk mode and now you must choose a URL" 8 78
		grep -q 'SITE=' $OPENBOX_AUTOSTART
		if [ $? = 0 ];
		then
			OLD_SITE="cut -d "=" -f 2 <<< $(grep "SITE=" $OPENBOX_AUTOSTART)"
			
			# ACTIVATE
			# remove the last line of bashrc to start this config-menu file
			# remove the last line of bash_profile and add to start startx
			sed -i '$d' $BASH_PROFILE
			sed -i '$d' $BASH_RC
			echo "[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && startx -- -nocursor" > $BASH_PROFILE

			# SET URL
			# remove the last chromium's URL and add the correct one
			CURRENT_URL="https://www.smeup.com"
			SITE=$(whiptail --inputbox "Please enter a valid URL" 20 60 "$CURRENT_URL" 3>&1 1>&2 2>&3)
			sed 's/^\(\s*SITE\s*=\s*\).*/\1'$SITE'/' $OPENBOX_AUTOSTART
			NEW_SITE=$SITE
		else
			CURRENT_URL="https://www.smeup.com"
			SITE=$(whiptail --inputbox "Please enter a valid URL" 20 60 "$CURRENT_URL" 3>&1 1>&2 2>&3)
			echo "sed -i 's/\"exited_cleanly\":false/\"exited_cleanly\":true/' $HOME/.config/chromium/'Local State'" >> $OPENBOX_AUTOSTART
			echo "sed -i 's/\"exited_cleanly\":false/\"exited_cleanly\":true/; s/\"exit_type\":\"[^\"]\+\"/\"exit_type\":\"Normal\"/' $HOME/.config/chromium/Default/Preferences" >> $OPENBOX_AUTOSTART
			echo "SITE=$SITE"
			echo "chromium-browser --disable-translate --incognito --disable-infobars --disable-restore-session-state --disable- session-crashed-bubble --kiosk \$SITE &" >> $OPENBOX_AUTOSTART
			NEW_SITE=$SITE
		fi
		if [ $NEW_SITE != $OLD_SITE ];
		then
			whiptail --title "Activate URL Browser" --msgbox "URL Browser changed correctly and succesfull activated KIOSK MODE." 8 78
		else
			whiptail --title "Error!" --msgbox "New site insered not saved correctly." 8 78
		fi
	else
			whiptail --title "Error!" --msgbox "File $OPENBOX_AUTOSTART not found or not accessible." 8 78
	fi
	goToMainMenu
}

updateSystem() {
  {
		# APT-Update
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(apt-get update)
  } | whiptail --title "Progress" --gauge "Please wait while system search updating" 6 60 0

  {
		# APT-Upgrade
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(apt -y upgrade)
  } | whiptail --title "Progress" --gauge "Please wait while system install update" 6 60 0

	{
		# RPI-Update
    i=1
    while read -r line; do
        i=$(( i + 1 ))
        echo $i
    done < <(rpi-update)
  } | whiptail --title "Progress" --gauge "Please wait while updating your RPI firmware and kernel" 6 60 0

  goToMainMenu
} 

updateMenuVersion() {
 cd $SCRIPT_PATH
 wget -q $UPDATE_MENU_URL -O $SCRIPT_PATH | whiptail --title "Progress" --gauge "Please wait while download update script..." 6 60 0
 if [ $? = 0 ];
 then
	whiptail --msgbox "Procedure for updating menu terminated sucessfully." 20 60 1
 else
 	whiptail --msgbox "Error in procedure for updating menu." 20 60 1
 fi
 goToMainMenu
}

info() {
  local MESSAGE="\
  Menu version: $VERSION\n\
  Writed by: SmeUP \
  "
  whiptail --title "INFO" --msgbox "$MESSAGE" 10 30 1
  goToMainMenu
}

checkHowExit() {
	whiptail --yesno "For take changes raspberry must will reboot. Would you like to reboot now?" 20 60 2
	if [ $? = 1 ];
	then
		sync
		exit 0
	else
		sync
		reboot
		exit 0
	fi
}

checkIfKioskMode() {
	if [ -z "${NEW_SITE// }" ] || ( [ $NEW_SITE = $OLD_SITE ] && [ ! -z "${NEW_SITE// }" ] );
		then
			whiptail --yesno "For use raspberry in kios-mode you MUST change the default URL in menu\n\nDo you want to leave without abilitate a Kiosk mode?" 20 60
			if [ $? = 1 ];
			then
				goToMainMenu
			fi
		else
			checkHowExit
		fi
}


GLOBAL_SUB_TITLE=""
goToMainMenu

while [ 1 ]
do
	case $SEL in
		1 ) networkMenu
		;;
		2 ) setCrontab
		;;
		3 ) changeSiteURL
		;;
		4 ) updateSystem
		;;
		5 ) updateMenuVersion
		;;
    6 ) info 
		;;
		"1.1" ) setHostname
		;;
    "1.2" ) setAutomaticWifi
    ;;
		"1.3" ) setIPNetwork
		;;
		"<--- " )

			MAIN_TIT='SmeUP Raspberry Menu'
			declare -a MAIN_ARR=(
				'1' 'Configure Network' 
				'2' 'Configure scheduler' 
				'3' 'Configure default URL for Chrome-kiosk' 
				'4' 'Update system'
				'5' 'Update this menu'
        '6' 'Info'  
				'0  ' 'Exit'
			);
			drawMenu "$MAIN_TIT" "${MAIN_ARR[@]}"
		;;
		"0  " ) 
			whiptail --msgbox "If you configurated correctly the raspi this will change it in KIOSK MODE.\nNote: This means that this configuration-tool will be hide, but you will can find it at $SCRIPT_PATH" 20 60 2
			checkIfKioskMode
			checkHowExit
		;;
	esac
done
exit



################################ Update notification 1.7

#CURRENTVERSION=$(grep -m1 "# VERSION=" $SCRIPT_PATH)
#GITHUBVERSION=$(curl -s $REPO/version)
#SCRIPTS="/var/scripts"

#if [ $(dpkg-query -W -f='${Status}' curl 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
#      echo "Curl is already installed..."
#      clear
#else
#    apt-get install curl -y
#fi

#if [ "$CURRENTVERSION" == "$GITHUBVERSION" ]; then
#          echo "Tool is up to date..."
#else

#  whiptail --yesno "A new version of this tool is available, download it now?" --title "Update Notification!" 10 60 2
#  if [ $? -eq 0 ]; then # yes

#  if [ -f "$SCRIPTS"/techandtool.sh ]; then
#          rm "$SCRIPTS"/techandtool.sh
#  fi

#  if [ -f /usr/sbin/techandtool ]; then
#          rm /usr/sbin/techandtool
#  fi
#          mkdir -p "$SCRIPTS"
#          wget -q $REPO/techandtool.sh -P "$SCRIPTS"
#          cp "$SCRIPTS"/techandtool.sh /usr/sbin/techandtool
#          chmod +x /usr/sbin/techandtool

#          if [ -f "$SCRIPTS"/techandtool.sh ]; then
#                  rm "$SCRIPTS"/techandtool.sh
#          fi

#          exec techandtool
#    fi
#fi





#dpkg-reconfigure keyboard-configuration &&
  #printf "Reloading keymap. This may take a short while\n" &&
  #invoke-rc.d keyboard-setup start
  #dpkg-reconfigure locales
  #dpkg-reconfigure tzdata