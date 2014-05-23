#!/bin/sh
#
#  build.sh
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
	error "Usage: $(basename $0) [OPTION]\nOPTION\n\t-f: Force build event if footprint mismatches"
}


get_args() {
	if [ ${#} -ne 0 ] && [ ${1} != "-f" ]; then
		usage
	elif [ ${#} -ne 0 ]; then
		FORCE=1
	fi
}

check_md5file() {
	if [ ! -f ${PKG_MD5} ]; then
		dbg 1 "MD5 file does not exist one will be created"
		PKG_NO_MD5=1
	elif [  ! -r ${PKG_MD5} ]; then
		error "MDE file (\"$PKG_MD5}\") is not readable"
	fi
}


check_footprintfile() {
	if [ ! -f ${PKG_FOOTPRINT} ]; then
		dbg 1 "Footprint file does not exist one will be created"
		PKG_NO_FOOTPRINT=1
	elif [  ! -r ${PKG_FOOTPRINT} ]; then
		error "MDE file (\"$PKG_FOOTPRINT}\") is not readable"
	fi
}


clean_work() {
	rm -rf ${WORK_DIR}
}


prepare_work() {
	cd ${PKG_ROOT}
	clean_work

	mkdir -p ${SRC} ${PKG}
}


read_pkgmk() {
	. ${PKG_MKFILE}
	if [ -z "${HOST_PKG}" ]; then
		PKG_TAR="$NAME-$VERSION-cross-pkg.tar.bz2"
	else
		PKG_TAR="$NAME-$VERSION-host-pkg.tar.bz2"
	fi

}

prepare_env() {
	check_file ${PKGMK_COMMONCONF}
	. ${PKGMK_COMMONCONF}
	if [ -z "${HOST_PKG}" ]; then
		check_file ${PKGMK_CROSSCONF}
		. ${PKGMK_CROSSCONF}
	else
		check_file ${PKGMK_HOSTCONF}
		. ${PKGMK_HOSTCONF}
	fi

}

add_source() {
	PKG_SOURCE="${PKG_SOURCE} $1"
}


http_handler_filename() {
	echo $(basename ${1})
}


http_handler_dl() {
	URL=$1
	FILE=$2

	WGET_RESUME=""
	WGET_OPT="--no-check-certificate -O ${FILE}.partial"

	if [ -f ${FILE} ]; then
		dbg 2 "${src} already downloaded"
		return
	fi

	if [ -f "${FILE}.partial" ]; then
		dbg 2 "Partial file present. Trying to resume"
		WGET_RESUME="-c"
	fi

	wget ${WGET_RESUME} ${WGET_OPT} ${URL}

	if [ ! $? -eq 0 ]; then
		error "Fail to download ${FILE}"
	fi

	mv "${FILE}.partial" "${FILE}"
}


check_md5() {
	FILE=$1
	COMPUTED_MD5=$(md5sum ${FILE})

	if [ -n "${PKG_NO_MD5}" ]; then
		echo "${COMPUTED_MD5}" >> ${PKG_MD5}
		return
	fi

	EXPECTED_MD5=$(egrep "${FILE}$" ${PKG_MD5})
	if [ -z "${EXPECTED_MD5}" ]; then
		error "${FILE} missing from ${PKG_MD5}"
	elif [ "${COMPUTED_MD5}" != "${EXPECTED_MD5}" ]; then
		error "MD5 mismatch for ${FILE} :
			Having : ${COMPUTED_MD5}
			but Expected : ${EXPECTED_MD5}"
	else
		dbg 2 "MD5 matches for ${FILE}"
	fi
}


extract_src() {
	FILE=$1

	# TODO check file ?

	case ${FILE} in
	*.tar.gz)
		dbg 2 "Untar gz file ${FILE}"
		tar -xzf ${PKG_ROOT}/${FILE}
		;;
	*.tar.xz)
		dbg 2 "Untar xz file ${FILE}"
		tar -xJf ${PKG_ROOT}/${FILE}
		;;
	*.tar.bz2)
		dbg 2 "Untar bzip2 file ${FILE}"
		tar -xjf ${PKG_ROOT}/${FILE}
		;;
	*)
		dbg 2 "Raw copy file ${FILE}"
		cp ${PKG_ROOT}/${FILE} .
		;;
	esac
}


fetch_src() {
	for src in ${SOURCES}; do
		case $src in
		http://*)
			dbg 2 "Fetch ${src} with http handler"
			SRC_FILENAME=$(http_handler_filename ${src})
			http_handler_dl ${src} ${SRC_FILENAME}
			;;
		https://*)
			dbg 2 "Fetch ${src} with https handler"
			SRC_FILENAME=$(http_handler_filename ${src})
			http_handler_dl ${src} ${SRC_FILENAME}
			;;
		ftp://*)
			dbg 2 "Fetch ${src} with ftp handler"
			SRC_FILENAME=$(http_handler_filename ${src})
			http_handler_dl ${src} ${SRC_FILENAME}
			;;
		*)
			error "No handler to fetch ${src}"
			;;
		esac

		check_md5 ${SRC_FILENAME}
		add_source ${SRC_FILENAME}
	done
}


