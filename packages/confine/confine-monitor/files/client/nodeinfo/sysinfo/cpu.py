import re
import time
from client.nodeinfo.sysinfo.common import nt_sys_cputimes, usage_percent
import os

_CLOCK_TICKS = os.sysconf(os.sysconf_names["SC_CLK_TCK"])

#works
def _get_boot_time():
    """Return system boot time (epoch in seconds)"""
    f = open('/proc/stat', 'r')
    try:
        for line in f:
            if line.startswith('btime'):
                return float(line.strip().split()[1])
        raise RuntimeError("line 'btime' not found")
    finally:
        f.close()

#####################################CPU######################################################
INTERVAL = 1 #Node monitoring period must be greater than INTERVAL*2 seconds

def get_num_cpus():
    num = 0
    if num == 0:
        f = open('/proc/stat', 'r')
        try:
            lines = f.readlines()
        finally:
            f.close()
        search = re.compile('cpu\d')
        for line in lines:
            line = line.split(' ')[0]
            if search.match(line):
                num += 1

    if num == 0:
        raise RuntimeError("can't determine number of CPUs")
    return num


def get_system_cpu_times():
    """Return a named tuple representing the following CPU times:
    user, nice, system, idle, iowait, irq, softirq.
    """
    f = open('/proc/stat', 'r')
    try:
        values = f.readline().split()
    finally:
        f.close()

    values = values[1:8]
    values = tuple([float(x) / _CLOCK_TICKS for x in values])
    return nt_sys_cputimes(*values[:7])


def get_system_per_cpu_times():
    """Return a list of namedtuple representing the CPU times
    for every CPU available on the system.
    """
    cpus = []
    f = open('/proc/stat', 'r')
    # get rid of the first line who refers to system wide CPU stats
    try:
        f.readline()
        for line in f.readlines():
            if line.startswith('cpu'):
                values = line.split()[1:8]
                values = tuple([float(x) / _CLOCK_TICKS for x in values])
                entry = nt_sys_cputimes(*values[:7])
                cpus.append(entry)
        return cpus
    finally:
        f.close()


def cpu_percent(interval=0.1, percpu=False):
    """Return a float representing the current system-wide CPU
    utilization as a percentage.

    When interval is > 0.0 compares system CPU times elapsed before
    and after the interval (blocking).

    When interval is 0.0 or None compares system CPU times elapsed
    since last call or module import, returning immediately.
    In this case is recommended for accuracy that this function be
    called with at least 0.1 seconds between calls.

    When percpu is True returns a list of floats representing the
    utilization as a percentage for each CPU.
    First element of the list refers to first CPU, second element
    to second CPU and so on.
    The order of the list is consistent across calls.
    """
    global _last_cpu_times
    global _last_per_cpu_times
    blocking = interval is not None and interval > 0.0

    def calculate(t1, t2):
        t1_all = sum(t1)
        t1_busy = t1_all - t1.idle

        t2_all = sum(t2)
        t2_busy = t2_all - t2.idle

        # this usually indicates a float precision issue
        if t2_busy <= t1_busy:
            return 0.0

        busy_delta = t2_busy - t1_busy
        all_delta = t2_all - t1_all
        busy_perc = (busy_delta / all_delta) * 100
        return round(busy_perc, 1)

    # system-wide usage
    if not percpu:
        if blocking:
            t1 = get_system_cpu_times()
            time.sleep(interval)
        else:
            t1 = _last_cpu_times
        _last_cpu_times = get_system_cpu_times()
        return calculate(t1, _last_cpu_times)
    # per-cpu usage
    else:
        ret = []
        if blocking:
            tot1 = get_system_per_cpu_times()
            time.sleep(interval)
        else:
            tot1 = _last_per_cpu_times
        _last_per_cpu_times = get_system_per_cpu_times()
        for t1, t2 in zip(tot1, _last_per_cpu_times):
            ret.append(calculate(t1, t2))
        return ret


def cpu_all():
    cpu_info = {}
    cpu_info['num_cpus'] = get_num_cpus()
    cpu_info['total_percent_usage'] = cpu_percent(INTERVAL)
    cpu_info['per_processor_percent_usage'] = per_processor_usage()

    return cpu_info

def per_processor_usage():
    per_processor_info = {}
    usage = cpu_percent(INTERVAL,True)
    for processor_number in range(0,get_num_cpus()):
        per_processor_info[str(processor_number+1)] = usage[processor_number]

    return  per_processor_info

#####################################CPU######################################################


if __name__ == "__main__":


    cpu_info =cpu_all()
    print "CPU: " + str(cpu_info)



