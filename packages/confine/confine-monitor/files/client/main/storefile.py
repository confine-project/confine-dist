
from client.nodeinfo.sliverinfo import sliverinfo
from client.nodeinfo.sysinfo import nodeinfo
import config
import time
import os


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

    ## Write current sequence number to file "current_sequence"
    if os.path.exists(config.PATH + '/current_sequence'):
        file_current_sequence_number = open(config.PATH+'/current_sequence', 'r+')
        print "File exists"
        current_sequence_number = int(file_current_sequence_number.read()) +1
    else:
        file_current_sequence_number = open(config.PATH+'/current_sequence', 'w+')
        current_sequence_number = 1

    file_current_sequence_number.close()
    print "Current: ", current_sequence_number

    file_current_sequence_number = open(config.PATH+'/current_sequence', 'r+')
    open(config.PATH+'/current_sequence', 'w').close() #empty the contents of current sequence file before writing in

    file_current_sequence_number.write(str(current_sequence_number))
    file_current_sequence_number.close()

    # write monitored values to a file with name as the current sequence number
    file_content = open (config.PATH + '/'+str(current_sequence_number), 'w')
    file_content.write(str(system_info))
    file_content.close()

    delete_seen_entries()


def delete_seen_entries():
    if os.path.exists(config.PATH + '/last_seen'):
        file_names= []
        last_seen_file = open(config.PATH + '/last_seen', 'r')
        last_seen_seq = int(last_seen_file.read())
        print "Server has seen entry until: " + str(last_seen_seq)

        for path, dir, files in os.walk(config.PATH):
            for name in files:
                if name != 'current_sequence' and name != 'last_seen':
                    file_names.append(int(name))

        lowest_seq_number = min(file_names)
        for seq in xrange(lowest_seq_number, last_seen_seq+1):
            file_path = config.PATH + '/'+ str(seq)
            if os.path.exists(file_path):
                os.remove(file_path)
            else:
                print "An expected file with sequence number %s was not present" %str(seq)