process_patches() {
	for patch in ${PATCHES}; do
		check_file ${PKG_ROOT}/${patch}
		dbg 2 "Patching file ${patch}"
		patch -p1 < ${PKG_ROOT}/${patch}
		if [ ${?} -ne 0 ]; then
			error "Cannot apply patch"
		fi
	done
}


copy_files() {
	for f in ${FILES}; do
		check_file ${PKG_ROOT}/${f}
		dbg 2 "Additional file ${f}"
		cp ${PKG_ROOT}/${f} .
	done
}

fix_temporary_libtool_files() {
	files=$(find . -name "*.la" -printf "%T@ %p\n" | sort -n | cut -d ' ' -f 2)
	for f in ${files}; do
		tmp=/tmp/$(basename ${f})_old
		cp ${f} ${tmp}
		sed "s#libdir='/usr/lib'#libdir='${PKG}/usr/lib'#g" ${tmp} > $f
		rm ${tmp}
	done
}


prepare_src() {
	cd ${SRC}
	for f in ${PKG_SOURCE}; do
		extract_src ${f}
	done
}


makepkg() {
	cd ${PKG}

	# Remove libtool files
	find . -name "*.la" -delete
	# Remove GNU info files
	if [ -d share/info ]; then
		rm -rf share/info
	fi
	if [ -d usr/share/info ]; then
		rm -rf usr/share/info
	fi

	# Remove doc uneeded files
	if [ -d share/doc ]; then
		rm -rf share/doc
	fi
	if [ -d usr/share/doc ]; then
		rm -rf usr/share/doc
	fi

	# Remove gtk-doc more uneeded files
	if [ -d usr/share/gtk-doc ]; then
		rm -rf usr/share/gtk-doc
	fi

	if [ -d usr/man ]; then
		if [ ! -d usr/share ]; then
			mkdir usr/share
		fi
		mv usr/{,share/}man
	fi


	bsdtar -cjf ${PKG_TAR} *
	if [ $? -ne 0 ]; then
		error "Failed to make package"
	fi
	mv  ${PKG_TAR} "${PKG_ROOT}/"
	cd ${PKG_ROOT}
}

patch_unknown_target() {
	_F=${1}
	check_file ${_F}
	sed -i "s/linux-uclibc/${CLFS_TARGET_TOKEN}/g" ${_F}
}

check_footprint() {
	if [ ${FORCE} -eq 1 ]; then
		return
	fi
	COMPUTED_FOOTPRINT=$(compute_footprint ${PKG_TAR})

	if [ -n "${PKG_NO_FOOTPRINT}" ]; then
		echo "${COMPUTED_FOOTPRINT}" >> ${PKG_FOOTPRINT}
		return
	fi

	DIFF=$(echo "${COMPUTED_FOOTPRINT}" | diff -u ${PKG_FOOTPRINT} -)
	if [ $? -ne 0 ]; then
		error "Footprint mismatch:\n${DIFF}"
	fi
}


main() {
	load_utils

	get_args "${@}"
	dbg 1 "Package build started"

	#Check files
	check_file ${PKG_MKFILE}
	check_md5file
	check_footprintfile

	#Prepare directories needed to build package
	prepare_work

	#Read the PkgMk file
	read_pkgmk

	#Prepare env
	prepare_env

	#Fetch sources
	fetch_src

	prepare_src

	#call PkgMk
	pkgmain
	if [ $? -ne 0 ]; then
		error "Package build error"
	fi

	#get pkg
	makepkg

	#check footprint
	check_footprint

	clean_work
	dbg 1 "Package build succeed"
}


TOOLS_BASEDIR=$(dirname $(readlink -e $0))
PKGMK_BASEDIR=$(dirname ${TOOLS_BASEDIR})

#Important files
PKGMK_COMMONCONF="${PKGMK_BASEDIR}/config/common.conf"
PKGMK_CROSSCONF="${PKGMK_BASEDIR}/config/cross.conf"
PKGMK_HOSTCONF="${PKGMK_BASEDIR}/config/toolchain.conf"
PKG_MKFILE="${PWD}/PkgMk"
PKG_FOOTPRINT=".footprint"
PKG_MD5=".md5"
PKG_PATCHES=".patches"
PKG_TAR=""

#Build files
PKG_ROOT="${PWD}"
WORK_DIR="${PKG_ROOT}/work"
PKG="${WORK_DIR}/pkg"
SRC="${WORK_DIR}/src"

#Opt
PKG_NO_MD5=""
PKG_NO_FOOTPRINT=""

PKG_SOURCES=""
FORCE=0

#Debug
DBGLVL=2

main "$@"
