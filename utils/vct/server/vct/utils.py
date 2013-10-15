from os import path

from controller.utils.system import run


def get_vct_root():
    return path.abspath(path.join(path.dirname(path.realpath(__file__)), '../..'))


def get_vct_config(var):
    """ Get options from vct config file """
    vct_root = get_vct_root()
    context = {
        'var': var,
        'source': """
            if [ -f %(vct_root)s/vct.conf.overrides ]; then
               . %(vct_root)s/vct.conf.default
               . %(vct_root)s/vct.conf.overrides
            elif [ -f %(vct_root)s/vct.conf ]; then
               . %(vct_root)s/vct.conf
            elif [ -f %(vct_root)s/vct.conf.default ]; then
               . %(vct_root)s/vct.conf.default
            fi """ % { 'vct_root': vct_root} }
    out = run("bash -c '%(source)s; echo $%(var)s'" % context, display=False, silent=False)
    return out.stdout


def vct_node(action, node):
    node_id = hex(node.id).split('0x')[1]
    node_id = '0'*(4-len(node_id)) + node_id
    wrapper = path.join(get_vct_root(), '%s')
    cmd = 'vct_node_%s %s' % (action, node_id)
    return run(wrapper % cmd, display=False)


def get_vct_node_state(node):
    info = vct_node('info', node)
    try:
        state = info.stdout.splitlines()[-1]
        return state.split(' ')[1] if not state.startswith('-----') else False
    except IndexError:
        return False
