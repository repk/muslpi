#!/bin/sh
#
# utils.sh
# Common utilities
#
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


# Print error message
error() {
	echo -e "ERROR : $1" >&2
	exit -1
}


# Print debug message depending on DBGLVL variable
dbg() {
	if [ -z "${DBGLVL}" ]; then
		return
	elif [ ${DBGLVL} -ge $1 ]; then
		echo "$2"
	fi
}


# Check if directory exists
check_dir() {
	DIR=$1
	if [ ! -d ${DIR} ]; then
		error "Directory \"${DIR}\" does not exist"
	elif [ ! -x ${DIR} ]  && [ ! -r ${DIR} ]; then
		error "Directory \"${DIR}\" is not readable"
	elif [ ! -w ${DIR} ]; then
		error "Directory \"${DIR}\" is not writable"
	else
		dbg 2 "Directory : \"${DIR}\" is OK"
	fi
}


# Check if file exists
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

compute_footprint() {
	FILE=$1
	bsdtar -tvf ${FILE} | tr -s ' ' | cut -d' ' -f1,9 | sort -k 2 | sed "s/^h/-/g"
}
