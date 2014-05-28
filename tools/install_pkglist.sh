#!/bin/sh
#
#  install_pkglist.sh
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
#

load_utils() {
	. ${TOOLS_BASEDIR}/utils.sh
}


usage() {
	error "Usage: $(basename $0) [OPTION] <pkglist_file>\nOPTION\n\t-f: Force build event if footprint mismatches"
}

get_args() {
	if [ ${#} -eq 1 ]; then
		PKG_LIST_FILE=${1}
	elif [ ${#} -eq 2 ] && [ ${1} = "-f" ]; then
		PKG_BUILD_OPT="-f"
		PKG_LIST_FILE=${2}
	else
		usage
	fi
}

# This could go into utils.sh
get_pkg_tar() {
	PKGMK=$1
	HOST_PKG="" # Reset variable

	. ${PKGMK}
	if [ -z "${HOST_PKG}" ]; then
		PKG_TAR="$NAME-$VERSION-cross-pkg.tar.bz2"
	else
		PKG_TAR="$NAME-$VERSION-host-pkg.tar.bz2"
	fi

}

main() {
	load_utils
	get_args "$@"
	check_file ${PKG_LIST_FILE}

	check_file ${PKGMK_COMMONCONF}
	. ${PKGMK_COMMONCONF}

	. ${PKG_LIST_FILE}
	for pkg in ${PKGLIST}; do
		OLD=${PWD}
		check_dir ${PKGMK_BASEDIR}/${pkg}
		cd ${PKGMK_BASEDIR}/${pkg}

		${TOOLS_BASEDIR}/build.sh ${PKG_BUILD_OPT}
		if [ $? -ne 0 ]; then
			error "Fail to build package"
		fi

		get_pkg_tar "${PKGMK_BASEDIR}/${pkg}/PkgMk" # Get package tar name

		if [ -f ${PKG_TAR} ]; then
			${TOOLS_BASEDIR}/install.sh ${PKG_TAR}
		else
			error "${PKG_TAR} has not been succesfully built"
		fi
		cd ${OLD}
	done;
}


TOOLS_BASEDIR=$(dirname $(readlink -e $0))
PKGMK_BASEDIR=$(dirname ${TOOLS_BASEDIR})

PKGMK_COMMONCONF="${PKGMK_BASEDIR}/config/common.conf"
PKG_LIST_FILE=""
PKG_BUILD_OPT=""
PKG_TAR=""

#Debug
DBGLVL=2

main "$@"
