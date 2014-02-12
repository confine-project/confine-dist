import string
import sys, os
from client.nodeinfo.sysinfo import disk, memory, network, cpu

PROC_UPTIME_PATH = "/proc/uptime"

def get_uptime (vars ={}, log = sys.stderr):
    try:
        uptime_file = file(PROC_UPTIME_PATH, "r")
    except IOError, e:
        return

    for line in uptime_file:
        try:
            uptime_list = string.split(line)
        except ValueError, e:
            return

    uptime = float (uptime_list[0])
    uptime_file.close()
    return uptime


def load_avg_all():
    # Gives an error on openwrt
    load_avg = {}
    av1, av2, av3 = os.getloadavg()
    load_avg ['load_avg_1min'] = av1
    load_avg ['load_avg_5min'] = av2
    load_avg ['load_avg_15min'] = av3

    return load_avg


PROC_LOADAVG_PATH = "/proc/loadavg"
def get_load_avg(vars ={}, log = sys.stderr):
    try:
        loadavg_file = file(PROC_LOADAVG_PATH, "r")
    except IOError, e:
        return

    for line in loadavg_file:
        try:
            loadavg_list = string.split(line)
        except ValueError, e:
            return

    tasks = string.split(loadavg_list[3], "/")
    load_avg = {'load_avg_1min': float(loadavg_list[0]),'load_avg_5min': float(loadavg_list[1]), 'load_avg_15min': float(loadavg_list[2]), 'Tasks scheduled to Run': int(tasks[0]), 'Total number of tasks':int(tasks[1])}
    loadavg_file.close()
    return load_avg

def node_all():
    all_info = {}
    disk_info = disk.disk_all()
    network_info = network.network_all()
    memory_info = memory.mem_all()
    uptime = get_uptime()
    load_avg = get_load_avg()
    cpu_info = cpu.cpu_all()

    all_info['disk'] = disk_info
    all_info['network'] = network_info
    all_info['memory'] = memory_info
    all_info['uptime'] = uptime
    all_info[ 'load_avg' ] = load_avg
    all_info[ 'cpu' ] = cpu_info

    return all_info

if __name__ == '__main__':
    print node_all()
