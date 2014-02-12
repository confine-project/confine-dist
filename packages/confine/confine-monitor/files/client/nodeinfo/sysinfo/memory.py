from client.nodeinfo.sysinfo.common import usage_percent, nt_virtmem_info

def get_virtual_memory():
    cached = active = inactive = None
    f = open('/proc/meminfo', 'r')
    try:
        for line in f:
            if line.startswith('MemTotal:'):
                total = int(line.split()[1])* 1024
            elif line.startswith('MemFree:'):
                free = int (line.split()[1]) * 1024
            elif line.startswith('Buffers:'):
                buffers = int (line.split()[1]) * 1024
            elif line.startswith('Cached:'):
                cached = int(line.split()[1]) * 1024
            elif line.startswith('Active:'):
                active = int(line.split()[1]) * 1024
            elif line.startswith('Inactive:'):
                inactive = int(line.split()[1]) * 1024
            if cached is not None\
               and active is not None\
            and inactive is not None:
                break
        else:
            raise RuntimeError("line(s) not found")
    finally:
        f.close()
    avail = free + buffers + cached
    used = total - free
    percent = usage_percent((total - avail), total, _round=1)
    return nt_virtmem_info(total, avail, percent, used, free, buffers, cached)

def mem_all ():
    memory = {}
    virtual_memory = get_virtual_memory()
    memory['virtual'] = {'total': virtual_memory.total,
                         'available': virtual_memory.available,
                         'percent_used': virtual_memory.percent,
                         'used': virtual_memory.used,
                         'free': virtual_memory.free}

    return memory

if __name__ == '__main__':
    print mem_all()