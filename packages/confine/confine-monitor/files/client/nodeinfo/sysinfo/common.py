from __future__ import division
from collections import namedtuple

def usage_percent(used, total, _round=None):
    """Calculate percentage usage of 'used' against 'total'."""

    try:
        ret = (used / total) * 100
    except ZeroDivisionError:
        ret = 0
    if _round is not None:
        return round(ret, _round)
    else:
        return ret

nt_sys_cputimes = namedtuple('cputimes', 'user nice system idle iowait irq softirq')
nt_diskstatus = namedtuple('usage', 'total used free percent')
nt_diskpartitions = namedtuple('partitions', 'device blocks used available use_percent mountpoint')
nt_net_iostat = namedtuple('iostat', 'bytes_sent bytes_recv packets_sent packets_recv errin errout dropin dropout')
nt_virtmem_info = namedtuple('vmem', 'total available percent used free buffers cached')