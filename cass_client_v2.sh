#!/bin/bash
#######################
list_of_keyspaces=()
## keyspaces to save
######################
host=$(hostname)
if [ ! -f /var/lib/cassandra/repair_cassandra.log ]; then
    touch /var/lib/cassandra/repair_cassandra.log
fi
#######################################
# Name:
#   saving
# Description:
#   Starting procedure of making backup for requested keyspaces.
# Important variables:
#   list_of_keyspaces [array]
# Arguments:
#   None
# Returns:
#   None
#######################################
function saving {
    NEWLINE=$'\n'
    echo "###Host is $host###"
    echo "Creating backups:"
    for i in ${list_of_keyspaces[@]}; do nodetool -h localhost -p 7199 snapshot -t backup_`date +%Y-%m-%d` ${i}
#		echo ${NEWLINE}
    done
    echo "###Backup is done###"
}
#######################################
# Name:
#   clearing_old_backups
# Description:
#   Deleting old backups.
# Important variables:
#   filtered_backups [array] -- used for storing list of snapshots that was prefix "backup_" in name
# Arguments:
#   None
# Returns:
#   None
#######################################
function clearing_old_backups {
    echo "###Start clearing###"
    arr=($(nodetool listsnapshots | cut -d " " -f1 | uniq | head -n -3 | tail -n +2))
    arr=($(for l in ${arr[@]}; do echo $l; done | sort))

    for i in "${arr[@]}"; do
        if [ "$(echo $i | cut -c1-7)" = "backup_" ]
            then
                filtered_backups+=($i)
        fi
    done

    array_lenght_hosts=${#filtered_backups[@]}

    let array_lenght_hosts=array_lenght_hosts-3
    if [ "$array_lenght_hosts" -lt "0" ]
        then
            echo "There are not enough snapshots, exiting"
            exit_code=1
        else
            echo "Snapshots quantity is okay"
        fi
    echo
    element="0"

    if [ "$exit_code" != "1" ]
        then
            while [ "$element" -le "$array_lenght_hosts" ]
                do
                    echo The date of snapshot for delete is ${filtered_backups[$element]}${NEWLINE}
                    nodetool clearsnapshot -t ${filtered_backups[$element]}
                    echo
                    let element=element+1
            done
    fi

    echo "###Clearing is done####"
}
#######################################
# Name:
#   repair
# Description:
#   Starting procedure of repair on chosen nodes.
# Important variables:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
function repair {
    nohup nodetool repair -pr -tr -full 1>>/var/lib/cassandra/repair_cassandra.log 2>>/var/lib/cassandra/repair_cassandra.log &
    sleep $1
    check=$(ps -ef | grep "repair -pr -tr -full" | grep -v grep | awk '{print $2}')
    check_fin=$(tail -7 /var/lib/cassandra/repair_cassandra.log | grep 'Repair completed successfully')
    if [ "$check" = "" ] && [ "$check_fin" != "" ]
    then
        echo "Process finished successfully. See log for details."
    elif [ "$check" != "" ] && [ "$check_fin" = "" ]
    then
        echo "Process was killed (timeout error). See log for details."
        ps -ef | grep "repair -pr -tr -full" | grep -v grep | awk '{print $2}' | xargs kill
    elif [ "$check" = "" ] && [ "$check_fin" = "" ]
    then
        echo "Process was finished, but looks like repair was unsuccessful (empty successful code error). See log for details."
    elif [ "$check" != "" ] && [ "$check_fin" != "" ]
    then
        echo "Repair was finished, but process was killed with timeout error (timeout error). See log for details."
        ps -ef | grep "repair -pr -tr -full" | grep -v grep | awk '{print $2}' | xargs kill
    fi
}
#######################################
# Name:
#   restart_f
# Description:
#   Starting procedure of restart on chosen nodes after repair.
#   WARNING: Cassandra must be installed as a service. Tested on CentOS 7.4. Using systemctl.
# Important variables:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
function restart_f {
    sudo /bin/systemctl restart cassandra
    tries="3"
    while [ "$tries" -gt "0" ]
		do
			stup_check=$(netstat -tulpn | grep 9042)
			if [ "$stup_check" != "" ]
				then
					tries="0"
			else
				let tries=tries-1
				sleep 180
			fi
		done
    if [ "$stup_check" = "" ]
		then
			echo "Restart was unsuccessful. Please start cassandra in manual mode."
    fi
}
#######################################
# Name:
#   restart_flush
# Description:
#   Starting procedure of flushing memtables to SSTables on chosen keyspaces.
#   WARNING: Cassandra must be installed as a service. Tested on CentOS 7.4. Using systemctl.
# Important variables:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
function flush {
    nohup nodetool flush -- 1>>/var/lib/cassandra/repair_flush_cassandra.log 2>>/var/lib/cassandra/repair_flush_cassandra.log &
}
#######################################
if [ "$1" = "repair" ]
    then
    echo "================================================="
    echo "Host ($host) is chosen one. This host will be restarted and repaired after."
	echo "Timeout set to: $2 seconds"
	printf '%dh:%dm:%ds\n' $(($2/3600)) $(($2%3600/60)) $(($2%60))
	timeout_repair=$(echo $2)
#    restart_f
    repair $timeout_repair
    echo "================================================="
else
	temp_op_key=$(echo $1)
	operation_key=${temp_op_key::-1}
	if [ "$operation_key" = "ks_key_" ]
		then
			keyspace_count=$(echo $1 | cut -c 8-)
			echo "Found $keyspace_count keyspaces for saving."
		else
			echo "Parsing was failed. Wrong initial argument."
			pars_code=1
	fi
	if [ "$pars_code" != "1" ]
		then
			keyspace_count_done=0
            args=("$@")
    		keyspace_count=$keyspace_count+1
	    	for (( i=1;i<$keyspace_count;i++)); do
    	    	list_of_keyspaces+=(${args[${i}]})
		    done
		echo "Parsing was ended. Successfully recognized ${#list_of_keyspaces[@]} keyspaces. List of keyspaces: ${list_of_keyspaces[*]}"
		echo ${NEWLINE}
		#calling backup function
		saving
		clearing_old_backups
		flush
	else
		echo "Since parsing step was unsuccessful, and also because it is a snapshot-session - the session will be terminated."
	    exit
	fi
fi
