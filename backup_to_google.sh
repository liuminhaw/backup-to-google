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
# Version: 0.1.1

# ----------------------------------------------------------------------------
# Function definition
#
# Usage: show_help
# ----------------------------------------------------------------------------
show_help() {
cat << EOF
Usage: ${0##*/} [--help] [--no-backup]

    --help                  Display this help message and exit
    --no-backup             Disable backup source data after uploaded
    --version               Show version information
EOF
}

# ----------------------------------------------------------------------------
# Function definition
#
# Usage: send_mail mail_content
# content can be written in html format
# ----------------------------------------------------------------------------
sendgrid_mail() {
    _sendgrid_key=$(jq -r '."sendgrid-config"."key"' ./config.json)
    _sendgrid_sender=$(jq -r '."sendgrid-config"."sender"' ./config.json)
    _sendgrid_recipient=$(jq -r '."sendgrid-config"."recipient"' ./config.json)
    _sendgrid_name=$(jq -r '."sendgrid-config"."name"' ./config.json)
    _sendgrid_subject=$(jq -r '."sendgrid-config"."subject"' ./config.json)

    _mail_content=${1}

    _mail_data='{"personalizations": [{"to": [{"email": "'${_sendgrid_recipient}'"}]}],
        "from": {"email": "'${_sendgrid_sender}'", 
        "name": "'${_sendgrid_name}'"},
        "subject": "'${_sendgrid_subject}'",
        "content": [{"type": "text/html", "value": "'${_mail_content}'"}]}'

    curl --request POST \
    --url https://api.sendgrid.com/v3/mail/send \
    --header 'Authorization: Bearer '$_sendgrid_key \
    --header 'Content-Type: application/json' \
    --data "'$_mail_data'"
}


# Environment variables
_VERSION="Version 0.1.1"
_SCRIPT=$(basename ${0})
_CONFIG_FILE=./config.json
_INFO_FILE=./info.json
_ARCHIVE_ENCRYPT=archive_encrypt_v0.1.1.sh

# --------------------
# Command line options
# --------------------
while :; do
    case ${1} in 
        --version)
            echo "${_VERSION}"
            exit
            ;;
        --help)
            show_help
            exit
            ;;
        --no-backup)
            _no_backup="true"
            ;;
        -?*)
            echo "WARN: Unknown option (ignored): ${1}" 1>&2
            ;;
        *) # Default case: no more options
            break
    esac
    shift
done

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

# gdrive command
which gdrive 1> /dev/null
if [[ "${?}" -ne 0 ]]; then
    echo "No such command: gdrive"
    exit 3
fi

# Variable declaration
_source_dir=$(jq -r '."general-config"."source"' ./config.json)
_complete_dir=$(jq -r '."general-config"."completed"' ./config.json)
_backup_dir=$(jq -r '."general-config"."backup"' ./config.json)

_gdrive_config=$(jq -r '."gdrive-config"."config"' ./config.json)
_gdrive_parent=$(jq -r '."gdrive-config"."parent"' ./config.json)
_gdrive_info_id=$(jq -r '."gdrive-config"."info-id"' ./config.json)

# Create config file for archive_encrypt dependency script
_ae_destination_dir=$(jq -r '."archive-encrypt-config"."destination-dir"' ./config.json)
_ae_encrypt_method=$(jq -r '."archive-encrypt-config"."encrypt-method"' ./config.json)
_ae_passphrase_file=$(jq -r '."archive-encrypt-config"."passphrase-file"' ./config.json)
_ae_passphrase=$(jq -r '."archive-encrypt-config"."passphrase"' ./config.json)

# Test configuration directories / files
if [[ ! -d "${_source_dir}" ]]; then
    echo "Info: ${_source_dir} directory not exist"
    exit 4
fi

if [[ ! -d "${_complete_dir}" ]]; then
    echo "Info: ${_complete_dir} directory not exist"
    exit 4
fi

if [[ ! -d "${_backup_dir}" ]]; then
    echo "Info: ${_backup_dir} directory not exist"
    exit 4
fi

if [[ ! -d "${_ae_destination_dir}" ]]; then
    echo "Info: ${_ae_destination_dir} directory not exist"
    exit 4
fi

if [[ ! -e "${_gdrive_config}" ]]; then
    echo "Info: ${_gdrive_config} file not exist"
    exit 2
fi


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
_iter=0
for _list_data in $(ls ${_source_dir}); do
    _summary[${_iter}]=${_list_data}

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
        _uploaded=$(echo "${_info_block}" | jq -r '."uploaded"')
        echo "Filename: ${_filename}"
        echo "Description: ${_description}"
        echo "Uploaded: ${_uploaded}"
    fi

    # Cancel upload process if uploaded is true
    if [[ "${_uploaded}" != false ]]; then
        echo ""
        echo "Uploaded not equal to 'fales' detection"
        continue
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

    # Backup to backup directory 
    if [[ "${_no_backup}" != "true" ]]; then
        echo ""
        echo "Backup ${_source_data} to ${_backup_dir}..."
        cp -r ${_source_data} ${_backup_dir}
        echo "Backup succeed"
    fi

    # Moving to complete directory
    echo ""
    echo "Copy ${_source_data} to ${_complete_dir}..."
    cp -r ${_source_data} ${_complete_dir}
    if [[ ${?} -eq 0 ]]; then
        echo "Remove ${_source_data}..."
        rm -rf ${_source_data}
        echo "Moving ${_source_data} to ${_complete_dir} successed"
    else
        echo "Failed to move ${_source_data} to ${_complete_dir}"
    fi

    # Remove encrypted file
    echo ""
    echo "Removing encrypted file ${_output_filename} in ${_ae_destination_dir}..."
    cd ${_ae_destination_dir}
    rm ${_output_filename}
    cd -
    echo "Remove successed."

    # Change info uploaded status
    cp ./info.json ./.info.json.bkp
    jq --arg _ID "${_id}" '.[$_ID]."uploaded" = true' ./info.json > ./.info.json.tmp
    mv ./.info.json.tmp ./info.json

    echo ""
    echo "${_list_data} progress done."

    # Send notification mail
    echo ""
    echo "Sending notification..."
    _mail_content="<p>File: ${_output_filename} upload success</p><p>Origin filename: ${_list_data}</p>"

    sendgrid_mail "${_mail_content}"
    echo "Notification sent."

    _iter=$((${_iter} + 1))
done

# Clean up
rm  archive_encrypt.conf ${_ae_passphrase_file}

# Stop process if noting is uploaded
if [[ "${_iter}" == 0 ]]; then
    echo ""
    echo "No file has been uploaded."

    # Send notification mail
    echo ""
    echo "Sending notification..."
    _mail_content="<p>No file has been uploaded</p>"
    sendgrid_mail "${_mail_content}"
    exit 0
fi

# info upload
echo ""
echo "Uploading info file..."
_output_filename="info.json"
gdrive --config ${_gdrive_config} update ${_gdrive_info_id} ${_output_filename}
echo "info file upload success"

# Send summary mail
echo ""
echo "Sending summary notification..."
# _mail_content="<p>File: ${_output_filename} upload success</p><p>Origin filename: ${_list_data}</p>"
_mail_content="<h2>Backup to Google summary: HeyHey</h2>"
for _list_data in ${_summary[@]}; do
    _mail_content="${_mail_content}<p>${_list_data}</p>"
done
_mail_content="${_mail_content}<hr><p>info.json</p>"

sendgrid_mail "${_mail_content}"
echo "Summary notification sent."
