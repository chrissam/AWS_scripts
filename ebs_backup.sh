#!/bin/bash

ACTION=$1
AGE=$2

if [ -z $ACTION ];
then
    echo "Usage $1: Define ACTION of backup or delete"
    exit 1
fi

if [ "$ACTION" == "delete" ] && [ -z $AGE ];
then
    echo "Please enter the age of backups you would like to delete"
    exit 1
fi

function backup_ebs () {
    
    prod_instances=`aws ec2 describe-instances --filters "Name=tag-value,Values=prod*" | jq -r ".Reservations[].Instances[].InstanceId"`

    for instance in $prod_instances
    do  

        volumes=`aws ec2 describe-volumes --filter Name=attachment.instance-id,Values=$instance | jq .Volumes[].VolumeId | sed 's/\"//g'`
        
        for volume in $volumes
        do
            #echo Creating snapshot for $volume
            echo Creating snapshot for $volume $(aws ec2 create-snapshot --volume-id $volume --description "ebs-backup-script")
        done

    done
}


function delete_snapshots () {
    
    for snapshot in $(aws ec2 describe-snapshots --filters Name=description,Values=ebs-backup-script | jq .Snapshots[].SnapshotId | sed 's/\"//g')
    do
        #echo $snapshot
        SNAPSHOTDATE=$(aws ec2 describe-snapshots --filters Name=snapshot-id,Values=$snapshot | jq .Snapshots[].StartTime | cut -d T -f1 | sed 's/\"//g')
        STARTDATE=$(date +%s)
        ENDDATE=$(date -d $SNAPSHOTDATE +%s)
        INTERVAL=$[ (STARTDATE - ENDDATE) / (60*60*24) ]

        if (( $INTERVAL >= $AGE ));
        then
            echo "Deleting snapshot --> $snapshot"
            aws ec2 delete-snapshot --snapshot-id $snapshot
        fi

    done
}

case $ACTION in
    
    "backup")
            backup_ebs
    ;;

    "delete")
            delete_snapshots
    ;;

esac

