#!/bin/sh
#
# strip.sh
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

main() {
	load_utils

	check_file ${PKGMK_COMMONCONF}
	check_file ${PKGMK_CROSSCONF}
	. ${PKGMK_COMMONCONF}
	. ${PKGMK_CROSSCONF}
	unset LD_LIBRARY_PATH

	for f in $(find ${CLFS_DIR} -type f -executable); do
		${FILEPROG} ${f} | grep -i "not stripped" >& /dev/null
		if [ ${?} -eq 0 ]; then
			${STRIP} --strip-debug ${f}
		fi
	done
}

TOOLS_BASEDIR=$(dirname $(readlink -e $0))
PKGMK_BASEDIR=$(dirname ${TOOLS_BASEDIR})
PKGMK_COMMONCONF="${PKGMK_BASEDIR}/config/common.conf"
PKGMK_CROSSCONF="${PKGMK_BASEDIR}/config/cross.conf"
FILEPROG=file
#Debug
DBGLVL=2

main "$@"
