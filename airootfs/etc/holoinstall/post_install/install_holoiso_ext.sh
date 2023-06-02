#!/bin/zsh
# HoloISO Installer v2
# This defines all of the current variables.
HOLO_INSTALL_DIR="${HOLO_INSTALL_DIR:-/mnt}"
IS_WIN600=$(cat /sys/devices/virtual/dmi/id/product_name | grep Win600)
IS_STEAMDECK=$(cat /sys/devices/virtual/dmi/id/product_name | grep Jupiter)

if [ -n "${IS_WIN600}" ]; then
	GAMEPAD_DRV="1"
fi

if [ -n "${IS_STEAMDECK}" ]; then
	FIRMWARE_INSTALL="1"
fi

check_mount(){
	if [ $1 != 0 ]; then
		echo "\n错误: 挂载分区 $2 时出现问题。请重试!\n"
		echo '按任意键退出...'; read -k1 -s
		exit 1
	fi
}

check_download(){
	if [ $1 != 0 ]; then
		echo "\n错误: 在 $2 时发生了一些问题。\n请确保您的网络连接稳定!\n"
		echo '按任意键退出...'; read -k1 -s
		exit 1
	fi
}

parted_mkpart() {
	DEVICE=$1
	PARTITION_TYPE=$2
	PARTITION_START=$3
	PARTITION_END=$4

	# if not end specified, use 100%
	if [ -z $PARTITION_END ]; then
		PARTITION_END="100%"
	fi

	init_devices=$(lsblk -rno PATH ${DEVICE})
	parted --script ${DEVICE} mkpart primary ${PARTITION_TYPE} ${PARTITION_START} ${PARTITION_END}
	sleep 1
	current_devices=$(lsblk -rno PATH ${DEVICE})
	new_device=$(comm -13 <(echo "$init_devices") <(echo "$current_devices"))
	echo $new_device
}

