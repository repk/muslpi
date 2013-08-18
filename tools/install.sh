#!/bin/sh
#
# install.sh
#
# Copyright (c) 2013 repk
#
# ----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# <repk@triplefau.lt> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return repk
# ----------------------------------------------------------------------------
#

load_utils() {
	. ${TOOLS_BASEDIR}/utils.sh
}

usage() {
	error "Usage: $(basename $0) <pkgfile>"
}

get_args() {
	if [ ${#} -ne 1 ]; then
		usage
	fi
	PKG_FILE=${1}
}


install_pkg() {
	_INSTALL_DIR=$1
	_OLD=${PWD}

	cd ${_INSTALL_DIR}
	bsdtar -xjf ${PKG_ROOT}/${PKG_FILE}
	cd ${_OLD}
}


install_footprint() {
	_INSTALL_DIR=$1
	_PKG_NAME=$2
	_PKG_VERSION=$3

	FOOTPRINT_FILE="${_INSTALL_DIR}/${_PKG_NAME}"

	echo "PACKAGE_NAME:${_PKG_NAME}" >> ${FOOTPRINT_FILE}
	echo "PACKAGE_VERSION:${_PKG_VERSION}" >> ${FOOTPRINT_FILE}
	echo "PACKAGE_TIMESTAMP:$(date '+%s')" >> ${FOOTPRINT_FILE}
	compute_footprint ${PKG_FILE} >> ${FOOTPRINT_FILE}
}


prepare_cross_install() {
	check_file ${PKGMK_COMMONCONF}
	check_file ${PKGMK_CROSSCONF}

	. ${PKGMK_COMMONCONF}
	. ${PKGMK_CROSSCONF}

	if [ ! -d ${CLFS_DIR} ]; then
		dbg 2 "Create clfs dir at ${CLFS_DIR}"
		mkdir -p ${CLFS_DIR}
	fi
	if [ ! -d ${CROSS_INSTALLDB} ]; then
		dbg 2 "Create cross package db at ${CROSS_INSTALLDB}"
		mkdir -p ${CROSS_INSTALLDB}
	fi
}

prepare_host_install() {
	check_file ${PKGMK_COMMONCONF}
	check_file ${PKGMK_HOSTCONF}

	. ${PKGMK_COMMONCONF}
	. ${PKGMK_HOSTCONF}

	if [ ! -d ${TOOLCHAIN_DIR} ]; then
		dbg 2 "Create toolchain dir at ${TOOLCHAIN_DIR}"
		mkdir -p ${TOOLCHAIN_DIR}
	fi
	if [ ! -d ${HOST_INSTALLDB} ]; then
		dbg 2 "Create host package db at ${HOST_INSTALLDB}"
		mkdir -p ${HOST_INSTALLDB}
	fi
}

cross_main() {
	prepare_cross_install
	_PKG_NAME=$(echo ${PKG_FILE} | rev | cut -d'-' -f4- | rev)
	_PKG_VERSION=$(echo ${PKG_FILE} | rev | cut -d'-' -f3 | rev)
	_FOOTPRINT="${CROSS_INSTALLDB}/${_PKG_NAME}"
	_FLOCK="${CROSS_INSTALLDB}/.${_PKG_NAME}.lock"

	dbg 2 "Installing package name: ${_PKG_NAME} version: ${_PKG_VERSION}"

	# Write lock to installed package's footprint
	(
		flock -x 200
		if [ -f ${_FOOTPRINT} ]; then
			echo "Package already installed skipping..."
			exit 0
		fi
		install_pkg ${CLFS_DIR}
		install_footprint ${CROSS_INSTALLDB} ${_PKG_NAME} ${_PKG_VERSION}
	) 200>${_FLOCK}
}

host_main() {
	prepare_host_install
	_PKG_NAME=$(echo ${PKG_FILE} | rev | cut -d'-' -f4- | rev)
	_PKG_VERSION=$(echo ${PKG_FILE} | rev | cut -d'-' -f3 | rev)
	_FOOTPRINT="${HOST_INSTALLDB}/${_PKG_NAME}"
	_FLOCK="${HOST_INSTALLDB}/.${_PKG_NAME}.lock"

	dbg 2 "Installing package name: ${_PKG_NAME} version: ${_PKG_VERSION}"

	# Write lock to installed package's footprint
	(
		flock -x 200
		if [ -f ${_FOOTPRINT} ]; then
			echo "Package already installed skipping..."
			exit 0
		fi
		install_pkg ${TOOLCHAIN_DIR}
		install_footprint ${HOST_INSTALLDB} ${_PKG_NAME} ${_PKG_VERSION}
	) 200>${_FLOCK}
}

main() {
	load_utils
	get_args "$@"

	case ${PKG_FILE} in
	*-*-host-pkg.tar.bz2)
		dbg 1 "Install host package: ${PKG_FILE}"
		host_main
		;;
	*-*-cross-pkg.tar.bz2)
		dbg 1 "Install cross package: ${PKG_FILE}"
		cross_main
		;;
	*)
		error "${PKG_FILE} seems not to be a valid package"
		;;
	esac
}


TOOLS_BASEDIR=$(dirname $(readlink -e $0))
PKGMK_BASEDIR=$(dirname ${TOOLS_BASEDIR})


PKGMK_COMMONCONF="${PKGMK_BASEDIR}/config/common.conf"
PKGMK_CROSSCONF="${PKGMK_BASEDIR}/config/cross.conf"
PKGMK_HOSTCONF="${PKGMK_BASEDIR}/config/toolchain.conf"
PKG_ROOT=${PWD}
PKG_FOOTPRINT="${PKG_ROOT}/.footprint"
PKG_FILE=""
DBGLVL=2

main "$@"
