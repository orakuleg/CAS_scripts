#!/usr/bin/python

import time;
import datetime;
from cassandra.cluster import Cluster
from cassandra.query import SimpleStatement
from cassandra import ConsistencyLevel

log_file = open("cassandra_time_logging.out","a+")

keyspace_name = 'NAME_OF_KEYSPACE'
cluster = Cluster(['0.0.0.0', '1.1.1.1', '2.2.2.2', '3.3.3.3'])

session = cluster.connect(keyspace_name)
timeout_to_warn = datetime.time(0, 0, 5)

flag = 0


def read():
    query = "select * from cassandra_monitoring.time_checks where date = %s order by custom_field_1 desc limit 1;"
    cur_date = datetime.datetime.now().date()
    ts1=datetime.datetime.now()
    log_file.write(("{0} Starting reading from cassandra \n").format(datetime.datetime.now()))
    rows=session.execute(query, [str(cur_date)])
    ts2=datetime.datetime.now()
    if not rows:
        log_file.write(("{0} Not found any entries with current date. Performing write operation first.	 {1} \n").format((datetime.datetime.now()),(ts2-ts1)))
        global flag
        flag = 1
    else:
        log_file.write(("{0} Ended reading from cassandra. Reading take {1} \n").format((datetime.datetime.now()),(ts2-ts1)))
    diff_time=(datetime.datetime.min + (ts2-ts1)).time()
    if (diff_time) > (timeout_to_warn):
        log_file.write(("{0} Found abnormal time to operation. !!!!!!WARNING!!!!!!  \n").format((datetime.datetime.now()),))

def write():
    ts1=datetime.datetime.now()
    log_file.write(("{0} Starting writing to cassandra \n").format(datetime.datetime.now()))
    query = SimpleStatement("INSERT INTO cassandra_monitoring.time_checks (date, custom_field_1, custom_field_2, execution_time, opearion_type) VALUES (%s, %s, %s, %s, %s)",consistency_level=ConsistencyLevel.QUORUM)
    session.execute(query, (str(datetime.datetime.now().date()), 'Null', 'Null', ((str(datetime.datetime.now()).replace(".","+"))[:-7]), 'write'))
    ts2=datetime.datetime.now()
    log_file.write(("{0} Ended writing to cassandra. Writing take {1} \n").format((datetime.datetime.now()),(ts2-ts1)))
    diff_time=(datetime.datetime.min + (ts2-ts1)).time()
    if (diff_time) > (timeout_to_warn):
        log_file.write(("{0} Found abnormal time to operation. !!!!!!WARNING!!!!!!  \n").format((datetime.datetime.now()),))

log_file.write(("{0} Starting new check. ================== \n").format(datetime.datetime.now()))
read()
if flag==1:
    write()
    read()
    flag = 0
else:
    write()
log_file.write(("{0} Ended of check. ====================== \n").format(datetime.datetime.now()))
log_file.close()
