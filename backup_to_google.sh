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
_complete_dir=$(jq -r '."general-config"."completed"' ./config.json)

_gdrive_config=$(jq -r '."gdrive-config"."config"' ./config.json)
_gdrive_parent=$(jq -r '."gdrive-config"."parent"' ./config.json)

# Create config file for archive_encrypt dependency script
_ae_destination_dir=$(jq -r '."archive-encrypt-config"."destination-dir"' ./config.json)
_ae_encrypt_method=$(jq -r '."archive-encrypt-config"."encrypt-method"' ./config.json)
_ae_passphrase_file=$(jq -r '."archive-encrypt-config"."passphrase-file"' ./config.json)
_ae_passphrase=$(jq -r '."archive-encrypt-config"."passphrase"' ./config.json)


cat <<EOF > archive_encrypt.conf
_DESTINATION_DIR=${_ae_destination_dir}
_ENCRYPT_METHOD=${_ae_encrypt_method}
_PASSPHRASE_FILE=${_ae_passphrase_file}
EOF

cat <<EOF > ${_ae_passphrase_file}
${_ae_passphrase}
EOF

# Archive, Encrypt, and Upload
# cd ${_source_dir}
for _list_data in $(ls ${_source_dir}); do
    _source_data=${_source_dir}/${_list_data}
    echo "${_source_data} in progress..."
    if [[ -f "${_source_data}" ]]; then
        chmod 644 ${_source_data}
    elif [[ -d "${_source_data}" ]]; then
        chmod -R 644 ${_source_data}/*
        chmod 755 ${_source_data}
    fi

    _id=$(echo "${_list_data}" | cut -d _ -f1)
    _info_block=$(jq -r --arg _ID "${_id}" '.[$_ID]' ${_INFO_FILE})
    echo "Current path: $(pwd)"
    if [[ ${_info_block} == "null" ]]; then
        echo "info file for ${_list_data} is not set"
        continue
    else
        _filename=$(echo "${_info_block}" | jq -r '."filename"')
        _description=$(echo "${_info_block}" | jq -r '."description"')
        echo "Filename: ${_filename}"
        echo "Description: ${_description}"
    fi

    echo ""
    ./lib/${_ARCHIVE_ENCRYPT} ${_filename} ${_source_dir}/${_list_data}
    echo ""

    echo "Uploading..."
    cd ${_ae_destination_dir}
    _output_filename=$(echo "${_info_block}" | jq -r '."output-filename"')
    gdrive --config ${_gdrive_config} upload --parent ${_gdrive_parent} ${_output_filename}
    cd -
    echo "Upload done."

    # Moving and removing file
    echo ""
    echo "${_source_data} moving to ${_complete_dir}..."
    mv ${_source_data} ${_complete_dir}
    echo "Moved successed."

    echo ""
    echo "Removing encrypted file ${_output_filename} in ${_ae_destination_dir}..."
    cd ${_ae_destination_dir}
    rm ${_output_filename}
    cd -
    echo "Remove successed."

    # Change info uploaded status
    cp ./info.json ./.info.json.bkp
    jq --arg _ID "${_id}" '.[$_ID]."uploaded" = "true"' ./info.json > ./.info.json.tmp
    mv ./.info.json.tmp ./info.json

    # Clean up
    rm  archive_encrypt.conf ${_ae_passphrase_file}

    echo ""
    echo "${_list_data} progress done."
done

