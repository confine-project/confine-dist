import sys
import psutil
from psutil._compat import print_

INTERVAL = 1 #Node monitoring period must be greater than INTERVAL*2 seconds

def cpu_all():
    cpu_info = {}
    cpu_info['num_cpus'] = psutil.NUM_CPUS
    cpu_info['total_percent_usage'] = psutil.cpu_percent(INTERVAL)
    cpu_info['per_processor_percent_usage'] = per_processor_usage()

    return cpu_info

def per_processor_usage():
    per_processor_info = {}
    usage = psutil.cpu_percent(INTERVAL,True)
    for processor_number in range(0,psutil.NUM_CPUS):
        per_processor_info[str(processor_number+1)] = usage[processor_number]

    return  per_processor_info