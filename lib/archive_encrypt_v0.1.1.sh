#!/bin/bash

# Program:
#   Archives and encrypt target path for further use
# Author:
#   haw
#
# Usage:
#   archive_encrypt.sh OUTPUT_FILENAME SOURCE
#
# Notes:
#   - Use tar command for archive and compress
#   - Use gpg command for encryption
#
# Exit code:
#   1 - Usage error
#   2 - Config file not found
#   3 - Missing command
#   4 - Config file environment error
#   5 - Source not found
#
# Version: 0.1.1


# ----------------------------------------------------------------------------
# Function definition
#
# Usage: random_password PASSWORD_LENTGH [CHARACTER_SET]
# Return:
#   11 - usage error
# ----------------------------------------------------------------------------
random_password() {
    if [[ "${#}" -ne 1 && "${#}" -ne 2 ]]; then
        echo "Usage: random_password PASSWORD_LENGTH [CHARACTER_SET]"
        exit 11
    fi

    _length=${1}
    if [[ "${#}" -eq 2 ]]; then
        _character_set="${2}"
    else
        _character_set='a-zA-Z0-9!@#$%^&*()_+'
    fi

    echo $(cat /dev/urandom | tr -dc ${_character_set} | fold -w ${_length} | head -n 1)
}



# Environment variables
_SCRIPT=$(basename ${0})
_CONFIG_FILE=./archive_encrypt.conf

# --------------------
# Requirements testing
# --------------------

# Config file
if [[ ! -f "${_CONFIG_FILE}" ]]; then
    echo "Info: ${_CONFIG_FILE} file for configuration not found"
    exit 2
fi
source ${_CONFIG_FILE}

# tar command
which tar 1> /dev/null
if [[ "${?}" -ne 0 ]]; then
    echo "No such command: tar"
    exit 3
fi
# gpg command
which gpg 1> /dev/null
if [[ "${?}" -ne 0 ]]; then
    echo "No such command: gpg"
    exit 3
fi

# Destination directory
if [[ -z "${_DESTINATION_DIR}" || ! -d "${_DESTINATION_DIR}" ]]; then
    echo "Info: Config _DESTINATION_DIR no value or not exist"
    exit 4
fi

# Passphrase file 
# Generate random passphrase if no passphrase commited
if [[ -z "${_PASSPHRASE_FILE}" || ! -f "${_PASSPHRASE_FILE}" ]]; then
    _passphrase=$(random_password 17)
fi

# Check encrypt method
shopt -s nocasematch
if [[ "${_ENCRYPT_METHOD}" == "bzip2" ]]; then
    _tar_option='-jcf'
elif [[ "${_ENCRYPT_METHOD}" == "xz" ]]; then
    _tar_option='-Jcf'
else 
    _tar_option='-zcf'
fi


if [[ "${#}" -ne 2 ]]; then
    echo "USAGE: ${_SCRIPT} OUTPUT_FILENAME SOURCE"
    exit 1
fi
_output_filename=${1}
_output_fullpath=${_DESTINATION_DIR}/${_output_filename}
_source=${2}
_source_dir=$(dirname ${_source})
_source_base=$(basename ${_source})

# Source directory/file
if [[ -e "${source}" ]]; then
    echo "Info: Source ${_source} does not exist"
    exit 5
fi

# Avoid gpg encryption file duplicates
if [[ -f "${_output_fullpath}.gpg" ]]; then
    rm ${_output_fullpath}.gpg
fi

# Archive and encrypt
echo "Archiving..."
cd ${_source_dir}
tar ${_tar_option} ${_output_fullpath} ${_source_base}
cd -

echo "Encrypting..."
if [[ -z "${_passphrase}" ]]; then
    gpg -c --batch --passphrase-file ${_PASSPHRASE_FILE} ${_output_fullpath}
else
    gpg -c --batch --passphrase "${_passphrase}" ${_output_fullpath}
    echo
    echo "Passphrase: ${_passphrase}"
fi
rm ${_output_fullpath}

echo
echo "Archive and encrypt done"