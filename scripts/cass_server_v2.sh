#!/bin/bash

##!!!!!!!!!!!!!!!!!!!!!!!!!!!required package jq to work
IFS=" "
hosts=(server1.domen.com server2.domen.com server3.domen.com)
#hosts - array used to store information about hosts with cassandra nodes. Space (' ') as a delimiter.
#                   list_of_keyspaces=(sga13 sga12)
keyspaces=$(curl -s http://your_consul_server | jq -r '.[].Value' | base64 -d)
list_of_keyspaces=($keyspaces)
#list_of_keyspaces - array used to store information about list of keyspaces to backup. Space (' ') as a delimiter.
key_location=/tmp/test.pem
#key_location - variable used to define location of key. Used for connect to nodes.
key_user=centos
#key_user - user for key.
timeout_repair=10800
#timeout_repair - variable that is used as a timer for a repair operation. Specified in seconds. If repair process does not end within the specified time, it will be killed.
#######################################
NEWLINE=$'\n'
#######################################
logs=(cassandra_maitenance.log to_send.out)
for i in "${!logs[@]}"; do
	if [ ! -f "${logs[$i]}" ]; then
		touch "${logs[$i]}"
	fi
done
#######################################
# Name:
#   saving
# Description:
#   Starting procedure of making backup for requested keyspaces.
# Important variables:
#   key_location
#   key_user
#   hosts   [array]
#   logs    [array]
# Arguments:
#   None
# Returns:
#   None
#######################################
function saving {
	echo "======================== SAVING AND CLEANING `date +%Y-%m-%d` ========================" | tee -a ${logs[@]} output
	for i in "${!hosts[@]}"; do
		ssh -i $key_location $key_user@${hosts[$i]} "sudo -u cassandra /cass_client_v2.sh $new_args" > output
		cat output >> sensors_full.log
		cat output >> to_send.out
	done
}
#######################################
# Name:
#   argu
# Description:
#   Creating list of arguments to call a client script.
# Important variables:
#   list_of_keyspaces   [array]
# Arguments:
#   None
# Returns:
#   None
#######################################
function argu {
	array_lenght_ks=${#list_of_keyspaces[@]}
	new_args="ks_key_$array_lenght_ks"
	for i in "${!list_of_keyspaces[@]}"; do
		new_args="$new_args ${list_of_keyspaces[$i]}"
	done
}
#######################################
# Name:
#   repair
# Description:
#   Function that performs analysis of logs and choose last repaired node. After that it calling repair on next node after already repaired.
# Important variables:
#   hosts   [array]
# Arguments:
#   None
# Returns:
#   None
#######################################
function repair {
    sleep $timeout_repair
	grep_result=$( grep REPAIR ./cassandra_maitenance.log | tail -1  | cut -c 37-)
	for i in "${!hosts[@]}"; do
	   if [[ "${hosts[$i]}" = "${grep_result}" ]]; then
		   let grep_index=$i+1
		   if [ $grep_index -ge ${#hosts[@]} ]
			   then
					let grep_index=$grep_index-${#hosts[@]}
		   fi
	   fi
	done
	echo "==================${NEWLINE}==================${NEWLINE}==================${NEWLINE}==================REPAIR `date +%Y-%m-%d` ${hosts[grep_index]}${NEWLINE}==================${NEWLINE}==================" | tee -a ${logs[@]} output
	ssh -i $key_location $key_user@${hosts[grep_index]} "sudo -u cassandra /cass_client_v2.sh \"repair\" $timeout_repair "> output
	cat output >> sensors_full.log
	cat output >> to_send.out
}
#######################################
# Name:
#   mail_notif
# Description:
#   Function that performs mail notification with output of script as a attachment.
# Important variables:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
function mail_notif {
	mail -s "Cassandra maitenance `date +%Y-%m-%d`" "user1@test.com"  < to_send.out
}
#######################################
if [ "${#list_of_keyspaces[@]}" -eq "0" ]
	then
		echo "List of keyspaces not provided. Processing only repair." | tee -a ${logs[@]}
		repair
		mail_notif
		echo "" > to_send.out
	else
		argu
		saving
		repair
		mail_notif
		echo "" > to_send.out
fi
