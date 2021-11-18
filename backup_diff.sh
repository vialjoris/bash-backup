#!/bin/bash
# rsync_diff -s source_path -b backup_path -e file_exclude_path -k number of saved backups
GREEN="\\033[1;32m"
RED="\\033[1;31m"
COLOR_OFF="\\033[0;39m"


set -o errexit
set -o nounset
set -o pipefail

function usage() {
    echo -e ${GREEN}" usage:${COLOR_OFF} ./backup_diff.sh  [-s <source_path>]  [-b <backup_path>] [-e <exclude_file_path> optionnel] [-k <number of saved backups> default = 7]"   
    echo -e ${GREEN}" usage:${COLOR_OFF} ./backup_diff.sh -s /home/dev -b /mnt/data/backup -e /home/dev/.rsyncignore"
    exit 1;
}

function test_path() {
    if [ ! -d "$1" ]; then
        if [ ! -f "$1" ]; then
            echo -e ${GREEN}" info:${COLOR_OFF} Création du repertoire : $1" 
            mkdir -p $1
        fi        
    fi
}

function rsync_diff() {
    
    SOURCE_DIR="$1"
    BACKUP_DIR="$2"
    DATETIME="$(date '+%Y-%m-%d_%H:%M:%S')"
    BACKUP_PATH="${BACKUP_DIR}/${DATETIME}"
    LATEST_LINK="${BACKUP_DIR}/latest"
    echo "" >> ${BACKUP_DIR}/backup_diff.log
    echo "---" >> ${BACKUP_DIR}/backup_diff.log
    date >> ${BACKUP_DIR}/backup_diff.log
    rsync -av --delete \
    "${SOURCE_DIR}/" \
    --link-dest "${LATEST_LINK}" \
    --exclude-from="${EXCLUDE_FILE}" \
    "${BACKUP_PATH}" >> ${BACKUP_DIR}/backup_diff.log

    rm -rf "${LATEST_LINK}"
    ln -s "${BACKUP_PATH}" "${LATEST_LINK}"
    
}

function clean_backups() {
    ((NB_SAVED_BAKUPS++))          
    echo "find ${BACKUP_DIR} -maxdepth 1 -type d -printf '%Ts\t%P\n' | sort -n | head -n -${NB_SAVED_BAKUPS} | cut -f 2- | xargs rm -rf" > ${BACKUP_DIR}/clear.sh
    chmod +x ${BACKUP_DIR}/clear.sh
    cd ${BACKUP_DIR} && ./clear.sh
    rm ${BACKUP_DIR}/clear.sh    
}

function unset_var() {
    unset SOURCE_DIR
    unset BACKUP_DIR
    unset DATETIME
    unset BACKUP_PATH
    unset LATEST_LINK
    unset EXCLUDE_FILE
    unset NB_SAVED_BAKUPS
}

case "$#" in
    4|6|8) ;;
    *) echo -e ${RED}" erreur:${COLOR_OFF} parametres manquant." && usage ;;
esac

if [ $1 == "-s" ] && [ $3 == "-b" ];then 
    test_path $2 && test_path $4
else
    echo -e ${RED}" erreur:${COLOR_OFF} mauvais parametres." && usage    
fi

case "$#" in
    4) EXCLUDE_FILE="" && NB_SAVED_BAKUPS="7" ;;
    6)              
        case $5 in
            -e) EXCLUDE_FILE="$5" && NB_SAVED_BAKUPS="7" ;;
            -k) EXCLUDE_FILE="" && NB_SAVED_BAKUPS="$6" ;;
            *) echo -e ${RED}" erreur:${COLOR_OFF} mauvais parametres." && usage ;;
        esac 
    ;;             
    8) 
        case $5 in
            -e) EXCLUDE_FILE="$6" ;;
            -k) NB_SAVED_BAKUPS="$6" ;;
            *) echo -e ${RED}" erreur:${COLOR_OFF} mauvais parametres." && usage ;;
        esac
        case $7 in
            -e) [ ! $5 == "-e" ] && EXCLUDE_FILE="$8" || echo -e ${RED}" erreur:${COLOR_OFF} doublon dans les parametres." && usage  ;;
            -k) [ ! $5 == "-k" ] && NB_SAVED_BAKUPS="$8" || echo -e ${RED}" erreur:${COLOR_OFF} doublon dans les parametres." && usage ;;
            *) echo -e ${RED}" erreur:${COLOR_OFF} mauvais parametres." && usage ;;
        esac
    ;;
    *) echo -e ${RED}" erreur:${COLOR_OFF} nombre de parametres incorrecte. $#" && usage ;;
esac

rsync_diff $2 $4 && clean_backups && unset_var || usage
