#!/bin/bash

# Program:
#   backup_to_google.sh
# Author:
#   haw
# Usage:
#   Upload archived and envrypted data to google drive for backup
#
# Dependencies: 
#
# Notes:
#
# Exit Code:
#   2 - Required settings file not found
#   3 - Missing command
#   4 - info data not set
#
# Version: 

#--------------------
# Function definition
# 
# Usage: 
# Return:
#---------------------


# Environment variables
_CONFIG_FILE=./config.json
_INFO_FILE=./info.json
_ARCHIVE_ENCRYPT=archive_encrypt_v0.1.1.sh

# --------------------
# Requirements testing
# --------------------

# Config file
if [[ ! -f "${_CONFIG_FILE}" ]]; then
    echo "Info: ${_CONFIG_FILE} file for configuration not found"
    exit 2
fi

# Info file
if [[ ! -f "${_INFO_FILE}" ]]; then
    echo "Info: ${_INFO_FILE} file not found"
    exit 2
fi

# jq command
which jq 1> /dev/null
if [[ "${?}" -ne 0 ]]; then
    echo "No such command: jq"
    exit 3
fi

# Variable declaration
_source_dir=$(jq -r '."general-config"."source"' ./config.json)

_gdrive_config=$(jq -r '."gdrive-config"."config"' ./config.json)
_gdrive_parent=$(jq -r '."gdrive-config"."parent"' config.json)

# Create config file for archive_encrypt dependency script
_ae_destination_dir=$(jq -r '."archive-encrypt-config"."destination-dir"' ./config.json)
_ae_encrypt_method=$(jq -r '."archive-encrypt-config"."encrypt-method"' ./config.json)
_ae_passphrase_file=$(jq -r '."archive-encrypt-config"."passphrase-file"' ./config.json)
_ae_passphrase=$(jq -r '."archive-encrypt-config"."passphrase"' ./config.json)


cat <<EOF > archive_encrypt.conf
_DESTINATION_DIR=${_ae_destination_dir}
_ENCRYPT_METHOD=${_ae_encrypt_method}
_PASSPHRASE_FILE=.passphrase_heyhey=${_ae_passphrase_file}
EOF

cat <<EOF > ${_ae_passphrase_file}
${_ae_passphrase}
EOF

# Archive, Encrypt, and Upload
cd ${_source_dir}
for _list_data in $(ls); do
    echo "${_list_data} in progress..."
    if [[ -f "${_list_data}" ]]; then
        chmod 644 ${_list_data}
    elif [[ -d "${_list_data}" ]]; then
        chmod -R 644 ${_list_data}/*
        chmod 755 ${_list_data}
    fi

    _id=$(echo "${_list_data}" | cut -d _ -f1)
    _info_block=$(jq -r '."${_id}"' ${_INFO_FILE})
    if [[ ${_info_block} == "null" ]]; then
        echo "info file for ${_list_data} is not set"
        exit 4
    else
        _filename=$(echo "${_info_block}" | jq -r '."filename"')
        _description=$(echo "${_info_block}" | jq -r '."description"')
        echo "Filename: ${_filename}"
        echo "Description: ${_description}"
    fi

    cd -
    ./lib/${_ARCHIVE_ENCRYPT} ${_filename} ${_source_dir}/${_list_data}

    echo "Uploading..."
    cd ${_ae_destination_dir}
    _output_filename=$(echo "${_info_block}" | jq -r '."output-filename"')
    gdrive --config ${_gdrive_config} --parent ${_gdrive_parent} ${_output_filename}
    cd -
    echo "Upload done"

    # TODOs: Moving file and removing file
done

