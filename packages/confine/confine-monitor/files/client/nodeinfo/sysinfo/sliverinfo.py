
import argparse
from time import gmtime, strftime, localtime, sleep
from subprocess import check_output



def collectMemory(container):
    mem_rss = 0
    mem_cache = 0
    mem_swap = 0

    with open('/cgroup/lxc/%s/memory.stat' % (container,), 'r') as f:
        lines = f.read().splitlines()

    for line in lines:
        data = line.split()
        if data[0] == "total_rss":
            mem_rss = data[1]
        elif data[0] == "total_cache":
            mem_cache = data[1]
        elif data[0] == "total_swap":
            mem_swap = data[1]

    with open('/cgroup/lxc/%s/memory.usage_in_bytes' % (container,), 'r') as f:

        for line in f.readline():
            mem_usage = line

    return {'memory':{'total_rss': mem_rss, 'total_cache': mem_cache, 'total_swap': mem_swap, 'mem_usage': mem_usage}}


def collectCpu(container):
    cpu_usage = 0
    with open('/cgroup/lxc/%s/cpuacct.usage' % (container,), 'r') as f:
        cpu_usage = f.readline()
        cpu_usage = cpu_usage.rstrip('\n')

    return {'cpu':{'cpu_usage': cpu_usage}}

def getName(container):
    slice_name = ''
    rd_name = ''

    with open('/lxc/images/%s/config' % (container,), 'r') as f:
        line = f.readline()
        info = line.split('=')
        (rd_name,slice_name) = info[-1].split('_')

    return {'sliver_name': rd_name, 'slice_name': slice_name}


def collectData(container):
    container_info = {}
    all_info = {}

    container_info['container'] = container
    container_info.update(collectMemory(container))
    container_info.update(collectCpu(container))
    container_info.update(getName(container))

    all_info[container] = container_info
#    print all_info.items()
    return all_info


def unique_list(l):
    ulist = []
    [ulist.append(x) for x in l if x not in ulist]

    return ulist

def collectAllData():
    container_info = {}
    all_info = {}

    line=check_output(["ls", "/lxc/images"])
    container_list=' '.join(unique_list(line.split()))
    print 'Monitoring all started containers: '
    for container in container_list.split(' '):
        if not "7d" in container:
            container_info.update(collectData(container))

    all_info['slivers'] = container_info

    print all_info.items()
    return all_info

def main():
    collectAllData()


if __name__ == "__main__":
    main()