partitioning(){
	echo "在对话框中选择您的磁盘驱动器:"

	DRIVEDEVICE=$(lsblk -d -o NAME,SIZE,MODEL | sed "1d" | awk '{ printf "FALSE""\0"$0"\0" }' | \
xargs -0 zenity --list --width=600 --height=512 --title="选择磁盘" --text="请在下方选择要安装HoloISO的磁盘:\n\n" \
--radiolist --multiple --column ' ' --column '磁盘')

	DRIVEDEVICE=$(awk '{print $1}' <<< $DRIVEDEVICE)
	
	DEVICE="/dev/${DRIVEDEVICE}"
	
	INSTALLDEVICE="${DEVICE}"

	if [ ! -b $DEVICE ]; then
		echo "未找到 $DEVICE! 安装已中止!"
		exit 1
	fi
	lsblk $DEVICE | head -n2 | tail -n1 | grep disk > /dev/null 2>&1
	if [ $? != 0 ]; then
		echo "$DEVICE 不是磁盘类型! 安装已中止!"
		echo "\n注意: 如果您想进行分区安装,\n请先指定磁盘驱动器节点, 然后选择\"2\"进行分区安装."
		exit 1
	fi
	echo "\n选择您的分区类型:"
	install=$(zenity --list --title="选择您的分区类型:" --column="Type" --column="Name" 1 "擦除整个驱动器" \2 "保留现有的操作系统/分区旁边安装(至少需要50GB的末尾空闲空间)" \3 "擦除一个现有分区安装(分区大小至少需要50GB)"  --width=700 --height=320)
	# if install is 3
	if [[ $install = "3" ]]; then
		echo "在对话框中选择要覆盖的分区:"
	fi

	OVERWRITE_DEVICE=$(lsblk -rno NAME,SIZE,FSTYPE,LABEL ${DEVICE} | sed "1d" | awk '{ printf "FALSE""\0"$0"\0" }' | \
xargs -0 zenity --list --width=600 --height=530 --title="选择分区" --text="请在下方选择要覆盖安装HoloISO的分区:" \
--radiolist --multiple --column ' ' --column '分区')
	OVERWRITE_DEVICE=$(awk '{print $1}' <<< $OVERWRITE_DEVICE)
	# last number of the device name
	OVERWRITE_DEVICE_SER=$(echo $OVERWRITE_DEVICE | sed 's/.*\([0-9]\+\)$/\1/')

	if [[ -n "$(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1)" ]]; then
		HOME_REUSE_TYPE=$(zenity --list --title="警告" --text="在 $(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1) 检测到HoloISO home分区. 请在下方选择适当的操作:" --column="Type" --column="Name" 1 "重新进行格式化安装" \2 "重复使用分区"  --width=500 --height=220)
		mkdir -p /tmp/home
		mount $(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1) /tmp/home
		mkdir -p /tmp/rootpart
		mount $(sudo blkid | grep holo-root | cut -d ':' -f 1 | head -n 1) /tmp/rootpart
			if [[ -d "/tmp/home/.steamos" ]]; then
				echo "Migration data found. Proceeding"
				umount -l $(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1)
				HOLOUSER=$(cat /tmp/rootpart/etc/passwd | grep home | cut -d ':' -f 1)
				MIGRATEDINSTALL="1"
				umount -l $(sudo blkid | grep holo-root | cut -d ':' -f 1 | head -n 1)
			else
					(
					sleep 2
					echo "10"
					HOLOUSER=$(cat /tmp/rootpart/etc/passwd | grep home | cut -d ':' -f 1)
					MIGRATEDINSTALL="1"
					mkdir -p /tmp/home/.steamos/ /tmp/home/.steamos/offload/opt /tmp/home/.steamos/offload/root /tmp/home/.steamos/offload/srv /tmp/home/.steamos/offload/usr/lib/debug /tmp/home/.steamos/offload/usr/local /tmp/home/.steamos/offload/var/lib/flatpak /tmp/home/.steamos/offload/var/cache/pacman /tmp/home/.steamos/offload/var/lib/docker /tmp/home/.steamos/offload/var/lib/systemd/coredump /tmp/home/.steamos/offload/var/log /tmp/home/.steamos/offload/var/tmp
					echo "15" ; sleep 1
					mv /tmp/rootpart/opt/* /tmp/home/.steamos/offload/opt
					mv /tmp/rootpart/root/* /tmp/home/.steamos/offload/root
					mv /tmp/rootpart/srv/* /tmp/home/.steamos/offload/srv
					mv /tmp/rootpart/usr/lib/debug/* /tmp/home/.steamos/offload/usr/lib/debug
					mv /tmp/rootpart/usr/local/* /tmp/home/.steamos/offload/usr/local
					mv /tmp/rootpart/var/cache/pacman/* /tmp/home/.steamos/offload/var/cache/pacman
					mv /tmp/rootpart/var/lib/docker/* /tmp/home/.steamos/offload/var/lib/docker
					mv /tmp/rootpart/var/lib/systemd/coredump/* /tmp/home/.steamos/offload/var/lib/systemd/coredump
					mv /tmp/rootpart/var/log/* /tmp/home/.steamos/offload/var/log
					mv /tmp/rootpart/var/tmp/* /tmp/home/.steamos/offload/var/tmp
					echo "System directory moving complete. Preparing to move flatpak content."
					echo "30" ; sleep 1
					echo "Starting flatpak data migration.\nThis may take 2 to 10 minutes to complete."
					rsync -axHAWXS --numeric-ids --info=progress2 --no-inc-recursive /tmp/rootpart/var/lib/flatpak /tmp/home/.steamos/offload/var/lib/ |    tr '\r' '\n' |    awk '/^ / { print int(+$2) ; next } $0 { print "# " $0 }'
					echo "Finished."
					) |
					zenity --progress --title="Preparing to reuse home at $(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1)" --text="Your installation will reuse following user: ${HOLOUSER} \n\nStarting to move following directories to target offload:\n\n- /opt\n- /root\n- /srv\n- /usr/lib/debug\n- /usr/local\n- /var/cache/pacman\n- /var/lib/docker\n- /var/lib/systemd/coredump\n- /var/log\n- /var/tmp\n" --width=500 --no-cancel --percentage=0 --auto-close
					umount -l $(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1)
					umount -l $(sudo blkid | grep holo-root | cut -d ':' -f 1 | head -n 1)
				fi
	fi
	# 设置root密码
	while true; do
		ROOTPASS=$(zenity --forms --title="账户配置" --text="设置 root 密码" --add-password="root用户密码")
		if [ -z $ROOTPASS ]; then
			zenity --warning --text "No password was set for user \"root\"!" --width=300
			break
		fi
		echo
		ROOTPASS_CONF=$(zenity --forms --title="账户配置" --text="确认 root 密码" --add-password="root用户密码")
		echo
		if [ $ROOTPASS = $ROOTPASS_CONF ]; then
			break
		fi
		zenity --warning --text "前后密码不匹配." --width=300
	done
	# 创建用户
	NAME_REGEX="^[a-z][-a-z0-9_]*\$"
	if [ -z $MIGRATEDINSTALL ]; then
	while true; do
		HOLOUSER=$(zenity --entry --title="账户创建" --text "输入用户名:")
		if [ $HOLOUSER = "root" ]; then
			zenity --warning --text "root用户已存在." --width=300
		elif [ -z $HOLOUSER ]; then
			zenity --warning --text "清创建用户!" --width=300
		elif [ ${#HOLOUSER} -gt 32 ]; then
			zenity --warning --text "用户名长度不能超过32个字符!" --width=400
		elif [[ ! $HOLOUSER =~ $NAME_REGEX ]]; then
			zenity --warning --text "Invalid username \"$HOLOUSER\"\nUsername needs to follow these rules:\n\n- Must start with a lowercase letter.\n- May only contain lowercase letters, digits, hyphens, and underscores." --width=500
		else
			break
		fi
	done
	fi
	# 设置用户密码
	while true; do
		HOLOPASS=$(zenity --forms --title="账户配置" --text="设置用户 $HOLOUSER 的密码" --add-password="用户 $HOLOUSER 的密码")
		echo
		HOLOPASS_CONF=$(zenity --forms --title="账户配置" --text="确认用户 $HOLOUSER 的密码" --add-password="用户 $HOLOUSER 的密码")
		echo
		if [ -z $HOLOPASS ]; then
			zenity --warning --text "请输入用户 \"$HOLOUSER\" 的密码!" --width=300
			HOLOPASS_CONF=unmatched
		fi
		if [ $HOLOPASS = $HOLOPASS_CONF ]; then
			break
		fi
		zenity --warning --text "前后密码不匹配." --width=300
	done
	case $install in
		1)
			destructive=true
			# Umount twice to fully umount the broken install of steam os 3 before installing.
			umount $INSTALLDEVICE* > /dev/null 2>&1
			umount $INSTALLDEVICE* > /dev/null 2>&1
			$INST_MSG1
			if zenity --question --text "警告: 以下驱动器将被完全擦除。驱动器${DEVICE}上的所有数据将丢失! \n\n$(lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,VENDOR,MODEL,SERIAL,MOUNTPOINT ${DEVICE} | sed "1d")\n\n擦除 ${DEVICE} 并开始安装?" --width=700
			then
				echo "\n擦除分区中..."
				sfdisk --delete ${DEVICE}
				wipefs -a ${DEVICE}
				echo "\n创建新的GPT分区..."
				parted ${DEVICE} mklabel gpt
			else
				echo "\n还没有写入任何内容。\n您取消了破坏性的安装, 请重试。"
				echo '按任意键退出...'; read -k1 -s
				exit 1
			fi
			;;
		2)
			echo "\nHoloISO将会与现有的操作系统/分区一同安装。\n请确保在磁盘>>末尾<<处有超过24GB的空闲(未分配)空间可用\n"
			parted $DEVICE print free
			echo "HoloISO将被安装在以下空闲(未分配)空间上.\n"
			parted $DEVICE print free | tail -n2 | grep "Free Space"
			if [ $? != 0 ]; then
				echo "错误！在磁盘末尾未找到可用空间。\n还没有写入任何内容, \n您取消了非破坏性安装, 请重试"
				exit 1
				echo '按任意键退出...'; read -k1 -s
			fi
				$INST_MSG1
			if zenity --question --text "HoloISO将安装在以下空闲(未分配)空间上。\n这看起来没问题吗?\n$(sudo parted ${DEVICE} print free | tail -n2 | grep "Free Space")" --width=500
			then
        		echo "\n开始安装..."
			else
				echo "\n没有写入任何内容, \n您取消了非破坏性安装, 请重试"
				echo '按任意键退出...'; read -k1 -s
				exit 1
        		fi
			;;
		3)
			overwriter_partition=true
			echo "\nHoloISO将覆盖安装在以下分区的空间上 /dev/${OVERWRITE_DEVICE}"
			if zenity --question --text "HoloISO将覆盖安装在以下分区的空间上，原分区数据将会擦除。\n确定吗?\n$(sudo lsblk -f /dev/${OVERWRITE_DEVICE})" --width=500
			then
        		echo "\n开始安装..."
			else
				echo "\n没有写入任何内容, \n您取消了非破坏性安装, 请重试"
				echo '按任意键退出...'; read -k1 -s
				exit 1
        		fi
			;;
		esac

	# numPartitions=$(grep -c ${DRIVEDEVICE}'[0-9]' /proc/partitions)
	
	echo ${DEVICE} | grep -q -P "^/dev/(nvme|loop|mmcblk)"
	if [ $? -eq 0 ]; then
		INSTALLDEVICE="${DEVICE}p"
		# numPartitions=$(grep -c ${DRIVEDEVICE}p /proc/partitions)
	fi

	# if [ overwriter_partition ]; then
	# 	# numPartitions=$(expr $OVERWRITE_DEVICE_SER - 1)
	# 	efiPartNum=$OVERWRITE_DEVICE_SER
	# else
	# 	efiPartNum=$(expr $numPartitions + 1)
	# fi
	
	# rootPartNum=$(expr $numPartitions + 2)
	# swapPartNum=$(expr $numPartitions + 3)
	# homePartNum=$(expr $numPartitions + 4)

	# echo "\n计算空闲空间..."
	# diskSpace=$(awk '/'${DRIVEDEVICE}'/ {print $3; exit}' /proc/partitions)
	# <= 60GB: typical flash drive
	# if [ $diskSpace -lt 60000000 ]; then
	# 	digitMiB=9
	# 	# realDiskSpace=$(parted ${DEVICE} unit MB print free|head -n2|tail -n1|cut -c 16-20)
	# # <= 500GB: typical 512GB hard drive
	# elif [ $diskSpace -lt 500000000 ]; then
	# 	digitMiB=9
	# 	# realDiskSpace=$(parted ${DEVICE} unit MB print free|head -n2|tail -n1|cut -c 20-25)
	# # anything else: typical 1024GB hard drive
	# else
	# 	digitMiB=10
	# 	# realDiskSpace=$(parted ${DEVICE} unit MB print free|head -n2|tail -n1|cut -c 20-26)
	# fi

	if [ $destructive ]; then
		efiStart=2
	else
		if [ overwriter_partition ]; then
			efiStart=$(sudo parted ${DEVICE} unit MiB print|awk '$1 == "'$OVERWRITE_DEVICE_SER'" {print $2}'|sed s/MiB//|sed s/' '//g)
			homeEnd=$(sudo parted ${DEVICE} unit MiB print|awk '$1 == "'$OVERWRITE_DEVICE_SER'" {print $3}'|sed s/MiB//|sed s/' '//g)
		else
			# efiStart=$(parted ${DEVICE} unit MiB print free|tail -n2|sed s/'        '//|cut -c1-$digitMiB|sed s/MiB//|sed s/' '//g)
			efiStart=$(sudo parted ${DEVICE} unit MiB print free|tail -n2|awk '{print $1}'|sed s/MiB//|sed s/' '//g)
		fi
	fi
	efiEnd=$(expr $efiStart + 300)
	rootStart=$efiEnd
	rootEnd=$(expr $rootStart + 20 \* 1024)
	swapStart=$rootEnd
	swapEnd=$(expr $swapStart + 32 \* 1024)

	# if [ $efiEnd -gt $realDiskSpace ]; then
	# 	echo "Not enough space available, please choose another disk and try again"
	# 	exit 1
	# 	echo '按任意键退出...'; read -k1 -s
	# fi

	echo "\nCreating partitions..."
	if [ overwriter_partition ]; then
		echo "Overwriting partition /dev/${OVERWRITE_DEVICE}"
		parted ${DEVICE} rm ${OVERWRITE_DEVICE_SER}
	fi

	efi_partition=$(parted_mkpart ${DEVICE} fat32 ${efiStart}MiB ${efiEnd}MiB)
	efiPartNum=$(echo $efi_partition | grep -o '[0-9]*$')
	parted --script ${DEVICE} set ${efiPartNum} boot on
	parted --script ${DEVICE} set ${efiPartNum} esp on
	# If the available storage is less than 64GB, don't create /home.
	# If the boot device is mmcblk0, don't create an ext4 partition or it will break steamOS versions
	# released after May 20.
	if [ $diskSpace -lt 64000000 ] || [[ "${DEVICE}" =~ mmcblk0 ]]; then
		root_partition=$(parted_mkpart ${DEVICE} btrfs ${rootStart}MiB 100%)
	else
		root_partition=$(parted_mkpart ${DEVICE} btrfs "${rootStart}MiB" "${rootEnd}MiB")
		swap_partition=$(parted_mkpart ${DEVICE} linux-swap "${swapStart}MiB" "${swapEnd}MiB")
		if [ $homeEnd ]; then
			home_partition=$(parted_mkpart ${DEVICE} ext4 ${swapEnd}MiB ${homeEnd}MiB)
		else
			home_partition=$(parted_mkpart ${DEVICE} ext4 ${swapEnd}MiB "100%")
		fi
		home=true
	fi

	mkfs -t vfat -F 32 ${efi_partition}
	fatlabel ${efi_partition} HOLOEFI
	mkfs -t btrfs -f ${root_partition}
	btrfs filesystem label ${root_partition} holo-root
	mkswap ${swap_partition}
	swapon ${swap_partition}
	# swap_uuid="$(blkid ${swap_partition} -o value -s UUID)"

	# Setup home partition ext4 or btrfs
	if [[ $home && "x${HOME_REUSE_TYPE}" != "x2" ]]; then
		HOMETYPE=$(zenity --list --title="选择 home 分区格式:" --column="Type" --column="Name" 1 "ext4" \2 "btrfs"  --width=500 --height=320)
	fi

	if [ $home ]; then
		# reuse home partition if it exists
		if [[ -n "$(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1)" ]]; then
				if [[ "${HOME_REUSE_TYPE}" == "1" ]]; then
					if [[ "${HOMETYPE}" == "1" ]]; then
						mkfs -t ext4 -F -O casefold ${home_partition}
						e2label "${home_partition}" holo-home
					elif [[ "${HOMETYPE}" == "2" ]]; then
						mkfs -t btrfs -f ${home_partition}
						btrfs filesystem label ${home_partition} holo-home
					fi
				elif [[ "${HOME_REUSE_TYPE}" == "2" ]]; then
					echo "Home partition will be reused at $(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1)"
                    home_partition="$(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1)"
				fi
		else
			if [[ "${HOMETYPE}" == "1" ]]; then
				mkfs -t ext4 -F -O casefold ${home_partition}
				e2label "${home_partition}" holo-home
			elif [[ "${HOMETYPE}" == "2" ]]; then
				mkfs -t btrfs -f ${home_partition}
				btrfs filesystem label ${home_partition} holo-home
			fi
		fi
	fi
	echo "\nPartitioning complete, mounting and installing."
}



base_os_install() {
	sleep 1
	clear
	partitioning
	echo "${UCODE_INSTALL_MSG}"
	sleep 1
	clear
	mount -t btrfs -o subvol=/,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} ${HOLO_INSTALL_DIR}
	btrfs subvolume create ${HOLO_INSTALL_DIR}/@
	btrfs subvolume set-default $(btrfs subvolume list ${HOLO_INSTALL_DIR} | grep '@$' | awk '{print $2}') ${HOLO_INSTALL_DIR}
	btrfs subvolume create ${HOLO_INSTALL_DIR}/@snapshots
	umount ${HOLO_INSTALL_DIR}
	mount -t btrfs -o subvol=@,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} ${HOLO_INSTALL_DIR}
	mkdir -p ${HOLO_INSTALL_DIR}/.snapshots
	mount -t btrfs -o subvol=@snapshots,compress-force=zstd:1,discard,noatime,nodiratime,nofail ${root_partition} ${HOLO_INSTALL_DIR}/.snapshots
	check_mount $? root
	${CMD_MOUNT_BOOT}
	check_mount $? boot
	if [ $home ]; then
        mkdir -p ${HOLO_INSTALL_DIR}/home
		if [[ "${HOMETYPE}" == "1" ]]; then
			mount -t ext4 ${home_partition} ${HOLO_INSTALL_DIR}/home
		elif [[ "${HOMETYPE}" == "2" ]]; then
			mount -t btrfs -o subvol=/,compress-force=zstd:1,discard,noatime,nodiratime ${home_partition} ${HOLO_INSTALL_DIR}/home
			btrfs subvolume create ${HOLO_INSTALL_DIR}/home/@home
			btrfs subvolume set-default $(btrfs subvolume list ${HOLO_INSTALL_DIR}/home | grep '@home$' | awk '{print $2}') ${HOLO_INSTALL_DIR}/home
			btrfs subvolume create ${HOLO_INSTALL_DIR}/home/@snapshots
			umount ${HOLO_INSTALL_DIR}/home
			mount -t btrfs -o subvol=@home,compress-force=zstd:1,discard,noatime,nodiratime ${home_partition} ${HOLO_INSTALL_DIR}/home
			mkdir -p ${HOLO_INSTALL_DIR}/home/.snapshots
			mount -t btrfs -o subvol=@snapshots,compress-force=zstd:1,discard,noatime,nodiratime,nofail ${home_partition} ${HOLO_INSTALL_DIR}/home/.snapshots
		fi
		check_mount $? home
	else
		mkdir -p ${HOLO_INSTALL_DIR}/home
		btrfs subvolume create ${HOLO_INSTALL_DIR}/@home
		mount -t btrfs -o subvol=@home,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} ${HOLO_INSTALL_DIR}/home
	fi
    rsync -axHAWXS --numeric-ids --info=progress2 --no-inc-recursive / ${HOLO_INSTALL_DIR} |    tr '\r' '\n' |    awk '/^ / { print int(+$2) ; next } $0 { print "# " $0 }' | zenity --progress --title="Installing base OS..." --text="Bootstrapping root filesystem...\nThis may take more than 10 minutes.\n" --width=500 --no-cancel --auto-close
	arch-chroot ${HOLO_INSTALL_DIR} install -Dm644 "$(find /usr/lib | grep vmlinuz | grep neptune)" "/boot/vmlinuz-$(cat /usr/lib/modules/*neptune*/pkgbase)"
	arch-chroot ${HOLO_INSTALL_DIR} rm /etc/polkit-1/rules.d/99_holoiso_installuser.rules
	cp -r /etc/holoinstall/post_install/pacman.conf ${HOLO_INSTALL_DIR}/etc/pacman.conf
	arch-chroot ${HOLO_INSTALL_DIR} pacman-key --init
    arch-chroot ${HOLO_INSTALL_DIR} pacman -Rdd --noconfirm linux-neptune-61 linux-neptune-61-headers mkinitcpio-archiso
	arch-chroot ${HOLO_INSTALL_DIR} sed -i 's/\(HOOKS=.*k\)/\1 resume/' /etc/mkinitcpio.conf
	arch-chroot ${HOLO_INSTALL_DIR} mkinitcpio -P
    arch-chroot ${HOLO_INSTALL_DIR} pacman -U --noconfirm $(find /etc/holoinstall/post_install/pkgs | grep pkg.tar.zst)

	arch-chroot ${HOLO_INSTALL_DIR} userdel -r liveuser
	check_download $? "installing base package"
	sleep 2
	clear
	
	# sleep 1
	# clear
	# echo "\nBase system installation done, generating fstab..."
	# genfstab -U -p /mnt >> /mnt/etc/fstab
	# sleep 1
	# clear

    echo "Configuring first boot user accounts..."
	rm ${HOLO_INSTALL_DIR}/etc/skel/Desktop/*
    arch-chroot ${HOLO_INSTALL_DIR} rm /etc/sddm.conf.d/* 
	mv /etc/holoinstall/post_install_shortcuts/steam.desktop /etc/holoinstall/post_install_shortcuts/desktopshortcuts.desktop ${HOLO_INSTALL_DIR}/etc/xdg/autostart
    mv /etc/holoinstall/post_install_shortcuts/steamos-gamemode.desktop ${HOLO_INSTALL_DIR}/etc/skel/Desktop	
	echo "\nCreating user ${HOLOUSER}..."
	echo -e "${ROOTPASS}\n${ROOTPASS}" | arch-chroot ${HOLO_INSTALL_DIR} passwd root
	arch-chroot ${HOLO_INSTALL_DIR} useradd --create-home ${HOLOUSER}
	echo -e "${HOLOPASS}\n${HOLOPASS}" | arch-chroot ${HOLO_INSTALL_DIR} passwd ${HOLOUSER}
	echo "${HOLOUSER} ALL=(root) NOPASSWD:ALL" > ${HOLO_INSTALL_DIR}/etc/sudoers.d/${HOLOUSER}
	chmod 0440 ${HOLO_INSTALL_DIR}/etc/sudoers.d/${HOLOUSER}
	echo "127.0.1.1    ${HOLOHOSTNAME}" >> ${HOLO_INSTALL_DIR}/etc/hosts

	arch-chroot ${HOLO_INSTALL_DIR} ln -sf /usr/bin/vim /usr/bin/vi
	arch-chroot ${HOLO_INSTALL_DIR} rm -f /etc/zsh/zshrc
	arch-chroot ${HOLO_INSTALL_DIR} sed -i 's/set mouse=a/set mouse-=a/g' /usr/share/vim/vim90/defaults.vim
	sleep 1
	clear

	echo "\nInstalling bootloader..."
	mkdir -p ${HOLO_INSTALL_DIR}/boot/efi
	mount -t vfat ${efi_partition} ${HOLO_INSTALL_DIR}/boot/efi
	arch-chroot ${HOLO_INSTALL_DIR} holoiso-grub-update
	mount -o remount,rw -t efivarfs efivarfs /sys/firmware/efi/efivars
	# arch-chroot ${HOLO_INSTALL_DIR} efibootmgr -c -d ${DEVICE} -p ${efiPartNum} -L "HoloISO" -l '\EFI\BOOT\BOOTX64.efi'
	arch-chroot ${HOLO_INSTALL_DIR} grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=SteamOS --recheck
	sleep 1
	clear

	sleep 1
	clear
	echo "\nBase system installation done, generating fstab..."
	genfstab -U -p /mnt >> /mnt/etc/fstab
	sleep 1
	clear
}
full_install() {
	if [[ "${GAMEPAD_DRV}" == "1" ]]; then
		echo "You're running this on Anbernic Win600. A suitable gamepad driver will be installed."
		arch-chroot ${HOLO_INSTALL_DIR} pacman -U --noconfirm $(find /etc/holoinstall/post_install/pkgs_addon | grep win600-xpad-dkms)
	fi
	if [[ "${FIRMWARE_INSTALL}" == "1" ]]; then
		echo "You're running this on a Steam Deck. linux-firmware-neptune will be installed to ensure maximum kernel-side compatibility."
		arch-chroot ${HOLO_INSTALL_DIR} pacman -Rdd --noconfirm linux-firmware
		arch-chroot ${HOLO_INSTALL_DIR} pacman -U --noconfirm $(find /etc/holoinstall/post_install/pkgs_addon | grep linux-firmware-neptune)
		arch-chroot ${HOLO_INSTALL_DIR} sed -i 's/\(HOOKS=.*k\)/\1 resume/' /etc/mkinitcpio.conf
		arch-chroot ${HOLO_INSTALL_DIR} mkinitcpio -P
	fi
	echo "\nConfiguring Steam Deck UI by default..."		
    ln -s /usr/share/applications/steam.desktop ${HOLO_INSTALL_DIR}/etc/skel/Desktop/steam.desktop
	echo -e "[General]\nDisplayServer=wayland\n\n[Autologin]\nUser=${HOLOUSER}\nSession=gamescope-wayland.desktop\nRelogin=true\n\n[X11]\n# Janky workaround for wayland sessions not stopping in sddm, kills\n# all active sddm-helper sessions on teardown\nDisplayStopCommand=/usr/bin/gamescope-wayland-teardown-workaround" >> ${HOLO_INSTALL_DIR}/etc/sddm.conf.d/autologin.conf
	arch-chroot ${HOLO_INSTALL_DIR} usermod -a -G rfkill ${HOLOUSER}
	arch-chroot ${HOLO_INSTALL_DIR} usermod -a -G wheel ${HOLOUSER}
	arch-chroot ${HOLO_INSTALL_DIR} usermod -a -G input ${HOLOUSER}
	echo "Preparing Steam OOBE..."
	arch-chroot ${HOLO_INSTALL_DIR} touch /etc/holoiso-oobe
	echo "Cleaning up..."
	cp /etc/skel/.bashrc ${HOLO_INSTALL_DIR}/home/${HOLOUSER}
    arch-chroot ${HOLO_INSTALL_DIR} rm -rf /etc/holoinstall
	arch-chroot ${HOLO_INSTALL_DIR} sed -i 's/zh_CN.UTF-8/en_US.UTF-8/g' /etc/locale.conf
	arch-chroot ${HOLO_INSTALL_DIR} sed -i 's/#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/g' /etc/locale.gen
	arch-chroot ${HOLO_INSTALL_DIR} sed -i 's/#zh_TW.UTF-8 UTF-8/zh_TW.UTF-8 UTF-8/g' /etc/locale.gen
	arch-chroot ${HOLO_INSTALL_DIR} locale-gen
	sleep 1
	clear
}


# The installer itself. Good wuck.
echo "SteamOS 3 Installer"
echo "Start time: $(date)"
echo "Please choose installation type:"
export LANG=en_US.UTF-8
HOLO_INSTALL_TYPE=$(zenity --list --title="Choose your installation type:" --column="Type" --column="Name" 1 "Install HoloISO, version $(cat /etc/os-release | grep VARIANT_ID | cut -d "=" -f 2 | sed 's/"//g') " \2 "Exit installer"  --width=700 --height=220)
if [[ "${HOLO_INSTALL_TYPE}" == "1" ]] || [[ "${HOLO_INSTALL_TYPE}" == "barebones" ]]; then
	echo "Installing SteamOS, barebones configuration..."
	base_os_install
	full_install
	zenity --warning --text="Installation finished! You may reboot now, or type arch-chroot /mnt to make further changes" --width=700 --height=50
else
	zenity --warning --text="Exiting installer..." --width=120 --height=50
fi

echo "End time: $(date)"
