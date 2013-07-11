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
	error "Usage: $(basename $0) <pkgfile>"
}


get_args() {
	if [ ${#} -ne 1 ]; then
		usage
	fi
	PKG_FILE=${1}
}


host_main() {
	echo super
}


install_pkg() {
	_INSTALL_DIR=$1
	_OLD=${PWD}

	cd ${_INSTALL_DIR}
	tar -xjf ${PKG_ROOT}/${PKG_FILE}
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
	cat ${PKG_FOOTPRINT} >> ${FOOTPRINT_FILE}
}


prepare_cross_install() {
	if [ ! -d ${CLFS_DIR} ]; then
		dbg 2 "Create clfs dir at ${CLFS_DIR}"
		mkdir -p ${CLFS_DIR}
	fi
	if [ ! -d ${CROSS_INSTALLDB} ]; then
		dbg 2 "Create cross package db at ${CROSS_INSTALLDB}"
		mkdir -p ${CROSS_INSTALLDB}
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


main() {
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


PKGMK_BASEDIR=$(dirname $0)
PKG_ROOT=${PWD}
PKG_FOOTPRINT="${PKG_ROOT}/.footprint"
PKG_FILE=""
CLFS_DIR="${PKGMK_BASEDIR}/clfs"
CROSS_INSTALLDB="${PKGMK_BASEDIR}/.installdb/cross_pkg/"
DBGLVL=2

main "$@"
