#!/bin/bash
#shellcheck disable=SC2002

# script de backup avec la solution borg backup vers un serveur accessible en ssh d'un repertoire avec --keep-daily=7 --keep-weekly=4 --keep-monthly=6 en retention + push metrics vers prometheus via pushgateway

function usage(){
    echo " ./borg.sh --ssh ssh_connection --projet projet_name --data data_sauvegardée"        
}

function declare_variable(){
    SSH_REMOTE="${2}"    
    PROJET="${4}"
    DATA="${6}"
}

function push_metrics(){

    name_metric=$2
    valeur_metric=$4
    job=$6
    type=$8

    echo -e "# TYPE ${name_metric} ${type}\n${name_metric} ${valeur_metric}" | curl --data-binary @- http://127.0.0.253:9091/metrics/job/${job}

}

function borg_info_metrics(){

    borg info ssh://"${SSH_REMOTE}"/home/borg/"${PROJET}"/"${DATA}"::"${PROJET}"_"${DATA}"-"$(date +%Y-%m-%d)" --json > /data/backups/"${PROJET}"/log/borg_"${DATA}".json

    duration="$(cat /data/backups/"${PROJET}"/log/borg_"${DATA}".json  | grep duration | awk -F ': ' '{print $2}' | awk -F ',' '{print $1}')"
    compressed_size="$(cat /data/backups/"${PROJET}"/log/borg_"${DATA}".json | grep compressed_size | awk -F ': ' '{print $2}' | awk -F ',' '{print $1}')"
    deduplicated_size="$(cat /data/backups/"${PROJET}"/log/borg_"${DATA}".json | grep deduplicated_size | awk -F ': ' '{print $2}' | awk -F ',' '{print $1}')"
    nfiles="$(cat /data/backups/"${PROJET}"/log/borg_"${DATA}".json | grep nfiles | awk -F ': ' '{print $2}' | awk -F ',' '{print $1}')"
    original_size="$(cat /data/backups/"${PROJET}"/log/borg_"${DATA}".json | grep original_size | awk -F ': ' '{print $2}' | awk -F ',' '{print $1}')"

    push_metrics --name_metric "borg_${PROJET}_${DATA}_duration" --valeur_metric "${duration}" --job "borg_${PROJET}_${DATA}_duration" --type GAUGE
    push_metrics --name_metric "borg_${PROJET}_${DATA}_compressed_size" --valeur_metric "${compressed_size}" --job "borg_${PROJET}_${DATA}_compressed_size" --type GAUGE
    push_metrics --name_metric "borg_${PROJET}_${DATA}_deduplicated_size" --valeur_metric "${deduplicated_size}" --job "borg_${PROJET}_${DATA}_deduplicated_size" --type GAUGE
    push_metrics --name_metric "borg_${PROJET}_${DATA}_nfiles" --valeur_metric "${nfiles}" --job "borg_${PROJET}_nfiles" --type GAUGE
    push_metrics --name_metric "borg_${PROJET}_${DATA}_original_size" --valeur_metric "${original_size}" --job "borg_${PROJET}_${DATA}_original_size" --type GAUGE

}

function borg_create(){
    borg create --stats ssh://"${SSH_REMOTE}"/home/borg/"${PROJET}"/"${DATA}"::"${PROJET}"_"${DATA}"-"$(date +%Y-%m-%d)" /data/backups/"${PROJET}"/"${DATA}" 2>> /data/backups/"${PROJET}"/log/borg_"${DATA}".log 
}

function borg_prune(){
    borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6 --stats ssh://"${SSH_REMOTE}"/home/borg/"${PROJET}"/"${DATA}" 2>> /data/backups/"${PROJET}"/log/borg_"${DATA}".log
    cat /data/backups/"${PROJET}"/log/borg_"${DATA}".log > /data/backups/"${PROJET}"/log/borg_"${DATA}".info
}

case $1 in
--help|-h|--usage|-u) usage && exit 0 ;;
--ssh)
    case "$#" in
        6) ;;
        *) echo -e "${RED} erreur:${COLOR_OFF} parametres manquant. $#" && usage && exit 1 ;;
    esac

    declare_variable "$@" && borg_create && borg_prune && borg_info_metrics
;;
--metrics)
    case "$#" in
        6) ;;
        *) echo -e "${RED} erreur:${COLOR_OFF} parametres manquant. $#" && usage && exit 1 ;;
    esac

    declare_variable "$@" && borg_info_metrics
;;
*) echo "erreur parametre" && exit 1;;
esac

