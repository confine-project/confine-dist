from __future__ import division
import os
import time
from client.nodeinfo.sliverinfo.lxc.cgroup import cgroup
from client.nodeinfo.sliverinfo import lxc
import sys
from client.nodeinfo.sysinfo.common import usage_percent
import urllib2
import json
import common

interval =1

def getRunningContainers():
    containers, lxcdir = [], []

    if(os.path.exists(lxc.basepath)):
        lxcdir=os.listdir(lxc.basepath)

    else:
        return containers

    for entry in lxcdir:
        if os.path.isdir(os.path.join(lxc.basepath, entry)):
            containers.append(entry)

    ret = get_container_that_are_slivers(containers)

    return ret


def get_container_that_are_slivers(containers):

    ret = []

    for entry in containers:
        if os.path.exists(os.path.join(lxc.imagepath, entry)):
            ret.append(entry)

    return ret


def byte2MiByte(val):
    return val/1024/1024

def container_mem_usage(name):
    inst = cgroup(name)

    memlimit = int(inst.getValue("memory.limit_in_bytes"))
    memswlimit = int(inst.getValue("memory.memsw.limit_in_bytes"))
    memused = int(inst.getValue("memory.usage_in_bytes"))
    memswused = int(inst.getValue("memory.memsw.usage_in_bytes"))

    mem_total = memlimit
    mem_used = memused
    mem_free = memlimit-memused
    mem_percent_used = usage_percent(mem_used, mem_total, _round=1)

    swap_total = memswlimit-memlimit
    swap_used = memswused-memused
    swap_free = swap_total -swap_used
    swap_percent_used = usage_percent(swap_used, swap_total, _round=1)

    total = memswlimit
    total_used = memswused
    total_free = memswlimit-memswused

    total_percent_used = usage_percent(total_used, total, _round=1)


    return {'memory':{'mem_total': mem_total, 'mem_used': mem_used, 'mem_free': mem_free, 'mem_percent_used': mem_percent_used,
                      'swap_total':swap_total, 'swap_used': swap_used, 'swap_free': swap_free, 'swap_percent_used': swap_percent_used,
                      'total': total, 'total_used': total_used, 'total_free': total_free, 'total_percent_used': total_percent_used}}


def container_cpu_usage(name):
    inst = cgroup(name)
    previous_cpu_usage = inst.getValue("cpuacct.usage")
    time.sleep(interval)
    current_cpu_usage = inst.getValue("cpuacct.usage")
    diff_cpu_usage = int(current_cpu_usage) - int(previous_cpu_usage)
    cpu_usage = float(diff_cpu_usage/(interval*1000000000))*100
    return {'cpu':{'cpu_usage': cpu_usage}}


def get_name(container):
    slice_name = ''
    sliver_name = ''

    if (os.path.exists('/lxc/images/%s/config' % (container,))):
        with open('/lxc/images/%s/config' % (container,), 'r') as f:
            line = f.readline()
            if line.startswith('lxc.utsname'):
                line= line.replace("\n"," ")
                info = line.split('=')
                sliver_name = info[-1]
                sliver_name = sliver_name.strip()
                (slice_name,node_name) = sliver_name.split('_')


    return {'sliver_name': sliver_name, 'slice_name': slice_name}


def get_sliver_info_from_API():

        sliver_info = []
        request = urllib2.Request('http://127.0.0.1/confine/api/node/')
        response= None
        try:
            response = urllib2.urlopen(request)
        except:
            response = None


        if(response is None):
            return None
        
        print "Response: "+ str(response)
        page = json.loads(response.read())

        for sliver in page['slivers']:
            try:
                response = urllib2.urlopen(urllib2.Request(sliver['uri']))
            except:
                response = None

            if response:
                sliver_info.append(common.parse_api_sliver(json.loads(response.read())))

        #print sliver_info
        return sliver_info


