
from client.nodeinfo.sliverinfo import sliverinfo
from client.nodeinfo.sysinfo import nodeinfo
import config
import time
import shelve


def monitorStore():
    """
    Get monitored information
    Attach the sequence number
    Attach timestamp
    Store in the log file
    delete seen entries
    """
   # commented to use psutil system info system_info = systeminfo.get_all_info()

    system_info = nodeinfo.node_all()
    system_info ['monitored_timestamp'] = config.get_current_system_timestamp()

    # Attach sliver info to system info
    system_info.update(sliverinfo.collectAllDataAPI())

    s = shelve.open('log_shelf.db', writeback = True)

    while(1):
        try:
            try:
                if s.has_key('current_seq_number'):
                    #Update current sequence number
                    s['current_seq_number']+= 1
                    current_seq = s['current_seq_number']
                else:
                    current_seq = 1
                    s['current_seq_number']= current_seq

                print("writing to file: " + str(current_seq))

            #  print("writing to file" + str(system_info))
                s[str(current_seq)]= system_info


            finally:
                s.close()
                break

        except OSError:
            # In some research devices, the underlying dbm has a bug which needs to be handled explicitly
            print("Exception caught while handling shelve file!! OS Error: file not found. Trying again in 1 second")
            time.sleep(1)
            continue

    delete_seen_entries()


def delete_seen_entries():
    s = shelve.open('log_shelf.db')
    r =shelve.open('last_seen.db')
    while(1):
        try:
            try:
                if r.has_key('last_seen_seq'):
                    last_seen_seq=r['last_seen_seq']

                if (s.has_key(str(last_seen_seq))):
                    print("Server has seen entry until: " + str(last_seen_seq))
                    for key in s.keys():
                        if (int (key) <= int(last_seen_seq)):
                            print "Deleting key: " + key
                            del s[key]
            finally:
                s.close()
                r.close()
                break

        except OSError:
            # In some research devices, the underlying dbm has a bug which needs to be handled explicitly
            print("Exception caught while handling shelve file!! OS Error: file not found. Trying again in 1 second")
            time.sleep(1)
            continue