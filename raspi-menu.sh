	#! /bin/bash
	source $EXPORT_ENV_FILENAME


	VERSION=0.0.4
	USER=$SUDO_USER
	HOME=/home/"$USER"
	MENU_FILE_NAME=$MENU_FILE_NAME
	URL_FILE_MENU=$URL_FILE_MENU
	URL_FILE_VERSION_MENU=$URL_FILE_VERSION_MENU
	FILE_VARIATION_PKG=$FILE_VARIATION_PKG
	BACKUP_DIR=$BACKUP_DIR_PATH
	SCRIPT_PATH_NAME=$MENU_SCRIPT_PATH
	SCRIPT_DIR=$MENU_SCRIPT_DIR
	
	if [ ! -z "$CURRENT_KIOSK_URL" ];
	then
		CURRENT_KIOSK_URL=$CURRENT_KIOSK_URL
	else
		CURRENT_KIOSK_URL="http://www.smeup.com"
	fi
	
	OPENBOX_AUTOSTART=/etc/xdg/openbox/autostart
	BOOT_SCRIPT_CONFIG=/boot/config.txt
	BASH_PROFILE="$HOME"/.bash_profile
	BASH_RC="$HOME"/.bashrc

	clear

	checkIfDoBackup() {
		if [ ! -d "$BACKUP_DIR" ];
		then
		createBackupFile
		fi
	}

	createBackupFile() {
		if [ ! -z "$BACKUP_DIR" ];
		then
			sudo mkdir -p "$BACKUP_DIR"
			if [ $? -ne 0 ];
			then
				whiptail --title "Error!" --msgbox "Something was wrong and was not possible create a backup dir." 8 40 2
				exit 1
			fi
		fi
		cp "$SCRIPT_PATH_NAME" "$BACKUP_DIR" >> /dev/null 2>&1	
		sudo cp "$OPENBOX_AUTOSTART" "$BACKUP_DIR" >> /dev/null 2>&1
		sudo cp "$BASH_PROFILE" "$BACKUP_DIR" >> /dev/null 2>&1
		sudo cp "$BOOT_SCRIPT_CONFIG" "$BACKUP_DIR" >> /dev/null 2>&1
		sudo cp "$BASH_RC" "$BACKUP_DIR" >> /dev/null 2>&1
		sudo cp "/etc/network/interfaces" "$BACKUP_DIR" >> /dev/null 2>&1
		mkdir "$BACKUP_DIR"/interfaces.d >> /dev/null 2>&1
		sudo cp "/etc/network/interfaces.d/interfaces" "$BACKUP_DIR"/interfaces.d >> /dev/null 2>&1
		sudo cp "/etc/wpa_supplicant/wpa_supplicant.conf" "$BACKUP_DIR" >> /dev/null 2>&1
		sudo cp "/etc/dhcpcd.conf" "$BACKUP_DIR" >> /dev/null 2>&1
		sudo cp "/etc/hostname" "$BACKUP_DIR" >> /dev/null 2>&1
		sudo cp "$SCRIPT_DIR/$FILE_VARIATION_PKG" "$BACKUP_DIR" >> /dev/null 2>&1
		sudo rm "$SCRIPT_DIR/$FILE_VARIATION_PKG" >> /dev/null 2>&1
	}

	# Check if the user is a root user
	if [ "$(whoami)" != "root" ]; then
			whiptail --title "No root user" --msgbox "Sorry you are not root. You must type: 'sudo <nameOfScript>' \nto restart this script." 8 40 2
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
			whiptail --title "$TITLE" --menu "$SUB_TITLE" 18 60 10 --cancel-button Finish --ok-button Select --clear "${MENU_ITEM[@]}" 3>&2 2>&1 1>&3
		)
		GLOBAL_SUB_TITLE=""
	}

	networkMenu() {
		NET_TIT='Set Network configuration'
	declare -a NET_ARR=(
			'<--- ' 'Back to Main Menu'
			'1.1' 'Add/Modify a '$USER' hostname'
			'1.2' 'Set wi-fi/ethernet interface with a TOOL' 
			'1.3' 'Set wi-fi/ethernet interface manually'
			'1.4' 'Test connection'
			'1.5' 'Reset network'
		);
		drawMenu "$NET_TIT" "${NET_ARR[@]}"
	}

	resetNetwork() {
		whiptail --yesno "Do you really want reset raspberry's network?" --title "Reset network" 8 50 2
		if [ $? -eq 0 ];
		then
			if [ -d "$BACKUP_DIR" ];
			then
				echo "yes" | sudo cp -rf "$BACKUP_DIR"/interfaces "/etc/network/interfaces"
				echo "yes" | sudo cp -rf "$BACKUP_DIR"/interfaces.d/interfaces "/etc/network/interfaces.d/interfaces"
				echo "yes" | sudo cp -rf "$BACKUP_DIR"/wpa_supplicant.conf "/etc/wpa_supplicant/wpa_supplicant.conf"
				echo "yes" | sudo cp -rf "$BACKUP_DIR"/dhcpcd.conf "/etc/dhcpcd.conf"
				echo "yes" | sudo cp -rf "$BACKUP_DIR"/hostname "/etc/hostname"
				
				# Delete lease for interfaces
				sudo rm /var/lib/dhcp/*
				sudo rm /var/lib/dhcpcd5/*

				whiptail --title "Reset Raspberry" --msgbox "Raspberry was correctly reset." 8 78
			fi
		fi
		goToMainMenu
	}

	setAutomaticWifi() {
	if [ $(which wicd-curses) ];
	then
		whiptail --msgbox "After click on OK button, you can choose the Wifi from a list. \
		\nWith the keyboard key '->' you will be able to set the parameters of the wifi interface. \
		\nWith the keyboard key 'Q' you will be able to quit." 15 40 2
		wicd-curses
	else
		whiptail --msgbox "Tool for set wifi automatically not-found (wicd-curses)." 8 40 2
	fi
	goToMainMenu
	}

	setHostname() {
		whiptail --msgbox 
	"Please note:\n\n \ 
	\nhostname's labels may contain only the ASCII letters from 'a' to 'z' (case-insensitive), the digits from '0' to '9', and the hypen '-'.\
	\nHostname labels cannot begin or end with a hypen '-'. \
	\nNO OTHER SYMBOLS, punctuation characters, or blank spaces are permitted.\
		" 20 70 1
		CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
		NEW_HOSTNAME=$(whiptail --inputbox "Please enter a hostname" 20 60 "$CURRENT_HOSTNAME" 3>&1 1>&2 2>&3)
	
		if [ $? -eq 0 ];
		then
			echo $NEW_HOSTNAME > /etc/hostname
			sudo sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts

			if [ $? -eq 0 ]; then
				whiptail --msgbox "Hostname changed succesfull." 20 70 1
			else
				whiptail --msgbox "Something went wrong. Try again." 20 70 1
			fi
		fi
		goToMainMenu
	}

	writeStaticIP(){
		unset IP_ROUTER
		unset IP_DNS
		local IP_ADDR=$(whiptail --inputbox "Insert a CIDR IP address with a SUBNETMASK like 192.168.168.207/16" 8 78 --title "Insert static IP" 3>&1 1>&2 2>&3)
		if [ $? -eq 0 ];
		then
			local IP_ROUTER=$(whiptail --inputbox "Insert RouterIP address \nNote: Nothing if don't want to set it." 8 78 --title "Insert router IP" 3>&1 1>&2 2>&3)
			if [ $? -eq 0 ];
			then
				local IP_DNS=$(whiptail --inputbox "Insert the IP address for DNS, if are multiple DNS you can divide it by a space \" \"\nNote: Nothing if don't want to set it." 8 78 --title "Insert DNS IP" 3>&1 1>&2 2>&3)
				if [ $? -eq 0 ];
				then

					echo -e "#-!-$INTERFACE-# \ninterface $INTERFACE" >> /etc/dhcpcd.conf
					echo -e "#-!-$INTERFACE-# \nstatic ip_address=$IP_ADDR" >> /etc/dhcpcd.conf
				
					if [ ! -z $IP_ROUTER ];
					then
						echo -e "#-!-$INTERFACE-# \nstatic routers=$IP_ROUTER" >> /etc/dhcpcd.conf
					fi
					if [ ! -z $IP_DNS ];
					then
						echo -e "#-!-$INTERFACE-# \nstatic domain_name_servers=$IP_DNS" >> /etc/dhcpcd.conf
					fi
				fi
			fi
		fi
		goToMainMenu
			
	}

	addAutoInterface() {
		echo "" >> $INTERFACE_FILE
		echo "auto $INTERFACE" >> $INTERFACE_FILE
	}

	addHotPlugInterface() {
		echo "allow-hotplug $INTERFACE" >> $INTERFACE_FILE
	}

	addWpaSupplicant() {
		echo "#wpa_supplicant_$INTERFACE" >> $INTERFACE_FILE
		echo "wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf" >> $INTERFACE_FILE
	}

	writeWpaSupplicant() { # (ssid,passw)
		WPASUPPLICANT_FILE=/etc/wpa_supplicant/wpa_supplicant.conf
		echo 'network={' >> $WPASUPPLICANT_FILE
		echo "	ssid=\"$1\"" >> $WPASUPPLICANT_FILE
		echo "	psk=\"$2\"" >> $WPASUPPLICANT_FILE
		echo "	key_mgmt=WPA-PSK" >> $WPASUPPLICANT_FILE
		echo '}' >> $WPASUPPLICANT_FILE
	}

	writeDHCPStatusInterface() { # (type_interface)
		echo "iface $INTERFACE inet $1" >> $INTERFACE_FILE
	}

	writeConfigInterface() { # (type,ssid,passw)
		TYPE_INTERFACE=$1

		# Disable interface
		sudo ifconfig $INTERFACE down
		if [ $TYPE_INTERFACE -eq 1 ];
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
				addHotPlugInterface
				writeDHCPStatusInterface "dhcp"
				
				if [ $TYPE_INTERFACE = 1 ];
				then
					addWpaSupplicant
					writeWpaSupplicant "${2}" "${3}"
				fi
			;;
			1 )
				addAutoInterface
				addHotPlugInterface
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
		whiptail --title "Set Network interface" --msgbox "Please Wait.....Raspberry's network will restarting soon." 8 78
		sudo systemctl daemon-reload >> /dev/null 2>&1
		sudo service dhcpcd force-reload >> /dev/null 2>&1
		sudo ifconfig $INTERFACE up >> /dev/null 2>&1
		sleep 2
		sudo rm -rf /var/run/wpa_supplicant/$INTERFACE >> /dev/null 2>&1
		sudo /etc/init.d/networking restart >> /dev/null 2>&1
		sleep 2
		testConnection
		if [ $? -eq 0 ];
		then
			whiptail --title "Test Connection" --msgbox "Result Test: OK!\nThe connection work correctly." 8 78
		else
			whiptail --title "Test Connection" --msgbox "Result Test: FAILED!\nEnable connection require to reboot the raspberry." 8 78
		fi
	}

	testConnection() {
		ping -c 3 "www.google.com" >> /dev/null 2>&1
	}

	setIPNetwork() {
		INTERFACE_FILE=/etc/network/interfaces.d/interfaces
		# Scan interfaces without "lo" interface
		local counter=0
		local LIST_INTERF=$(ls /sys/class/net --hide="lo")
		# Count all interface found
		while IFS=' ' read -ra CUTTED_INTERF ; do
			for i in "${CUTTED_INTERF[@]}"; do
			local INTERF_MENU_LIST=("${INTERF_MENU_LIST[@]}" "$i" "     Interfaccia $counter   " )
			done
			counter=$((counter+1))
		done <<< "$LIST_INTERF"

		
		SET_NET_TIT="Set Network"
		GLOBAL_SUB_TITLE="Select one interface to configure it:"
		drawMenu "$SET_NET_TIT" "${INTERF_MENU_LIST[@]}"
		
		INTERFACE=''
		unset CANCEL
		INTERFACE=$SEL
		
		if [ ! -z "$INTERFACE" ];
		then 
			# Search if was just configured the interface but exclude the line that starts with '#'
			grep "iface $INTERFACE" "$INTERFACE_FILE" | grep -v "#"
			if [ $? -eq 0 ];
			then
				unset CANCEL
				whiptail --yesno "Attention! The interface is already set.\nClear and reinsert it?" 10 60 2
				if [ $? -eq 0 ];
				then
					# find and remove interface
					sudo sed -i "/#wpa_supplicant_$INTERFACE/,+1 d" $INTERFACE_FILE
					sudo sed -i "/iface $INTERFACE\|auto $INTERFACE\|allow-hotplug $INTERFACE/d" $INTERFACE_FILE

					# find and remove static IP if set
					DHCPCD_FILE=/etc/dhcpcd.conf
					grep "#-!-$INTERFACE-#" $DHCPCD_FILE >> /dev/null 2>&1
					if [ $? -eq 0 ];
					then
						sudo sed -i "/#-!-$INTERFACE-#/,+1 d" $DHCPCD_FILE
					fi
				
				else
					CANCEL=1
				fi
			fi
			if [ -z "$CANCEL" ];
			then
				#whiptail --yesno "What type of interface you selected?" --title "Set Network interface" --yes-button "Ethernet" --no-button "Wi-fi" 10 60 2
				
				# Calculate if is standard ethernet or standard wifi
				REGEX="eth*"
				[[ $INTERFACE  =~ $REGEX ]]
				# echo ${BASH_REMATCH[0]}
				
				if [ $? -eq 0 ];
				then
						writeConfigInterface 0
				else
						unset SSID_NAME
						unset CANCEL
						while [ -z "$SSID_NAME" ]; do
							SSID_NAME=$(whiptail --inputbox "Insert a SSID of the Wi-fi (Wi-fi name)" --title "Set Network interface" 8 78 3>&1 1>&2 2>&3)
							if [ $? -eq 1 ];
							then
								CANCEL=1
								break
							elif [ -z "$SSID_NAME" ];
							then
								whiptail --msgbox "SSID cannot be empty. Please try insert again." 10 60
							fi
						done

						
						if [ -z "$CANCEL" ];
						then
							# Check if SSID is present in wpa_supplicant
							grep "ssid=\"$SSID_NAME\"" /etc/wpa_supplicant/wpa_supplicant.conf
							if [ $? -eq 0 ];
							then
								whiptail --yesno "SSID already configured!\n Do you want to reconfigure?" --title "Set Wifi" 10 60 2
								if [ $? -eq 0 ];
								then
									WPA_CONF=1
								else
									unset WPA_CONF
									CANCEL=1
								fi
							fi
						fi

						if [ -z "$CANCEL" ];
						then
							PASSWORD=$(whiptail --inputbox "Insert a passphrase of Wi-fi" 8 78 --title "Set Network interface" 3>&1 1>&2 2>&3)
							if [ $? -eq 1 ];
							then
								CANCEL=1
							fi

							if [ -z "$CANCEL" ];
							then
								if [ -z $WPA_CONF ];
								then
									writeConfigInterface 1 "${SSID_NAME}" "${PASSWORD}"
								else # Exchange the value of passphrase already set
									sudo sed -i "/ssid=\"$SSID_NAME\"/,/\}/ s/^\(\s*psk=\s*\).*/\1\"$PASSWORD\"/" /etc/wpa_supplicant/wpa_supplicant.conf
								fi
							fi
						fi
				fi
			fi
		fi
		goToMainMenu
	}

	setCrontab() {
		CMD=$1
		if [ -z "$CMD" ];
		then
			CMD=$(whiptail --title "Set scheduled task" --inputbox "Please enter a valid task command: \
			\nFor example: \
			\n sudo /etc/init.d/networking restart" 20 60 3>&1 1>&2 2>&3)
		fi

		if [ $? -ne 1 ];
		then
			DEF_TIME="* * * * *"
			DEF_TIME=$(whiptail --inputbox "Insert the frequency for schedule a task. \
			\n\nPlease note: \
	\nthe five fields specify how often and when to execute a command: \
	\nThe value must be separated by ONE space! \
	\nFor example:
	\n  - restart the raspi every 2 hour the script will be: \
	\n    * 2 * * * \
	\n  - restart the raspi every sunday at 8pm the script will be: \
	\n    * 20 7 * * \
			\n\n.---------------- [m]inute: 0 - 59 \
			\n| .------------- [h]our: 0 - 23 \
			\n| | .---------- [d]ay of month: 1 - 31 \
			\n| | | .------- [mon]th: 1 - 12 \
			\n| | | |  .---- [w]eek day: 0 - 6 (sunday=0) \
			\n| | | | | \
			\n* * * * * " --title "Set frequency task" 30 80 "$DEF_TIME" 3>&1 1>&2 2>&3)
			
			(crontab -l 2>/dev/null; echo "$DEF_TIME $CMD" ) | crontab -

			CMD=""
		fi
		goToMainMenu
	}

	getCrontab() {
		LIST_CRONTAB=$(sudo crontab -l 2>/dev/null)
		if [ $? -eq 0 ];
		then
			whiptail --msgbox "Please note: \
	\nthe five fields specify how often and when to execute a command: \
			\n.----------------- [m]inute: 0 - 59 \
			\n| .-------------- [h]our: 0 - 23 \
			\n| | .----------- [d]ay of month: 1 - 31 \
			\n| | | .-------- [mon]th: 1 - 12 \
			\n| | | |  .----- [w]eek day: 0 - 6 (sunday=0) \
			\n| | | | |  .- Command to schedule\
			\n| | | | |  | 
			\n\n\n$LIST_CRONTAB" --title "List of active scheduler" 30 70 1
		else
			whiptail --title "List of active scheduler" --msgbox "No scheduler found" 20 70 1
		fi
		goToMainMenu
	}

	resetCrontab() {
		whiptail --yesno "Do you really want reset all scheduled tasks?" --title "Reset scheduled tasks" 8 40 2
		RESP=$?
		# if there are a crontab
		sudo crontab -l >> /dev/null 2>&1
		CRON_EXIT=$?
		if [ $RESP -eq 0 ] && [ $CRON_EXIT -eq 0 ];
		then
			sudo crontab -r >> /dev/null 2>&1
			RESET_CRON_EXIT=$?
			sudo crontab -l >> /dev/null 2>&1
			CRON_EXIT=$?
			# If there aren't a crontab and the reset result ok
			if [ $RESET_CRON_EXIT -eq 0 ] && [ $CRON_EXIT -eq 1 ];
			then
				whiptail --title "Reset scheduled tasks" --msgbox "Result Reset: OK!\nAll tasks was successfully reset." 8 78
			else
				whiptail --title "Reset scheduled tasks" --msgbox "Result Reset: FAILED!\nThe tasks wasn't reset" 8 78
			fi
		else
			whiptail --title "Reset scheduled tasks" --msgbox "Result Reset: FAILED!\nNo tasks to reset." 8 78
		fi
		goToMainMenu
	}

	schedulerMenu() {
		SCH_TIT='Set scheduler configuration'
	declare -a SCH_ARR=(
			'<--- ' 'Back to Main Menu'
			'2.1' 'Add a RESTART scheduler task'
			'2.2' 'Add a POWEROFF scheduler task' 
			'2.3' 'Add a custom scheduler task'
			'2.4' 'List all scheduled tasks'
			'2.5' 'Reset all scheduled tasks'
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
					SITE=$(whiptail --inputbox "Please enter a valid URL" 20 60 "$CURRENT_KIOSK_URL" 3>&1 1>&2 2>&3)
					sudo echo "SITE=$SITE" >> $OPENBOX_AUTOSTART
					sudo echo 'chromium-browser --disable-features=site-per-process,TranslateUI,BlinkGenPropertyTrees,IsolateOrigins --disable-extensions --disable-popup-blocking --incognito --disable-infobars --disable-restore-session-state --disable-session-crashed-bubble --kiosk "$SITE" &' >> $OPENBOX_AUTOSTART
					NEW_SITE=$SITE
				else
					# set the correct URL
					unset SITE
					
					
					while [ -z "$SITE" ]; do
						SITE=$(whiptail --inputbox "Please enter a valid URL" 20 60 "$CURRENT_KIOSK_URL" 3>&1 1>&2 2>&3)
						if [ $? -eq 1 ];
						then
							CANCEL=1
							break
						elif [ -z "$SITE" ];
						then
							whiptail --title "Error!" --msgbox "Site URL cannot be empty. Please try insert again."  8 40
						fi
					done

					if [ -z "$CANCEL" ];
					then
						NEW_SITE=$SITE
						SITE=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$SITE")
						sudo sed -i 's/^\(\s*SITE=\s*\).*/\1'\'$SITE\''/' $OPENBOX_AUTOSTART
					fi
				fi

				if [ -z "$CANCEL" ];
				then
					if [ "$NEW_SITE" == "$OLD_SITE" ];
					then
						whiptail --title "Error!" --msgbox "New site insered is the same that was stored. Kiosk-Mode NOT set." 8 40
					else
						whiptail --title "Activate URL Browser" --msgbox "URL Browser changed correctly and succesfull activated KIOSK MODE." 8 40
					fi
				fi
			else
					whiptail --title "Error!" --msgbox "File $BASH_RC or $BASH_PROFILE not found or not accessible." 8 40
			fi
		else
			whiptail --title "Error!" --msgbox "File $OPENBOX_AUTOSTART not found or not accessible." 8 40
		fi
		goToMainMenu
	}

	rotateMonitor() {
		whiptail --title "Orientation" --radiolist \
"Choose the screen orientation" 20 78 4 \
"0" "Normal (0 degrees)" ON \
"1" "Rotate of 90 degrees" OFF \
"2" "Rotate of 180 degrees" OFF \
"3" "Rotate of 270 degrees" OFF 
		
		ORIENTATION=$?
		
		if [ ! -z $ORIENTATION ];
		then
			echo "[Screen Rotation]\ndisplay_rotate=$ORIENTATION" >> $BOOT_SCRIPT_CONFIG
		fi

		whiptail --title "Info" --msgbox "Attention! For take changes raspberry must will reboot." 8 40
		goToMainMenu
	}

	changeUserPassword() {
		unset PSWD
		unset CANCEL
		unset PSWD_CONFIRM
		while [ -z "$PSWD" ]; do
			PSWD=$(whiptail --inputbox "Please enter a valid password for $SUDO_USER user:" 20 60 3>&1 1>&2 2>&3)
			if [ $? -eq 1 ];
			then
				CANCEL=1
				break
			elif [ -z "$PSWD" ];
			then
				whiptail --title "Error!" --msgbox "Password cannot be empty. Please try insert again."  8 40
			fi
		done

		if [ -z "$CANCEL" ];
		then
			while [ -z "$PSWD_CONFIRM" ] || [ "$PSWD_CONFIRM" != "$PSWD"  ]; do
				PSWD_CONFIRM=$(whiptail --inputbox "Please confirm previous password for $SUDO_USER user:" 20 60 3>&1 1>&2 2>&3)
				if [ $? -eq 1 ];
					then
						CANCEL=1
						break
					else
						if [[ "$PSWD" != "$PSWD_CONFIRM" ]] || [ -z "$PSWD_CONFIRM" ];
						then
							whiptail --title "Error!" --msgbox "Password cannot be different from previous. Please try insert again."  8 40
						else
							echo "$SUDO_USER:$PSWD_CONFIRM" | sudo chpasswd
							whiptail --title "Password Changed!" --msgbox "Password was changed correctly"  8 40
						fi
				fi
			done
		fi
		goToMainMenu
	}

	updateSystem() {
	testConnection
		if [ $? -eq 0 ];
		then
			{
				# APT-Update
				i=1
				while read -r line; do
						i=$(( $i + 1 ))
						echo $i
				done < <(sudo apt -y update >> /dev/null 2>&1)
			} | whiptail --title "Progress" --gauge "Please wait while system search updating" 6 60 0

			{
				# APT-Upgrade
				i=1
				while read -r line; do
						i=$(( $i + 1 ))
						echo $i
				done < <(sudo apt -y upgrade >> /dev/null 2>&1)
			} | whiptail --title "Progress" --gauge "Please wait while system install update" 6 60 0

	#		{
				# RPI-Update
	#			i=1
	#			while read -r line; do
	#					i=$(( i + 1 ))
	#					echo $i
	#			done < <(sudo rpi-update -y >> /dev/null 2>&1)
	#		} | whiptail --title "Progress" --gauge "Please wait while updating your RPI firmware and kernel" 6 60 0
		else
			whiptail --msgbox "Update result: FAILED!\nNo active connection found!" --title "Update ERROR" 8 60 1
		fi
	goToMainMenu
	} 

	updateMenuVersion() {	
		testConnection
		if [ $? -eq 0 ];
		then
			# The tr -d '[:space:]' is used to trim the string
			CURRENTVERSION=$(grep -m1 "VERSION=" "$SCRIPT_PATH_NAME" | tr -d '[:space:]')
			GITHUBVERSION=$(curl -s $URL_FILE_VERSION_MENU | tr -d '[:space:]')
			if [ $(echo $GITHUBVERSION | grep -i "VERSION=") ];
			then
				if [[ "$CURRENTVERSION" == "$GITHUBVERSION" ]]; then
					whiptail --msgbox "Update result: OK!\nThe menu tool is up to date" --title "Update Menu" 8 40 1
				else
					whiptail --yesno "A new version of this tool is available, download it now?" --title "Update Menu" 8 40 2
					if [ $? -eq 0 ]; 
					then

						wget -q $URL_FILE_MENU -O "$SCRIPT_PATH_NAME""_new"
						if [ -f "$SCRIPT_PATH_NAME""_new" ];
						then
							cp "$SCRIPT_PATH_NAME" "$SCRIPT_PATH_NAME""_old" >> /dev/null 2>&1
							rm "$SCRIPT_PATH_NAME" >> /dev/null 2>&1
							# create a backup of old menu
							cp "$SCRIPT_PATH_NAME" "$BACKUP_DIR"/$MENU_FILE_NAME"_old"
							# create a backup of new menu
							cp "$SCRIPT_PATH_NAME""_new" "$BACKUP_DIR"/"$MENU_FILE_NAME"
							# substitute a old menu with a new
							mv "$SCRIPT_PATH_NAME""_new" "$SCRIPT_PATH_NAME" >> /dev/null 2>&1
							chmod +x "$SCRIPT_PATH_NAME" >> /dev/null 2>&1
							sudo exec "$SCRIPT_PATH_NAME"
						fi
					else
						goToMainMenu
					fi
				fi		
			else
				whiptail --msgbox "Update result: FAILED!\nProblem to found a version file!" --title "Update ERROR" 8 40 1
			fi
		else
			whiptail --msgbox "Update result: FAILED!\nNo active connection found!" --title "Update ERROR" 8 40 1
		fi
	goToMainMenu
	}

	restoreLastOldMenu() {
		if [ -f $BACKUP_DIR/$MENU_FILE_NAME"_old" ];
		then
			VERSION_OLD= `cat $BACKUP_DIR/$MENU_FILE_NAME"_old" | grep "VERSION" | cut -d'=' -f2`
			whiptail --yesno "Do you really restore old menu?\n"\
			"\n"\
			"    From           To\n"\
			"  [v$VERSION] ---> [v$VERSION_OLD]" --title "Restore OLD Menu" 10 35 2
				if [ $? -eq 0 ]; 
				then
					mv $BACKUP_DIR/$MENU_FILE_NAME"_old" $SCRIPT_PATH_NAME
					rm $BACKUP_DIR/$MENU_FILE_NAME"_old"
					cp "$SCRIPT_PATH_NAME" "$BACKUP_DIR"
					sudo exec "$SCRIPT_PATH_NAME"
				fi
		else
			whiptail --msgbox "Restore result: FAILED!\nProblem to found a old version file!" --title "Restore OLD menu" 8 40 1	
		fi
		goToMainMenu
	}

	info() {
	local MESSAGE="\
Menu version: $VERSION\n\
Writed by: Sme.UP Spa"
	whiptail --title "INFO" --msgbox "$MESSAGE" 10 30 1
	goToMainMenu
	}

	checkHowExit() {
		whiptail --title "Reboot raspberry" --yesno "For take changes raspberry must will reboot. Would you like to reboot now?" 20 60 2
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
				whiptail --title "No KIOSK mode" --yesno "For use raspberry in kios-mode you MUST change the default URL in menu\n\nDo you want to leave without abilitate a Kiosk mode?" 20 60
				if [ $? -eq 0 ];
				then
					checkHowExit
				else
					goToMainMenu
				fi
			else
				checkHowExit
		fi
	}

	reset() {
		whiptail --yesno "Do you really want reset raspberry?" --title "Reset raspberry" 8 40 2
		if [ $? -eq 0 ];
		then
			if [ -d "$BACKUP_DIR" ];>> /dev/null
			then
				echo "yes" | sudo cp -rf "$BACKUP_DIR"/autostart "$OPENBOX_AUTOSTART"
				echo "yes" | sudo cp -rf "$BACKUP_DIR"/.bash_profile "$BASH_PROFILE"
				echo "yes" | sudo cp -rf "$BACKUP_DIR"/.bashrc "$BASH_RC"
				echo "yes" | sudo cp -rf "$BACKUP_DIR"/config.txt "$BOOT_SCRIPT_CONFIG"
				echo "yes" | sudo cp -rf "$BACKUP_DIR"/interfaces "/etc/network/interfaces"
				echo "yes" | sudo cp -rf "$BACKUP_DIR"/interfaces.d/interfaces "/etc/network/interfaces.d/interfaces"
				echo "yes" | sudo cp -rf "$BACKUP_DIR"/wpa_supplicant.conf "/etc/wpa_supplicant/wpa_supplicant.conf"
				echo "yes" | sudo cp -rf "$BACKUP_DIR"/dhcpcd.conf "/etc/dhcpcd.conf"
				echo "yes" | sudo cp -rf "$BACKUP_DIR"/hostname "/etc/hostname"
				
				# Usato comando e non funzione di cancellazione per i whiptail che si porta dietro
				sudo crontab -r >> /dev/null 2>&1

				# Delete lease for interfaces
				sudo rm /var/lib/dhcp/* >> /dev/null 2>&1
				sudo rm /var/lib/dhcpcd5/* >> /dev/null 2>&1

				whiptail --title "Reset Raspberry" --msgbox "Raspberry was correctly reset." 8 78
			fi
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
			4 ) rotateMonitor
			;;
			4 ) changeUserPassword
			;;
			6 ) updateSystem
			;;
			7 ) updateMenuVersion
			;;
			8 ) restoreLastOldMenu
			;;
			9 ) reset
			;;
			10 ) info 
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
					whiptail --title "Test Connection" --msgbox "Result Test: OK!\nThe connection work correctly." 8 78
				else
					whiptail --title "Test Connection" --msgbox "Result Test: FAILED!\nThe connection not work correctly." 8 78
				fi
				goToMainMenu
			;;
			"1.5" ) resetNetwork
			;;
			"2.1" ) setCrontab "sudo systemctl reboot"
			;;
			"2.2" ) setCrontab "sudo systemctl poweroff"
			;;
			"2.3" ) setCrontab
			;;
			"2.4" ) getCrontab
			;;
			"2.5" ) resetCrontab
			;;
			"<--- " )

				MAIN_TIT='SmeUP Raspberry Menu'
				declare -a MAIN_ARR=(
					'1' 'Configure Network' 
					'2' 'Configure scheduler' 
					'3' 'Configure default URL for Chrome-kiosk' 
					'4' 'Monitor orientation'
					'5' 'Change '"$SUDO_USER"' password'
					'6' 'Update system'
					'7' 'Update this menu'
					'8' 'Restore old version menu'
					'9' 'Reset raspberry'
					'10' 'Info'  
					'0  ' 'Exit'
				);
				drawMenu "$MAIN_TIT" "${MAIN_ARR[@]}"
			;;
			"0  " ) 
				whiptail --title "How find menu" --msgbox "If you configurated correctly the raspi this will change it in KIOSK MODE.\
				\n\nNote: \
				\nThis means that this configuration-tool will be hide, but you will can find it at \
				\n   $SCRIPT_PATH_NAME \
				\nTo run this menu you only will must write \
				\n   menu \
				\n or sudo bash $SCRIPT_PATH_NAME" 20 60 3
				setExit
			;;
			* ) SEL="0  "
			;;
		esac
	done
	exit 0