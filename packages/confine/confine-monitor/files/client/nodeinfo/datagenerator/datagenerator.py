import psutil
from client.nodeinfo.systeminfo import nodeinfo

def collectMemory(container):
    virtual_memory = psutil.virtual_memory()
    return {'memory':{'total_rss':virtual_memory.total , 'total_cache': virtual_memory.available , 'total_swap': virtual_memory.used}}


def collectCpu(container):
    return {'cpu':{'cpu_usage': psutil.cpu_percent(0.1)}}

def getName(container):
    slice_name = ''
    rd_name = ''

    return {'sliver_name': 'sliver-'+ str(container), 'slice_name': 'slice-'+ str(container)}


def collectData(container):
    container_info = {}
    all_info = {}

    container_info['container'] = str(container)
    container_info.update(collectMemory(container))
    container_info.update(collectCpu(container))
    container_info.update(getName(container))

    all_info[str(container)] = container_info
    #    print all_info.items()
    return all_info



def collectAllData_fake():
    container_info = {}
    all_info = {}

    for container in range(0,4):
        container_info.update(collectData(container))

    all_info['slivers'] = container_info

    print all_info.items()
    return all_info

def main():
    collectAllData_fake()


if __name__ == "__main__":
    main()


def get_fake_sliver_data():
    system_info = nodeinfo.node_all()



if __name__ == '__main__':
    get_fake_sliver_data()