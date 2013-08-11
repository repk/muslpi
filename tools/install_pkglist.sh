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
	error "Usage: $(basename $0) <pkglist_file>"
}

get_args() {
	if [ ${#} -ne 1 ]; then
		usage
	fi
	PKG_LIST_FILE=${1}
}

main() {
	load_utils
	get_args "$@"
	check_file ${PKG_LIST_FILE}

	. ${PKG_LIST_FILE}
	for pkg in ${PKGLIST}; do
		OLD=${PWD}
		check_dir ${PKGMK_BASEDIR}/${pkg}
		cd ${PKGMK_BASEDIR}/${pkg}
		${TOOLS_BASEDIR}/build.sh
		if [ -f *-host-pkg.tar.bz2 ]; then
			${TOOLS_BASEDIR}/install.sh *-host-pkg.tar.bz2
		elif [ -f *-cross-pkg.tar.bz2 ]; then
			${TOOLS_BASEDIR}/install.sh *-cross-pkg.tar.bz2
		else
			error "No package has been succesfully built"
		fi
		cd ${OLD}
	done;
}


TOOLS_BASEDIR=$(dirname $(readlink -e $0))
PKGMK_BASEDIR=$(dirname ${TOOLS_BASEDIR})

PKG_LIST_FILE=""

#Debug
DBGLVL=2

main "$@"
