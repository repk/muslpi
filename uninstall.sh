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

check_file() {
	FILE=$1
	if [ ! -f ${FILE} ]; then
		error "File \"${FILE}\" does not exist"
	elif [  ! -r ${FILE} ]; then
		error "File \"${FILE}\" is not readable"
	else
		dbg 2 "File \"${FILE}\" is OK"
	fi
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

    check_file ${PKGMK_CROSSCONF}
    . ${PKGMK_CROSSCONF}

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
PKGMK_CROSSCONF="${PKGMK_BASEDIR}/config/cross.conf"
FOOTPRINT=""
DBGLVL=2


main "$@"
