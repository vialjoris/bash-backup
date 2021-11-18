#!/bin/bash
# ./backup_clients.sh -s source_in_ssh_config -d backup_dir_path -o www_data -e file_exclude_path

set -o errexit
set -o nounset
set -o pipefail

GREEN="\\033[1;32m"
RED="\\033[1;31m"
COLOR_OFF="\\033[0;39m"

function usage() {
    echo -e ${GREEN}" usage:${COLOR_OFF} ./backup_clients.sh  [-s <source_in_ssh_config>] [-d <backup_dir_path>] [-o <www_data|mysql_backup|mongodb_backup|metabase_data|bitwarden_data|gitlab_backup>] [-e <exclude_file_path> optionnel]"   
    echo -e ${GREEN}" usage:${COLOR_OFF} ./backup_clients.sh -s ssh_client -d /mnt/data/backup/client -o www -e /mnt/data/backup/client/.rsyncignore"
    exit 1;
}

# send_slack ${MESSAGE}
function send_slack() {
    SLACK_HOOKS="https://hooks.slack.com/services/<...>"
    SLACK_CHANNEL_ID="******"
    MESSAGE="$@" 
    echo "${MESSAGE}"   
    curl --silent --output /dev/null --show-error --fail --request POST --url ${SLACK_HOOKS} --header 'content-type: application/json' --data "{ \"text\":\"${MESSAGE}\", \"channel\": \"${SLACK_CHANNEL_ID}\" }"    
}

# test_path <backup_dir_path> <www_data|mysql_backup|mongodb_backup|metabase_data|bitwarden_data|gitlab_backup>
function test_path() {
    if [ ! -d "$1/$2" ]; then
        if [ ! -f "$1/$2" ]; then            
            echo -e ${GREEN}" info:${COLOR_OFF} Création du repertoire : $1/$2" 
            mkdir -p $1/$2
        fi        
    fi
}

# get_source_path <source_in_ssh_config> <www_data|mysql_backup|mongodb_backup|metabase_data|bitwarden_data|gitlab_backup>
function get_source_path() {
    SOURCE_SSH="$1"
    echo $SOURCE_SSH > ./docker_name.txt    
    sed 's/_/-/g' ./docker_name.txt > ./docker-name.txt
    DOCKER_NAME=$(cat ./docker-name.txt)    
    rm ./docker-name.txt && rm  ./docker_name.txt
    SOURCE_NAME="$2"
    case "$SOURCE_NAME" in
        bitwarden_data) SOURCE_PATH="/data/docker-${DOCKER_NAME}/containers_data/bitwarden/";;
        gitlab_backup)
                GITLAB_LAST_BACKUP=$(ssh gitlab_prod ls /data/docker-gitlab-prod/gitlab_data/backups | tail -n 1) 
                SOURCE_PATH="/data/docker-${DOCKER_NAME}/gitlab_data/backups/${GITLAB_LAST_BACKUP}"
        ;;
        www_data) SOURCE_PATH="/data/docker-${DOCKER_NAME}/www/" ;;
        mysql_backup) SOURCE_PATH="/data/docker-${DOCKER_NAME}/containers_backups/mysql/" ;;
        mongo_backup) SOURCE_PATH="/data/docker-${DOCKER_NAME}/containers_backups/mongodb/" ;;
        metabase_data) SOURCE_PATH="/data/docker-${DOCKER_NAME}/containers_data/metabase/";;        
        *) echo -e ${RED}" erreur:${COLOR_OFF} mauvais parametres." && usage ;;
    esac
}

# backup <source_in_ssh_config> <backup_dir_path> <www_data|mysql_backup|mongodb_backup|metabase_data|bitwarden_data|gitlab_backup>
function backup() {    
    SOURCE_SSH="$1"    
    BACKUP_DIR="$2"
    BACKUP_NAME="$3"
    BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"    
    echo "" >> ${BACKUP_DIR}/backup_${BACKUP_NAME}.log
    echo "---" >> ${BACKUP_DIR}/backup_${BACKUP_NAME}.log
    DATE=$(date)
    echo "debut : $DATE" >> ${BACKUP_DIR}/backup_${BACKUP_NAME}.log
    rsync -avi --stats --human-readable --delete --exclude-from="${EXCLUDE_FILE}" ${SOURCE_SSH}:/${SOURCE_PATH} ${BACKUP_PATH} >> ${BACKUP_DIR}/${BACKUP_NAME}.log 
    DATE=$(date)
    echo "fin : $DATE" >> ${BACKUP_DIR}/backup_${BACKUP_NAME}.log  
}

# check_date_backup_mysql <source_in_ssh_config> <BACKUP_DIR>
function check_date_backup_mysql() {
    BACKUP_DIR="$2"
    CURRENT_DATE=$(date -u +"%Y%m%d")     
    FILE_SQL=$(cd ${BACKUP_DIR} && find . -print | grep -i .sql.gz)    
    DATE_FILE_SQL=$(echo ${FILE_SQL} | for i in * ; do awk -F '-' '{print $2}';done | for i in * ; do awk -F '_' '{print $1}';done )

    if [ ! "${DATE_FILE_SQL}" == "${CURRENT_DATE}" ];then        
        MESSAGE="Backup_Tools : $1 - Alerte, le fichier de backup ${FILE_SQL} n'est pas à la date du jour."        
        send_slack ${MESSAGE}
    fi   
}

case "$#" in
    6|8|10) ;;
    *) echo -e ${RED}" erreur:${COLOR_OFF} parametres manquant. $#" && usage ;;
esac

if [ $1 == "-s" ] && [ $3 == "-d" ] && [ $5 == "-o" ];then 
    test_path $4 $6
    get_source_path $2 $6
else
    echo -e ${RED}" erreur:${COLOR_OFF} mauvais parametres." && usage    
fi

case "$#" in
    6) EXCLUDE_FILE="" ;;                
    8)         
        case $7 in
            -e) EXCLUDE_FILE="$8" ;;          
            *) echo -e ${RED}" erreur:${COLOR_OFF} mauvais parametres." && usage ;;
        esac
    ;;
    *) echo -e ${RED}" erreur:${COLOR_OFF} nombre de parametres incorrecte. $#" && usage ;;
esac

backup $2 $4 $6

if [ $6 == "mysql_backup" ];then 
    check_date_backup_mysql $2 $4
fi
