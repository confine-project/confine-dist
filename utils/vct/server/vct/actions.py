from django.template.response import TemplateResponse

from firmware.actions import get_firmware
from firmware.models import Build

from vct.utils import vct_node, get_vct_node_state


def vm_management(modeladmin, request, queryset):
    INFO = ('info', 'VM Info', 'Node virtual machine information')
    BUILD = ('build', 'Build FW', 'Build firmware for this node')
    CREATE = ('create', 'Create VM', 'Create node virtual machine')
    START = ('start', 'Start VM', 'Start node virtual machine')
    STOP = ('stop', 'Stop VM', 'Stop node virtual machine')
    REMOVE = ('remove', 'Remove VM', 'Remove node virtual machine')
    DELETE = ('delete', 'Delete FW', 'Delete node firmware')

    name = request.GET.get('cmd', 'info')
    if name == 'build':
        response = get_firmware(modeladmin, request, queryset)
        if response.template_name != 'admin/firmware/download_build.html':
            return response
    
    node = queryset.get()
    node_id = hex(node.id).split('0x')[1]
    node_id = '0'*(4-len(node_id)) + node_id
    cmd = None
    commands = [BUILD]
    
    try:
        build = node.firmware_build
    except Build.DoesNotExist:
        build = None
    else:
        if name == 'delete':
            build.delete()
            build = None
    
    if name in ['create', 'start', 'stop', 'remove']:
        cmd = vct_node(name, node)
    
    info = vct_node('info', node)
    
    if build:
        state = get_vct_node_state(node)
        
        commands = [INFO]
        if build.state in [Build.DELETED, Build.OUTDATED, Build.FAILED]:
            commands += [BUILD]
        
        if state == 'running':
            commands += [STOP, REMOVE, DELETE]
        elif state == 'down':
            commands += [START, REMOVE, DELETE]
        else:
            info = None
            if name not in ['remove', 'create']:
                cmd = None
            commands = [DELETE]
            if build.state != Build.FAILED:
                commands = [CREATE, DELETE]
    else:
        info = None
    
    opts = modeladmin.model._meta
    app_label = opts.app_label
    context = {
        'build': build,
        'node': node,
        'node_id': node_id,
        'cmds': commands,
        'info': info,
        'cmd': cmd,
        'cmd_name': name,
        'queryset': queryset,
        'node': node,
        "opts": opts,
        "app_label": app_label,}
    
    return TemplateResponse(request, 'admin/vct/command.html', context,
            current_app=modeladmin.admin_site.name)
vm_management.short_description = 'VCT node management'
vm_management.verbose_name = 'VM management'
vm_management.css_class = 'viewsitelink'
vm_management.description = 'Manage VCT virtual machines.'
vm_management.url_name = 'vct'
