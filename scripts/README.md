cass_server_v2.sh and cass_client_v2.sh
    Used to maintenance cassandra cluster: performing backup of keyspaces ( can be configured as a key in consul ), cleaning old snapshots, starting repair and performing restart after repair.
cass_timeout_check.py
    Performing write and reading data from cassandra tables. Checking timeouts and in case of over time sending a email to team.