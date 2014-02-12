import psutil
from psutil._compat import print_
import time

def to_meg(n):
    return str(int(n / 1024 / 1024)) + "M"

def bytes2human(n):
    # http://code.activestate.com/recipes/578019
    # >>> bytes2human(10000)
    # '9.8K'
    # >>> bytes2human(100001221)
    # '95.4M'
    symbols = ('K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y')
    prefix = {}
    for i, s in enumerate(symbols):
        prefix[s] = 1 << (i+1)*10
    for s in reversed(symbols):
        if n >= prefix[s]:
            value = float(n) / prefix[s]
            return '%.1f%s' % (value, s)
    return "%sB" % n



def network_all():

    tot_before = psutil.network_io_counters()
    pnic_before = psutil.network_io_counters(pernic=True)
    # sleep some time
    time.sleep(1)
    tot_after = psutil.network_io_counters()
    pnic_after = psutil.network_io_counters(pernic=True)

    nic_names = pnic_after.keys()

    network= {}

    for name in nic_names:
        stats_before = pnic_before[name]
        stats_after = pnic_after[name]

        network[name] = {'bytes_sent': stats_after.bytes_sent,
                         'bytes_recv': stats_after.bytes_recv,
                         'bytes_sent_last_sec':stats_after.bytes_sent - stats_before.bytes_sent ,
                         'bytes_recv_last_sec': stats_after.bytes_recv - stats_before.bytes_recv  }



    network['total'] = {'bytes_sent':tot_after.bytes_sent,
                        'bytes_recv':tot_after.bytes_recv,
                        'bytes_sent_last_sec': tot_after.bytes_sent - tot_before.bytes_sent,
                        'bytes_recv_last_sec': tot_after.bytes_recv - tot_before.bytes_recv}

    return network



def main():
    print_('Network Information\n------')
    #bytes_sent= psutil.network_io_counters().bytes_sent
    #print (bytes2human(bytes_sent))

   # check()
    value = network_all()
    print value

if __name__ == '__main__':
   main()