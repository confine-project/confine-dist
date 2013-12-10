from subprocess import check_output
from client.nodeinfo.sliverinfo import lxc
from client.nodeinfo.sliverinfo.lxc import utils

def collectData(container):
    container_info = {}
    all_info = {}

    container_info['container'] = container
    container_info.update(utils.container_mem_usage(container))
    container_info.update(utils.container_cpu_usage(container))
    container_info.update(utils.get_name(container))

    all_info[container] = container_info
    #    print all_info.items()
    return all_info


def collectAllData():
    container_info = {}
    all_info = {}

    container_list = lxc.utils.getRunningContainers()
    print 'Monitoring all started containers: '
    for container in container_list:
        if not "7d" in container:
            container_info.update(collectData(container))

    all_info['slivers'] = container_info

    print all_info.items()
    return all_info




def collectDataAPI(container, slice_name, sliver_name, state, management_ip):
    container_info = {}
    all_info = {}
    print container
    if container != 'None' and state == 'started':
        container_info['container'] = container
        container_info.update(utils.container_mem_usage(container))
        container_info.update(utils.container_cpu_usage(container))

    container_info.update({'sliver_name': sliver_name, 'slice_name': slice_name, 'state': state, 'management_ip': management_ip})

    all_info[container] = container_info
    #    print all_info.items()
    return all_info

def collectAllDataAPI():
    #Monitors only slivers and not other running containers
    container_info = {}
    all_info = {}

    sliver_list = utils.get_sliver_info_from_API()

    print 'Monitoring all started containers: '
    if sliver_list:
        for sliver in sliver_list:
               container_info.update(collectDataAPI(sliver.container, sliver.sliceid, sliver.sliverid,sliver.state, sliver.management_ip))

        all_info['slivers'] = container_info

    print all_info.items()
    return all_info

#collectAllDataAPI()

