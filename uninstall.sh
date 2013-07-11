#!/bin/sh

error() {
	echo -e "ERROR : $1" >&2
	exit -1
}


dbg() {
	if [ -z "${DBGLVL}" ]; then
		return
	elif [ ${DBGLVL} -ge $1 ]; then
		echo "$2"
	fi
}


usage() {
	error "Usage: $(basename $0) <pkg>"
}


get_args() {
	if [ ${#} -ne 1 ]; then
		usage
	fi
	PKG_NAME=$1
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


main() {
	get_args "$@"


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
			dbg 1 "${PKG_NAME} uninstalled successfully"
			rm ${_FLOCK}
			exit 0
		fi
		rm ${_FLOCK}
		exit -1
	) 200>${_FLOCK}

	if [ ${?} -eq 0 ]; then
		return
	fi

	error "${PKG_NAME} is not installed"
}


PKGMK_BASEDIR=$(dirname $0)
CLFS_DIR="${PKGMK_BASEDIR}/clfs"
CROSS_INSTALLDB="${PKGMK_BASEDIR}/.installdb/cross_pkg/"
FOOTPRINT=""
DBGLVL=2


main "$@"
