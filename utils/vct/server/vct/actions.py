from django.template.response import TemplateResponse

from controller.utils.system import run
from firmware.actions import get_firmware
from firmware.models import Build


INFO = ('info', 'VM Info', 'Node virtual machine information')
BUILD = ('build', 'Build FW', 'Build firmware for this node')
CREATE = ('create', 'Create VM', 'Create node virtual machine')
START = ('start', 'Start VM', 'Start node virtual machine')
STOP = ('stop', 'Stop VM', 'Stop node virtual machine')
REMOVE = ('remove', 'Remove VM', 'Remove node virtual machine')
DELETE = ('delete', 'Delete FW', 'Delete node firmware')


def vct(modeladmin, request, queryset):
    name = request.GET.get('cmd', 'info')
    if name == 'build':
        response = get_firmware(modeladmin, request, queryset)
        if response.template_name != 'admin/firmware/download_build.html':
            return response
    node = queryset.get()
    node_id = hex(node.id).split('0x')[1]
    node_id = '0'*(4-len(node_id)) + node_id
    wrapper = 'cd /home/vct/confine-dist/utils/vct/; ./%s; cd - &> /dev/null'
    cmd = None
    commands = [BUILD]
    
    try:
        build = node.firmware_build
    except Build.DoesNotExist:
        build = None

    if name != 'info':
        cmd = 'vct_node_%s %s' % (name, node_id)
        cmd = run(wrapper % cmd, display=False)
    if name == 'delete' and build:
        build.delete()
        build = None
    
    info = 'vct_node_info %s' % node_id
    info = run(wrapper % info, display=False)
    
    if build:
        state = info.stdout.splitlines()[-1]
        state = state.split(' ')[1] if not state.startswith('-----') else False
        
        commands = [INFO]
        if build.state in [Build.DELETED, Build.OUTDATED, Build.FAILED]:
            commands += [BUILD]
        
        if state == 'running':
            commands += [STOP, REMOVE, DELETE]
        elif state == 'down':
            commands += [START, REMOVE, DELETE]
        else:
            info = None
            if name != 'remove':
                cmd = None
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
vct.short_description = 'VCT Node Management'
vct.verbose_name = 'VM Management'
vct.css_class = 'viewsitelink'
