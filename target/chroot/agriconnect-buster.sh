#!/bin/sh -e
#
# Copyright (c) 2014-2019 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

export LC_ALL=en_US.UTF-8

#contains: rfs_username, release_date
if [ -f /etc/rcn-ee.conf ] ; then
	. /etc/rcn-ee.conf
fi

if [ -f /etc/oib.project ] ; then
	. /etc/oib.project
fi

export HOME=/home/${rfs_username}
export USER=${rfs_username}
export USERNAME=${rfs_username}

echo "env: [`env`]"

is_this_qemu() {
	unset warn_qemu_will_fail
	if [ -f /usr/bin/qemu-arm-static ] ; then
		warn_qemu_will_fail=1
	fi
}

qemu_warning() {
	if [ "${warn_qemu_will_fail}" ] ; then
		echo "Log: (chroot) Warning, qemu can fail here... (run on real armv7l hardware for production images)"
		echo "Log: (chroot): [${qemu_command}]"
	fi
}

git_clone() {
	mkdir -p ${git_target_dir} || true
	qemu_command="git clone ${git_repo} ${git_target_dir} --depth 1 || true"
	qemu_warning
	git clone ${git_repo} ${git_target_dir} --depth 1 || true
	chown -R 1000:1000 ${git_target_dir}
	sync
	echo "${git_target_dir} : ${git_repo}" >> /opt/source/list.txt
}

git_clone_branch() {
	mkdir -p ${git_target_dir} || true
	qemu_command="git clone -b ${git_branch} ${git_repo} ${git_target_dir} --depth 1 || true"
	qemu_warning
	git clone -b ${git_branch} ${git_repo} ${git_target_dir} --depth 1 || true
	chown -R 1000:1000 ${git_target_dir}
	sync
	echo "${git_target_dir} : ${git_repo}" >> /opt/source/list.txt
}

git_clone_full() {
	mkdir -p ${git_target_dir} || true
	qemu_command="git clone ${git_repo} ${git_target_dir} || true"
	qemu_warning
	git clone ${git_repo} ${git_target_dir} || true
	chown -R 1000:1000 ${git_target_dir}
	sync
	echo "${git_target_dir} : ${git_repo}" >> /opt/source/list.txt
}

setup_system() {
	echo "" >> /etc/securetty
	echo "#USB Gadget Serial Port" >> /etc/securetty
	echo "ttyGS0" >> /etc/securetty
	# Set locale
	sed -i "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen
	sed -i "s/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/g" /etc/locale.gen
	locale-gen
}

install_git_repos() {
	git_repo="https://github.com/strahlex/BBIOConfig.git"
	git_target_dir="/opt/source/BBIOConfig"
	git_clone

	git_repo="https://github.com/beagleboard/BeagleBoard-DeviceTrees"
	git_target_dir="/opt/source/dtb-4.14-ti"
	git_branch="v4.14.x-ti"
	git_clone_branch

	git_repo="https://github.com/beagleboard/BeagleBoard-DeviceTrees"
	git_target_dir="/opt/source/dtb-4.19-ti"
	git_branch="v4.19.x-ti"
	git_clone_branch

	git_repo="https://github.com/RobertCNelson/dtb-rebuilder.git"
	git_target_dir="/opt/source/dtb-4.19"
	git_branch="4.19.x"
	git_clone_branch

	git_repo="https://github.com/beagleboard/bb.org-overlays"
	git_target_dir="/opt/source/bb.org-overlays"
	git_clone

	git_repo="https://github.com/mcdeoliveira/rcpy"
	git_target_dir="/opt/source/rcpy"
	git_clone

	git_repo="https://github.com/mcdeoliveira/pyctrl"
	git_target_dir="/opt/source/pyctrl"
	git_clone

	git_repo="https://github.com/mvduin/py-uio"
	git_target_dir="/opt/source/py-uio"
	git_clone
}

add_pip_repo() {
	pip_folder=/home/${rfs_username}/.config/pip
	mkdir ${pip_folder} || true
	if [ -d ${pip_folder} ] ; then
		echo -e "[global]\nextra-index-url=https://repo.fury.io/agriconnect/" > ${pip_folder}/pip.conf
		chown debian: -R ${pip_folder}
	fi
	# For root
	pip_folder=/root/.config/pip
	mkdir ${pip_folder} || true
	if [ -d ${pip_folder} ] ; then
		echo -e "[global]\nextra-index-url=https://repo.fury.io/agriconnect/" > ${pip_folder}/pip.conf
	fi
}

