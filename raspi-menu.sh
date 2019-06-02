#! /bin/bash

VERSION=0.0.1
USER=
HOME=/home/"$USER"
URL_FILE_MENU=
URL_UPDATE_VERSION_MENU=
SCRIPT_PATH="$HOME"/scripts/raspi-menu.sh
OPENBOX_AUTOSTART=/etc/xdg/openbox/autostart
BASH_PROFILE="$HOME"/.bash_profile
BASH_RC="$HOME"/.bashrc
BACKUP_DIR="$HOME"/.backup
FILE_VARIATION_PKG=

clear

checkIfDoBackup() {
	if [ ! -d "$BACKUP_DIR" ];
	then
	 createBackupFile
	fi
}

createBackupFile() {
	sudo mkdir -p "$BACKUP_DIR"
	cp "$SCRIPT_PATH" "$BACKUP_DIR"
	sudo cp "$OPENBOX_AUTOSTART" "$BACKUP_DIR"
	sudo cp "$BASH_PROFILE" "$BACKUP_DIR"
	sudo cp "$BASH_RC" "$BACKUP_DIR"
	sudo cp "/etc/network/interfaces" "$BACKUP_DIR"
	mkdir "$BACKUP_DIR"/interfaces.d
	sudo cp "/etc/network/interfaces.d/interfaces" "$BACKUP_DIR"/interfaces.d
	sudo cp "/etc/wpa_supplicant/wpa_supplicant.conf" "$BACKUP_DIR"
	sudo cp "/etc/dhcpcd.conf" "$BACKUP_DIR"
	sudo cp "/etc/hostname" "$BACKUP_DIR"
	sudo cp "$HOME/scripts/$FILE_VARIATION_PKG" "$BACKUP_DIR"
	sudo rm "$HOME/scripts/$FILE_VARIATION_PKG"
}

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
		'1.4' 'Test connection'
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
    sudo sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
  fi
  if [ $? -eq 0 ]; then
    whiptail --msgbox "Hostname changed succesfull." 20 70 1
  else
    whiptail --msgbox "Something went wrong. Try again." 20 70 1
  fi
  goToMainMenu
}

writeStaticIP(){
	local IP_ADDR=$(whiptail --inputbox "Insert a CIDR IP address with a SUBNETMASK like 192.168.168.207/16" 8 78 --title "Insert static IP" 3>&1 1>&2 2>&3)
	local IP_ROUTER=$(whiptail --inputbox "Insert RouterIP address" 8 78 --title "Insert router IP" 3>&1 1>&2 2>&3)
	local IP_DNS=$(whiptail --inputbox "Insert the IP address for DNS, if are multiple DNS you can divide it by a space \" \"" 8 78 --title "Insert DNS IP" 3>&1 1>&2 2>&3)
	echo "interface $INTERFACE" >> /etc/dhcpcd.conf
	echo "static ip_address=$IP_ADDR" >> /etc/dhcpcd.conf
	echo "static routers=$IP_ROUTER" >> /etc/dhcpcd.conf
	echo "static domain_name_servers=$IP_DNS" >> /etc/dhcpcd.conf
}

# TODO - Vedere che non esista già
addAutoInterface() {
	echo "" >> $INTERFACE_FILE
	echo "auto $INTERFACE" >> $INTERFACE_FILE
}

addWpaSupplicant() {
	echo "#wpa_supplicant_$INTERFACE" >> $INTERFACE_FILE
	echo "wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf" >> $INTERFACE_FILE
}

# TODO - Fare controllo prima di scrittura se esiste già
writeWpaSupplicant() { # (ssid,passw)
	WPASUPPLICANT_FILE=/etc/wpa_supplicant/wpa_supplicant.conf
	echo 'network={' >> $WPASUPPLICANT_FILE
	echo "    ssid=\"$1\"" >> $WPASUPPLICANT_FILE
	echo "    psk=\"$2\"" >> $WPASUPPLICANT_FILE
	echo '}' >> $WPASUPPLICANT_FILE
}

writeDHCPStatusInterface() { # (type_interface)
	echo "iface $INTERFACE inet $1" >> $INTERFACE_FILE
}

