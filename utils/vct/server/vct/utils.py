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