install_pip() {
	if [ -f /usr/bin/python3.6 ] ; then
		wget https://bootstrap.pypa.io/get-pip.py || true
		if [ -f get-pip.py ] ; then
			python3.6 get-pip.py
			rm -f get-pip.py || true
			rm -rf /root/.cache/pip
		fi
	fi
}

setup_gateway_config() {
	SRC_DIR=Gateway-Config
	git clone https://gitlab.com/agriconnect/Gateway-Config.git || true
	if [ -d ${SRC_DIR} ] ; then
		cp ${SRC_DIR}/bin/enable-gpio.sh /bin/ || true
		cp ${SRC_DIR}/etc/udev/rules.d/90-beaglebone-uart1.rules /etc/udev/rules.d/ || true
		cp ${SRC_DIR}/lib/systemd/system/beaglebone-gpio.service /lib/systemd/system/ || true
		cp ${SRC_DIR}/lib/systemd/system/ddns-update-cloudns.service /lib/systemd/system/ || true
		cp ${SRC_DIR}/lib/systemd/system/ddns-update-cloudns.timer /lib/systemd/system/ || true
		rm -rf ${SRC_DIR}
	fi
}

setup_gateway_tool() {
	SRC_DIR=Gateway-Tool
	git clone https://gitlab.com/agriconnect/Gateway-Tool.git || true
	if [ -d ${SRC_DIR} ] ; then
		cp ${SRC_DIR}/wait-influxdb/wait-influxdb.sh /usr/local/bin/ || true
		cp ${SRC_DIR}/database-backup/aibackup-db.py /usr/local/bin/ || true
		cp ${SRC_DIR}/database-backup/ph-backup-db.service /lib/systemd/system/ || true
		cp ${SRC_DIR}/database-backup/ph-backup-db.timer /lib/systemd/system/ || true
		rm -rf ${SRC_DIR}
	fi
}

enable_redis_socket() {
	FILEPATH=/etc/redis/redis.conf
	if [ -f $FILEPATH ] ; then
		sed -i 's/# unixsocket/unixsocket/g' ${FILEPATH}
		sed -Ei 's/unixsocketperm [0-9]+/unixsocketperm 766/g' ${FILEPATH}
	fi
}

disable_ipv6_avahi() {
	# Avahi has bug with IPv6, and make it fail to propage mDNS domain.
	sed -i 's/use-ipv6=yes/use-ipv6=no/g' /etc/avahi/avahi-daemon.conf
}

add_apt_repo() {
	wget -qO- https://repos.influxdata.com/influxdb.key | apt-key add -
	echo "deb https://repos.influxdata.com/debian buster stable" > /etc/apt/sources.list.d/influxdata.list
}

change_apt_mirror() {
	# Note: The pattern has whitespace, so that we don't replace the "security" repo
	sed -i "s:deb.debian.org/debian :opensource.xtdv.net/debian :g" /etc/apt/sources.list
}

install_bash_aliases() {
	echo -e "alias ip=\"ip -c\"\nalias ll=\"ls -l\"" > /home/${rfs_username}/.bash_aliases
	chown ${rfs_username}:${rfs_username} /home/${rfs_username}/.bash_aliases
}

passwordless_sudo () {
	if [ -d /etc/sudoers.d/ ] ; then
		# Don't require password for sudo access
		echo "${rfs_username} ALL=(ALL:ALL) NOPASSWD:ALL" >/etc/sudoers.d/${rfs_username}
		chmod 0440 /etc/sudoers.d/${rfs_username}
	fi
}

is_this_qemu
setup_system
add_apt_repo
add_pip_repo
install_pip
install_bash_aliases
enable_redis_socket
disable_ipv6_avahi
change_apt_mirror

if [ -f /usr/bin/git ] ; then
	git config --global user.email "${rfs_username}@agriconnect.vn"
	git config --global user.name "${rfs_username}"
	install_git_repos
	setup_gateway_config
	setup_gateway_tool
	git config --global --unset-all user.email
	git config --global --unset-all user.name
	chown ${rfs_username}:${rfs_username} /home/${rfs_username}/.gitconfig
fi

install_bash_aliases
passwordless_sudo