writeConfigInterface() { # (type,ssid,passw)
	TYPE_INTERFACE=$1

	# Disable interface
	sudo ifconfig $INTERFACE down
	if [ TYPE_INTERFACE -eq 1 ];
	then
		if [ -e "/var/run/wpa_supplicant/$INTERFACE" ];
		then
			sudo rm -rf "/var/run/wpa_supplicant/$INTERFACE"
		fi
	fi

	whiptail --yesno "How do you want to use your interface?" --title "Set Network interface" --yes-button "DHCP" --no-button "Static IP" 10 60 2
	case $? in
		0 ) 
			addAutoInterface
			writeDHCPStatusInterface "dhcp"
			
			if [ $TYPE_INTERFACE = 1 ];
			then

				addWpaSupplicant
				writeWpaSupplicant "${2}" "${3}"
			fi
		;;
		1 )
			addAutoInterface
			writeDHCPStatusInterface "manual"
			
			if [ $TYPE_INTERFACE = 1 ];
			then	
				addWpaSupplicant
				writeWpaSupplicant "${2}" "${3}"
			fi
			writeStaticIP
		;;
	esac
	# Re-enable interface and restart network
	sudo systemctl daemon-reload
	sudo service dhcpcd force-reload
	sudo ifconfig $INTERFACE up
	/etc/init.d/networking restart
	sleep 2
	sudo ifconfig $INTERFACE down
	sudo ifconfig $INTERFACE up
	sleep 2
	testConnection
	if [ $? -eq 0 ];
	then
		whiptail --title "Test Connection" --msgbox "The configuration was OK.\nThe connection work correctly." 8 78
	else
		whiptail --title "Test Connection" --msgbox "Test configuration failed.\nThe connection not work correctly." 8 78
	fi
}

testConnection() {
	ping -c 3 "www.google.com" 1>/dev/null
}

setIPNetwork() {
	INTERFACE_FILE=/etc/network/interfaces.d/interfaces
	# Scan interfaces
	local counter=0
	local LIST_INTERF=$(ls /sys/class/net)
	while IFS=' ' read -ra CUTTED_INTERF ; do
		for i in "${CUTTED_INTERF[@]}"; do
 		local INTERF_MENU_LIST=("${INTERF_MENU_LIST[@]}" "$i" "     Interfaccia $counter   " )
		done
		counter=$((counter+1))
	done <<< "$LIST_INTERF"

	
	SET_NET_TIT="Set Network"
	GLOBAL_SUB_TITLE="Select one interface to configure it:"
	drawMenu "$SET_NET_TIT" "${INTERF_MENU_LIST[@]}"

	INTERFACE=$SEL

	# Search if was just configured the interface but exclude the line that starts with '#'
	grep "iface $INTERFACE" "$INTERFACE_FILE" | grep -v "#"
	if [ $? -eq 0 ];
	then
		
		whiptail --yesno "Attention! The interface is already set.\nClear and reinsert it?" 10 60 2
		if [ $? -eq 0 ];
		then
			# findAndRemoveInterface
			sudo sed -i "/#wpa_supplicant_$INTERFACE/,+1 d" $INTERFACE_FILE
			sudo sed -i "/iface $INTERFACE\|auto $INTERFACE\|allow-hotplug $INTERFACE/d" $INTERFACE_FILE
		else
			goToMainMenu
		fi
	fi

	whiptail --yesno "What type of interface you selected?" --title "Set Network interface" --yes-button "Ethernet" --no-button "Wi-fi" 10 60 2
	if [ $? -eq 0 ];
	then
			writeConfigInterface 0
	else
			local SSID_NAME=$(whiptail --inputbox "Insert a SSID of the Wi-fi (Wi-fi name)" 8 78 --title "Set Network interface" 3>&1 1>&2 2>&3)
			if [ ! $? -eq 0 ]; # exitstatus
			then
				goToMainMenu
			fi
			local PASSWORD=$(whiptail --inputbox "Insert a passphrase of Wi-fi" 8 78 --title "Set Network interface" 3>&1 1>&2 2>&3)
			if [ ! $? -eq 0 ]; # exitstatus
			then
				goToMainMenu
			fi

			writeConfigInterface 1 "${SSID_NAME}" "${PASSWORD}"
	fi
	goToMainMenu
}

setCrontab() {
	CMD=$?
	if [ $CMD = "" ];
	then
		CMD=$(whiptail --inputbox "Please enter a valid command" 20 60 3>&1 1>&2 2>&3)
	fi

	if [ $? != 0 ];
	then
		goToMainMenu 
	fi

	whiptail --msgbox "\
Please note: \
\nthe five fields specify how often and when to execute a command: \
		\n\n .---------------- [m]inute: 0 - 59 \
		\n |  .------------- [h]our: 0 - 23 \
		\n |  |  .---------- [d]ay of month: 1 - 31 \
		\n |  |  |  .------- [mon]th: 1 - 12 \
		\n |  |  |  |  .---- [w]eek day: 0 - 6 (sunday=0) \
		\n |  |  |  |  | \
		\n *  *  *  *  * \
		" 20 70 1

	DEF_TIME="* * * * *"
	DEF_TIME=$(whiptail --inputbox "Please enter a valid frequency" 20 60 "$DEF_TIME" 3>&1 1>&2 2>&3)
	
	(crontab -l 2>/dev/null; echo "$DEF_TIME $CMD" ) | crontab -

	CMD=""
	goToMainMenu
}

