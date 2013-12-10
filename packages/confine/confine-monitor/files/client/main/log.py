from client.main import config

import shelve
import os

def get_all_info_since(seqnumber):
    """
    return all the information in the log file since the last seen seq number as a list
    Attach the current client timestamp, and time since the information was monitored (relative_timestamp)
    """
    last_seen_seq = seqnumber
    system_info= {}
    path = os.path.join(os.path.dirname(__file__), '../../log_shelf.db')
    print path

    s= shelve.open(str(path))	
    try:
       # Once deleting seq numbers in logs are implemented, then check for sequence number limits

        for seq in range(last_seen_seq+1, s['current_seq_number']+1):
            print seq
            if(str(seq) in s):
                value = s[str(seq)]
                # Do not persist current_timestamp and relative_timestamp. They are calculated every time a request is received in order to account for newer calculations in case of network partitions.
                value['relative_timestamp'] = config.get_current_system_timestamp()-value['monitored_timestamp']
                system_info[str(seq)] = value

    finally:
        s.close()

    #config.update_last_seen_seq_number(last_seen_seq)
    write_last_seen_sequence_number(last_seen_seq)


    #print system_info.items()
    return system_info


def write_last_seen_sequence_number(last_seen_seq):
    path = os.path.join(os.path.dirname(__file__), '../../last_seen.db')
    print path
    s= shelve.open(str(path), writeback=True)
    try:
        s['last_seen_seq'] = last_seen_seq
    finally:
        s.close()