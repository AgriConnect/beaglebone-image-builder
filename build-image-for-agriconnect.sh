#!/bin/bash -e

TODAY=$(date +%Y-%m-%d)
VERNUM=10.0

check_tools() {
	unset need_tool
	export OLD_PATH=$PATH
	export PATH=$PATH:/sbin:/usr/sbin
	command -v mkfs.vfat >/dev/null 2>&1 || { echo "Missing mkfs.vfat "; need_tool=1; }
	command -v git >/dev/null 2>&1 || { echo "Missing git "; need_tool=1; }
	command -v partprobe >/dev/null 2>&1 || { echo "Missing partprobe "; need_tool=1; }
	command -v kpartx >/dev/null 2>&1 || { echo "Missing kpartx "; need_tool=1; }
	command -v bmaptool >/dev/null 2>&1 || { echo "Missing bmaptool "; need_tool=1; }
	export PATH=$OLD_PATH
	unset OLD_PATH

	if [ ${need_tool} ] ; then
		echo "need_tool: ${need_tool}"
		echo "Please install these packages: dosfstools git-core kpartx wget parted bmap-tools"
		echo ""
		exit
	fi
}

generate_img() {
	cd deploy/debian-${VERNUM}-console-armhf-${TODAY}
	FILENAME=BBB-eMMC-flasher-debian-${VERNUM}-${TODAY}
	echo "Setup image for SD card"
	sudo ./setup_sdcard.sh --img-4gb ${FILENAME} --dtb beaglebone --bbb-flasher --bbb-old-bootloader-in-emmc --hostname beaglebone
	IMGFILE=${FILENAME}-4gb.img
	# Move to deploy/ folder
	mv ${IMGFILE} ../
	# Go to deploy/ folder
	cd ..
	# Generate bmap
	echo "Generate bmap for ${IMGFILE}"
	bmaptool create ${IMGFILE} -o ${FILENAME}-4gb.bmap
	# Compress the image file
	echo "Compress the image file ${IMGFILE}"
	xz -T 0 ${IMGFILE}
	# Go back to original working folder
	cd ..
}

check_tools

# Uncomment this line to enable APT proxy
# export apt_proxy=localhost:3142/

sudo echo "Start sudo session"

./RootStock-NG.sh -c agriconnect_console_debian_buster_armhf

generate_img
