#!/bin/sh
#
#  send2target.sh
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
	error "Usage: $(basename $0) TARGET_DIR [PKG]...\nPKG:\n\t-p pkg: Send package by name\n\t-l pkglist: Send packages from list"
}

get_args() {
	if [ ${#} -le 1 ]; then
		usage
	else
		TARGET_DIR=${1}
		shift 1
	fi

	while [ ${#} -ge 1 ]; do
		if [ "${1}" == "-l" ]; then
			if [ ${#} -le 1 ]; then
				usage
			fi
			PKGLIST_FILE="${PKGLIST_FILE} ${2}"
		elif [ "${1}" == "-p" ]; then
			if [ ${#} -le 1 ]; then
				usage
			fi
			PKGS="${PKGS} ${2}"
		else
			usage
		fi
		shift 2
	done

	if [ "${PKGS}" == "" ] || [ "${PKGLIST_FILE}" == "" ]; then
		usage
	fi
}

get_package() {
	_FOOTPRINT=${1}
	if [ -f ${_FOOTPRINT} ]; then
		return 0
	fi
	return 1
}

send2target() {
	PKG_NAME=${1}
	_FOOTPRINT="${CROSS_INSTALLDB}/${PKG_NAME}"

	dbg 2 "Installing ${PKG_NAME}"

	get_package ${_FOOTPRINT}
	if [ $? -ne 0 ]; then
		dbg 1 "Package ${PKG_NAME} is not installed"
		return
	fi

	FILE_LIST=$(cat ${_FOOTPRINT} | grep -v -e "^PACKAGE_" |
			awk '{ print length(), $2 | "sort -n"}' |
			cut -d' ' -f2)

	for F in ${FILE_LIST}; do
		if [ -d ${CLFS_DIR}/${F} ]; then
			mkdir -p ${TARGET_DIR}/${F}
		elif [ -e ${CLFS_DIR}/${F} ] || [ -h ${CLFS_DIR}/${F} ]; then
			cp -a ${CLFS_DIR}/${F} ${TARGET_DIR}/${F}
			chown -h 0:0 ${TARGET_DIR}/${F}
		else
			dbg 2 "${F} is in ${PKG_NAME} but not in clfs install dir"
			continue
		fi
		chmod -f $(stat -c '%a' ${CLFS_DIR}/${F}) ${TARGET_DIR}/${F}
	done
}

main() {
	load_utils
	get_args "${@}"

	check_file ${PKGMK_COMMONCONF}
	check_file ${PKGMK_CROSSCONF}
	check_file ${PKGMK_HOSTCONF}

	. ${PKGMK_COMMONCONF}
	. ${PKGMK_CROSSCONF}
	. ${PKGMK_HOSTCONF}

	check_dir ${TARGET_DIR}

	for file in ${PKGLIST_FILE}; do

		check_file ${file}
		. ${file}

		for pkg in ${PKGLIST}; do
			send2target $(basename ${pkg})
		done
	done

	for pkg in ${PKGS}; do
		send2target ${pkg}
	done
}

TOOLS_BASEDIR=$(dirname $(readlink -e $0))
PKGMK_BASEDIR=$(dirname ${TOOLS_BASEDIR})

PKGMK_COMMONCONF="${PKGMK_BASEDIR}/config/common.conf"
PKGMK_CROSSCONF="${PKGMK_BASEDIR}/config/cross.conf"
PKGMK_HOSTCONF="${PKGMK_BASEDIR}/config/toolchain.conf"
PKGLIST_FILE=""
PKGLIST=""
PKGS=""
DBGLVL=2

main "$@"
