# Backup to Google

#### Upload archived and encrypted file to google drive

#### Requirements
- `gdrive` installation: use to communicate with google drive 
    - links: https://github.com/gdrive-org/gdrive
- `jq` installation: command for parsing `json` file

- Sendgrid mail serivce account (key)

#### Setup
Run `setup.sh` script to setup program for use  
`DESTINATION` is the directory where the program will be

```bash
./setup.sh DESTINATION
```

#### Configuration
**`info.json`**  
config file will be created in destination derectory
- Modify it for each desired upload file/directory
- Each file/directory name should be in the format of `IDENTIFIER_DESCRIPTION` (underscore char is view as separator)

**`config.json`**  
config file will be created in destination directory
- Give information in the config file according to each configuration description


## Version 0.1.0
First release version
- Upload archived and encrypted file/directory to google drive
- Email notification after each process


## Usage
Run command after finish setting each configuration file

```bash
./backup_to_google.sh
```