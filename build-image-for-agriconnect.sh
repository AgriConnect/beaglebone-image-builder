#!/bin/bash -e

TODAY=$(date +%Y-%m-%d)
VERNUM=9.3

generate_img() {
	cd deploy/debian-${VERNUM}-console-armhf-${TODAY}
	FILENAME=BBB-eMMC-flasher-debian-${VERNUM}-${TODAY}
	sudo ./setup_sdcard.sh --img-4gb ${FILENAME} --dtb beaglebone --bbb-flasher --bbb-old-bootloader-in-emmc --hostname beaglebone
	IMGFILE=${FILENAME}-4gb.img
	mv ${IMGFILE} ../
	cd ../..
}

./RootStock-NG.sh -c agriconnect_console_debian_stretch_armhf.conf

generate_img
