import time
from client.nodeinfo.sysinfo.common import nt_net_iostat

def network_io_info():
    """Return network I/O statistics for every network interface
    installed on the system as a dict of raw tuples.
    """
    f = open("/proc/net/dev", "r")
    try:
        lines = f.readlines()
    finally:
        f.close()

    retdict = {}
    for line in lines[2:]:
        colon = line.find(':')
        assert colon > 0, line
        name = line[:colon].strip()
        fields = line[colon+1:].strip().split()
        bytes_recv = int(fields[0])
        packets_recv = int(fields[1])
        errin = int(fields[2])
        dropin = int(fields[2])
        bytes_sent = int(fields[8])
        packets_sent = int(fields[9])
        errout = int(fields[10])
        dropout = int(fields[11])
        retdict[name] = (bytes_sent, bytes_recv, packets_sent, packets_recv,
                         errin, errout, dropin, dropout)
    return retdict

def network_io_counters(pernic=False):
    """Return network I/O statistics as a namedtuple including
    the following attributes:

     - bytes_sent:   number of bytes sent
     - bytes_recv:   number of bytes received
     - packets_sent: number of packets sent
     - packets_recv: number of packets received
     - errin:        total number of errors while receiving
     - errout:       total number of errors while sending
     - dropin:       total number of incoming packets which were dropped
     - dropout:      total number of outgoing packets which were dropped
                     (always 0 on OSX and BSD)

    If pernic is True return the same information for every
    network interface installed on the system as a dictionary
    with network interface names as the keys and the namedtuple
    described above as the values.
    """
    rawdict = network_io_info()
    if not rawdict:
        raise RuntimeError("couldn't find any network interface")
    if pernic:
        for nic, fields in rawdict.items():
            rawdict[nic] = nt_net_iostat(*fields)
        return rawdict
    else:
        return nt_net_iostat(*[sum(x) for x in zip(*rawdict.values())])

def network_all():

    tot_before = network_io_counters()
    pnic_before = network_io_counters(pernic=True)
    # sleep some time
    time.sleep(1)
    tot_after = network_io_counters()
    pnic_after = network_io_counters(pernic=True)

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

if __name__ == "__main__":

    print('Network Information\n------')

    value = network_all()
    print value