schedulerMenu() {
	SCH_TIT='Set scheduler configuration'
  declare -a SCH_ARR=(
		'<--- ' 'Back to Main Menu'
		'2.1' 'Add a RESTART scheduler'
		'2.2' 'Add a POWEROFF scheduler' 
		'2.3' 'Add a custom scheduler'
	);
	drawMenu "$SCH_TIT" "${SCH_ARR[@]}"
}

changeSiteURL() {
	if [ -f "$OPENBOX_AUTOSTART" ];
	then 
		whiptail --title "Activate Kiosk Mode" --msgbox "With this option you'are activating a kiosk mode and now you must insert a valid URL" 8 78
		if [ -f "$BASH_RC" ] && [ -e "$BASH_PROFILE" ];
		then
			# extract the old site
			OLD_SITE="$(cut -d "=" -f 2 <<< $(grep "SITE=" $OPENBOX_AUTOSTART))"
			
			grep -q "SITE=" $OPENBOX_AUTOSTART
			if [ ! $? -eq 0 ];
			then
				# remove the line of bashrc to start this config-menu file
				sudo sed -i '/raspi-menu.sh/d' $BASH_RC 
				# remove the last line of bash_profile and add to start startx
				sudo sed -i '/&& \/bin\/bash/d' $BASH_PROFILE
				echo "[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && startx -- -nocursor" > $BASH_PROFILE
				# remove the line of openbox to start this config-menu file
				sudo sed -i '/raspi-menu.sh/d' $OPENBOX_AUTOSTART 

				# remove the last chromium's URL and add the correct one
				CURRENT_URL="https://www.smeup.com"
				SITE=$(whiptail --inputbox "Please enter a valid URL" 20 60 "$CURRENT_URL" 3>&1 1>&2 2>&3)
				sudo echo "SITE=$SITE" >> $OPENBOX_AUTOSTART
				sudo echo "chromium-browser --disable-translate --incognito --disable-infobars --disable-restore-session-state --disable-session-crashed-bubble --kiosk \$SITE &" >> $OPENBOX_AUTOSTART
				NEW_SITE=$SITE
			else
				# set the correct URL
				CURRENT_URL="https://www.smeup.com"
				SITE=$(whiptail --inputbox "Please enter a valid URL" 20 60 "$CURRENT_URL" 3>&1 1>&2 2>&3)
				SITE=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$SITE")
				sudo sed -i 's/^\(\s*SITE=\s*\).*/\1'"$SITE"'/' $OPENBOX_AUTOSTART
				NEW_SITE=$SITE
			fi
			
			if [ $NEW_SITE != $OLD_SITE ];
			then
				whiptail --title "Activate URL Browser" --msgbox "URL Browser changed correctly and succesfull activated KIOSK MODE." 8 78
			else
				whiptail --title "Error!" --msgbox "New site insered not saved correctly." 8 78
			fi
		else
				whiptail --title "Error!" --msgbox "File $BASH_RC or $BASH_PROFILE not found or not accessible." 8 78
		fi
	else
		whiptail --title "Error!" --msgbox "File $OPENBOX_AUTOSTART not found or not accessible." 8 78
	fi
	goToMainMenu
}

updateSystem() {
  testConnection
	if [ $? = 0 ];
	then
		{
			# APT-Update
			i=1
			while read -r line; do
					i=$(( $i + 1 ))
					echo $i
			done < <(sudo apt -y update 2>/dev/null)
		} | whiptail --title "Progress" --gauge "Please wait while system search updating" 6 60 0

		{
			# APT-Upgrade
			i=1
			while read -r line; do
					i=$(( $i + 1 ))
					echo $i
			done < <(sudo apt -y upgrade 2>/dev/null)
		} | whiptail --title "Progress" --gauge "Please wait while system install update" 6 60 0

		{
			# RPI-Update
			i=1
			while read -r line; do
					i=$(( i + 1 ))
					echo $i
			done < <(sudo rpi-update -y 2>/dev/null)
		} | whiptail --title "Progress" --gauge "Please wait while updating your RPI firmware and kernel" 6 60 0
	else
		whiptail --msgbox "Update failed! No connection!" 20 60 1
	fi
  goToMainMenu
} 

