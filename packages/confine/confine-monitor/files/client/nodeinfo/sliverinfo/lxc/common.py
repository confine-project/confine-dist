from collections import namedtuple

nt_sliver_info = namedtuple('sliver', 'container sliceid sliverid state management_ip')

def parse_api_sliver(json):
    temp_container = json['nr']

    if temp_container:
        container = str(temp_container).zfill(2)
    else:
        container = "None"

    sliceid = str.split(str(json['slice']['uri']) , '/')[-1]
    sliverid = str.split(str(json['uri']) , '/')[-1]
    state = json['state']
    management_ip = "None"
    for interface in json['interfaces']:
        if interface['type'] == 'management':
            if interface.has_key('ipv6_addr'):
                management_ip = interface['ipv6_addr']

    return nt_sliver_info(container, sliceid,sliverid,state,management_ip)
