import psutil
from psutil._compat import print_

def to_meg(n):
    return str(int(n / 1024 / 1024)) + "M"

def pprint_ntuple(nt):
    for name in nt._fields:
        value = getattr(nt, name)
        if name != 'percent':
            value = to_meg(value)
        print_('%-10s : %7s' % (name.capitalize(), value))


def mem_all ():
    memory = {}
    virtual_memory = psutil.virtual_memory()
    memory['virtual'] = {'total': virtual_memory.total,
                         'available': virtual_memory.available,
                         'percent_used': virtual_memory.percent,
                         'used': virtual_memory.used,
                         'free': virtual_memory.free}

    return memory

def main():
    print_('MEMORY\n------')
    pprint_ntuple(psutil.virtual_memory())
    print_('\nSWAP\n----')
    pprint_ntuple(psutil.swap_memory())

if __name__ == '__main__':
    main()