updateMenuVersion() {
	local CURRENTVERSION=$(grep -m1 "VERSION=" "$SCRIPT_PATH")
	local GITHUBVERSION=$(curl -s $URL_FILE_MENU/version)

	testConnection
	if [ $? -eq 0 ];
	then
		if [ "$CURRENTVERSION" == "$GITHUBVERSION" ]; then
			whiptail --msgbox "Tool is up to date" 20 60 1
		else
			whiptail --yesno "A new version of this tool is available, download it now?" --title "Update Menu" 10 60 2
			if [ $? -eq 0 ]; 
			then

				wget -q $URL_FILE_MENU -P "$SCRIPT_PATH""_new"
				if [ -f "$SCRIPT_PATH""_new" ];
				then
					cp "$SCRIPT_PATH" "$SCRIPT_PATH""_old"
					rm "$SCRIPT_PATH"
					mv "$SCRIPT_PATH""_new" "$SCRIPT_PATH" 
					chmod +x "$SCRIPT_PATH"
					exec "$SCRIPT_PATH"
				fi
			else
				goToMainMenu
			fi
		fi		
	else
		whiptail --msgbox "Update failed! No connection!" 20 60 1
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
	if [ $? -eq 1 ];
	then
		sync
		exit 0
	else
		sync
		reboot
		exit 0
	fi
}

setExit() {
	if [ -z "${NEW_SITE// }" ] || ( [ $NEW_SITE = $OLD_SITE ] && [ ! -z "${NEW_SITE// }" ] );
		then
			whiptail --yesno "For use raspberry in kios-mode you MUST change the default URL in menu\n\nDo you want to leave without abilitate a Kiosk mode?" 20 60
			if [ $? -eq 0 ];
			then
				goToMainMenu
			else
			  checkHowExit
			fi
		else
			checkHowExit
	fi
}

reset() {
	if [ -d "$BACKUP_DIR" ];
	then
		echo "yes" | sudo cp -rf "$BACKUP_DIR"/autostart "$OPENBOX_AUTOSTART"
		echo "yes" | sudo cp -rf "$BACKUP_DIR"/.bash_profile "$BASH_PROFILE"
		echo "yes" | sudo cp -rf "$BACKUP_DIR"/.bashrc "$BASH_RC"
		echo "yes" | sudo cp -rf "$BACKUP_DIR"/interfaces "/etc/network/interfaces"
		echo "yes" | sudo cp -rf "$BACKUP_DIR"/interfaces.d/interfaces "/etc/network/interfaces.d/interfaces"
		echo "yes" | sudo cp -rf "$BACKUP_DIR"/wpa_supplicant.conf "/etc/wpa_supplicant/wpa_supplicant.conf"
		echo "yes" | sudo cp -rf "$BACKUP_DIR"/dhcpcd.conf "/etc/dhcpcd.conf"
		echo "yes" | sudo cp -rf "$BACKUP_DIR"/hostname "/etc/hostname"
		
		whiptail --title "Reset Raspberry" --msgbox "Raspberry was correctly reset." 8 78

	fi
	goToMainMenu
}

checkIfDoBackup
GLOBAL_SUB_TITLE=""
goToMainMenu

while [ 1 ]
do
	case $SEL in
		1 ) networkMenu
		;;
		2 ) schedulerMenu
		;;
		3 ) changeSiteURL
		;;
		4 ) updateSystem
		;;
		5 ) updateMenuVersion
		;;
		6 ) reset
		;;
    7 ) info 
		;;
		"1.1" ) setHostname
		;;
		"1.2" ) setAutomaticWifi
		;;
		"1.3" ) setIPNetwork
		;;
		"1.4" ) testConnection
			if [ $? -eq 0 ];
			then
				whiptail --title "Test Connection" --msgbox "The configuration was OK.\nThe connection work correctly." 8 78
			else
				whiptail --title "Test Connection" --msgbox "Test configuration failed.\nThe connection not work correctly." 8 78
			fi
			goToMainMenu
		;;
		"2.1" ) setCrontab "sudo systemctl reboot"
		;;
		"2.2" ) setCrontab "sudo systemctl poweroff"
		;;
		"2.3" ) setCrontab
		;;
		"<--- " )

			MAIN_TIT='SmeUP Raspberry Menu'
			declare -a MAIN_ARR=(
				'1' 'Configure Network' 
				'2' 'Configure scheduler' 
				'3' 'Configure default URL for Chrome-kiosk' 
				'4' 'Update system'
				'5' 'Update this menu'
        		'6' 'Reset raspberry'
				'7' 'Info'  
				'0  ' 'Exit'
			);
			drawMenu "$MAIN_TIT" "${MAIN_ARR[@]}"
		;;
		"0  " ) 
			whiptail --msgbox "If you configurated correctly the raspi this will change it in KIOSK MODE.\nNote: This means that this configuration-tool will be hide, but you will can find it at $SCRIPT_PATH" 20 60 2
			setExit
		;;
		* ) SEL="0  "
		;;
	esac
done
exit 0