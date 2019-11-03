#!/bin/bash
#
# Program:
#   backup_to_google setup script
#
# Exit Code:
#   1 - Calling syntax error
#   3 - Destination directory does not exist
#
#   11 - Copy file failed
#   13 - Change file permission failed


# ============================
# Check exit code function
# USAGE:
#   checkCode EXITCODE MESSAGE
# ============================
function checkCode() {
  if [[ ${?} -ne 0 ]]; then
    echo ${2}
    exit ${1}
  fi
}

# ===========================
# Usage: Installation DESTDIR 
# ===========================
function Installation() {
    DESTDIR=${1}

    # Setup process
    cp -r lib ${DESTDIR}
    checkCode 11 "Copy lib failed." &> /dev/null    
    cp README.md ${DESTDIR}
    checkCode 11 "Copy README.md failed." &> /dev/null
    cp backup_to_google.sh ${DESTDIR}
    checkCode 11 "Copy archive_encrypt.sh failed."  &> /dev/null
    chmod 755 ${DESTDIR}/backup_to_google.sh
    checkCode 13 "Change file permission failed."   &> /dev/null
    chmod 755 ${DESTDIR}/lib/archive_encrypt_v0.1.1.sh
    checkCode 13 "Change file permission failed."   &> /dev/null

    if [[ ! -f ${DESTDIR}/config.json ]]; then
        cp heyhey-config-template.json ${DESTDIR}/config.json
        checkCode 11 "Copy heyhey-config-template.json failed."  &> /dev/null
        chmod 600 ${DESTDIR}/config.json
        checkCode 13 "Change config.json permission failed."
    fi

    if [[ ! -f ${DESTDIR}/info.json ]]; then
        cp heyhey-info-template.json ${DESTDIR}/info.json
        checkCode 11 "Copy heyhey-info-template.json failed."  &> /dev/null
        chmod 644 ${DESTDIR}/info.json
        checkCode 13 "Change info.json permission failed."
    fi
}


# Calling setup format check
USAGE="setup.sh DESTINATION"

if [[ "${#}" -ne 1 ]];  then
    echo -e "USAGE:\n    ${USAGE}"
    exit 1
fi

if [[ ! -d ${1} ]]; then
    echo "ERROR: Destination directory does not exist"
    exit 3
fi


# System checking
SYSTEM_RELEASE=$(uname -a)
case ${SYSTEM_RELEASE} in
  *Linux*)
    echo "Linux detected"
    echo ""
    Installation ${1}
    ;;
  *)
    echo "System not supported."
    exit 1
esac


echo "backup_to_google setup success."
exit 0