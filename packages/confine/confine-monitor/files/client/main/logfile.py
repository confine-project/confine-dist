from client.main import config
import os
import ast

def get_all_info_since(seqnumber):
    """
    return all the information in the log file since the last seen seq number as a list
    Attach the current client timestamp, and time since the information was monitored (relative_timestamp)
    """
    file_names = []
    last_seen_seq = seqnumber
    system_info= {}


    for path, dir, files in os.walk(config.PATH):
        for name in files:
            if name != 'current_sequence' and name != 'last_seen':
                file_names.append(int(name))

    file_current_sequence_number = open(config.PATH+'/current_sequence', 'r')

    for seq in xrange(last_seen_seq+1, int(file_current_sequence_number.read()) +1):
        path = config.PATH + '/'+str(seq)
        if os.path.exists(path):
            temp_file = open (config.PATH + '/'+str(seq), 'r')
            value = ast.literal_eval(temp_file.read())
            # Do not persist current_timestamp and relative_timestamp. They are calculated every time a request is received in order to account for newer calculations in case of network partitions.
            value['relative_timestamp'] = config.get_current_system_timestamp()-value['monitored_timestamp']
            system_info[str(seq)] = value
            temp_file.close()
        else:
            print "[ERROR]: A file with sequence number not seen has been deleted:: ", seq
    file_current_sequence_number.close()
    write_last_seen_sequence_number(last_seen_seq)

    #print system_info.items()
    return system_info


def write_last_seen_sequence_number(last_seen_seq):
    file_last_seen = open(config.PATH+'/last_seen', 'w')
    file_last_seen.write(str(last_seen_seq))
    file_last_seen.close()
