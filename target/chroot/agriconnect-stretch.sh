#!/bin/sh -e
#
# Copyright (c) 2014-2016 Robert Nelson <robertcnelson@gmail.com>
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
	sync
	echo "${git_target_dir} : ${git_repo}" >> /opt/source/list.txt
}

git_clone_branch() {
	mkdir -p ${git_target_dir} || true
	qemu_command="git clone -b ${git_branch} ${git_repo} ${git_target_dir} --depth 1 || true"
	qemu_warning
	git clone -b ${git_branch} ${git_repo} ${git_target_dir} --depth 1 || true
	sync
	echo "${git_target_dir} : ${git_repo}" >> /opt/source/list.txt
}

git_clone_full() {
	mkdir -p ${git_target_dir} || true
	qemu_command="git clone ${git_repo} ${git_target_dir} || true"
	qemu_warning
	git clone ${git_repo} ${git_target_dir} || true
	sync
	echo "${git_target_dir} : ${git_repo}" >> /opt/source/list.txt
}

setup_system() {
	echo "" >> /etc/securetty
	echo "#USB Gadget Serial Port" >> /etc/securetty
	echo "ttyGS0" >> /etc/securetty
}

install_git_repos() {
	git_repo="https://github.com/strahlex/BBIOConfig.git"
	git_target_dir="/opt/source/BBIOConfig"
	git_clone

	git_repo="https://github.com/RobertCNelson/dtb-rebuilder.git"
	git_target_dir="/opt/source/dtb-4.4-ti"
	git_branch="4.4-ti"
	git_clone_branch

	git_repo="https://github.com/RobertCNelson/dtb-rebuilder.git"
	git_target_dir="/opt/source/dtb-4.9-ti"
	git_branch="4.9-ti"
	git_clone_branch

	git_repo="https://github.com/RobertCNelson/dtb-rebuilder.git"
	git_target_dir="/opt/source/dtb-4.14-ti"
	git_branch="4.14-ti"
	git_clone_branch

	git_repo="https://github.com/beagleboard/bb.org-overlays"
	git_target_dir="/opt/source/bb.org-overlays"
	git_clone
}

add_pip_repo() {
	pip_folder=/home/${rfs_username}/.pip
	mkdir ${pip_folder}
	echo -e "[global]\nextra-index-url=https://packagecloud.io/quan/python3-arm/pypi/simple" > ${pip_folder}/pip.conf
	chown debian: -R ${pip_folder}
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

add_apt_repo() {
	wget -qO- https://repos.influxdata.com/influxdb.key | apt-key add -
	echo "deb https://repos.influxdata.com/debian stretch stable" > /etc/apt/sources.list.d/influxdata.list
}

change_apt_mirror() {
	# Note: The pattern has whitespace, so that we don't replace the "security" repo
	sed -i "s/deb.debian.org\/debian /opensource.xtdv.net/debian /g" /etc/apt/sources.list
}

passwordless_sudo () {
	if [ -d /etc/sudoers.d/ ] ; then
		#Don't require password for sudo access
		echo "${rfs_username} ALL=(ALL:ALL) NOPASSWD:ALL" >/etc/sudoers.d/${rfs_username}
		chmod 0440 /etc/sudoers.d/${rfs_username}
	fi
}

is_this_qemu
setup_system
add_pip_repo
install_pip
add_apt_repo
change_apt_mirror

if [ -f /usr/bin/git ] ; then
	git config --global user.email "${rfs_username}@agriconnect.vn"
	git config --global user.name "${rfs_username}"
	install_git_repos
	git config --global --unset-all user.email
	git config --global --unset-all user.name
fi

passwordless_sudo
