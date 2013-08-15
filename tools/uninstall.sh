#!/bin/sh
#
# uninstall.sh
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
	error "Usage: $(basename $0) <pkg> (host)"
}


get_args() {
	if [ ${#} -ne 1 ] && [ ${#} -ne 2 ]; then
		usage
	fi
	PKG_NAME=$1
	if [ ${#} -eq 2 ] && [ $2 = "host" ]; then
		REMOVE_HOST=1
	fi
}


get_package() {
	_FOOTPRINT=${1}
	if [ -f ${_FOOTPRINT} ]; then
		return 0
	fi
	return 1
}


remove() {
	_F=$1
	if [ -f ${_F} ]; then
		rm -f ${_F}
	elif [ -d ${_F} ]; then
		if [ -z "$(ls -A ${_F} 2> /dev/null)" ]; then
			rmdir ${_F}
		fi
	fi
}

pkg_remove() {
	_FILE_DIR=${1}
	_FOOTPRINT=${2}

	# Sorted file list
	FILE_LIST=$(cat ${_FOOTPRINT} | grep -v -e "^PACKAGE_" |
			awk '{ print length(), $2 | "sort -n -r"}' |
			cut -d' ' -f2)

	for F in ${FILE_LIST}; do
		remove ${_FILE_DIR}/${F}
	done
}


remove_cross() {
	# CROSS PACKAGE
	_FOOTPRINT="${CROSS_INSTALLDB}/${PKG_NAME}"
	_FLOCK="${CROSS_INSTALLDB}/.${PKG_NAME}.lock"
	(
		flock -x 200
		get_package ${_FOOTPRINT}
		if [ $? -eq 0 ]; then
			dbg 2 "Removing installed files from footprint: ${FOOTPRINT}"
			pkg_remove ${CLFS_DIR} ${_FOOTPRINT}
			remove ${_FOOTPRINT}
			dbg 1 "${PKG_NAME} cross package uninstalled successfully"
			rm ${_FLOCK}
			exit 0
		fi
		rm ${_FLOCK}
		exit -1
	) 200>${_FLOCK}
}


remove_host() {
	# HOST PACKAGE
	_FOOTPRINT="${HOST_INSTALLDB}/${PKG_NAME}"
	_FLOCK="${HOST_INSTALLDB}/.${PKG_NAME}.lock"
	(
		flock -x 200
		get_package ${_FOOTPRINT}
		if [ $? -eq 0 ]; then
			dbg 2 "Removing installed files from footprint: ${FOOTPRINT}"
			pkg_remove ${TOOLCHAIN_DIR} ${_FOOTPRINT}
			remove ${_FOOTPRINT}
			dbg 1 "${PKG_NAME} host package uninstalled successfully"
			rm ${_FLOCK}
			exit 0
		fi
		rm ${_FLOCK}
		exit -1
	) 200>${_FLOCK}
}


main() {
	load_utils
	get_args "$@"

	check_file ${PKGMK_COMMONCONF}
	check_file ${PKGMK_CROSSCONF}
	check_file ${PKGMK_HOSTCONF}

	. ${PKGMK_COMMONCONF}
	. ${PKGMK_CROSSCONF}
	. ${PKGMK_HOSTCONF}

	if [ ${REMOVE_HOST} -eq 0 ]; then
		remove_cross
		if [ ${?} -eq 0 ]; then
			return
		fi
	else
		remove_host
		if [ ${?} -eq 0 ]; then
			return
		fi
	fi


	error "${PKG_NAME} is not installed"
}

TOOLS_BASEDIR=$(dirname $(readlink -e $0))
PKGMK_BASEDIR=$(dirname ${TOOLS_BASEDIR})

PKGMK_COMMONCONF="${PKGMK_BASEDIR}/config/common.conf"
PKGMK_CROSSCONF="${PKGMK_BASEDIR}/config/cross.conf"
PKGMK_HOSTCONF="${PKGMK_BASEDIR}/config/toolchain.conf"
REMOVE_HOST=0
FOOTPRINT=""
DBGLVL=2


main "$@"
