"""
Django settings for VCT server.

For more information on this file, see
https://docs.djangoproject.com/en//topics/settings/

For the full list of settings and their values, see
https://docs.djangoproject.com/en//ref/settings/
and particulary for this project:
$ find /usr/local/lib/python2.6/dist-packages/controller/ -iname '*settings.py'|xargs cat|grep "getattr(settings,"
"""

from controller.utils import add_app, remove_app
from vct.utils import get_vct_config
# Production settings
from controller.conf.production_settings import *
# Development settings
# from controller.conf.devel_settings import *

VCT_SERVER_ROOT = get_vct_config('VCT_SERVER_DIR')


# SECURITY WARNING: keep the secret key used in production secret!
# Hardcoded values can leak through source control. Consider loading
# the secret key from an environment variable or a file instead.
SECRET_KEY = '+2fsh4on!v(*y4w5!_+m-9lq(rnr)(m&#4wpwircv_b=m&&9(='

ROOT_URLCONF = 'server.urls'

WSGI_APPLICATION = 'server.wsgi.application'


# Database
# https://docs.djangoproject.com/en//ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2', # Add 'postgresql_psycopg2', 'mysql', 'sqlite3' or 'oracle'.
        'NAME': 'controller',      # Or path to database file if using sqlite3.
        'USER': 'confine',         # Not used with sqlite3.
        'PASSWORD': 'confine',     # Not used with sqlite3.
        'HOST': 'localhost',       # Set to empty string for localhost. Not used with sqlite3.
        'PORT': '5432',                # Set to empty string for default. Not used with sqlite3.
    }
}


# Absolute filesystem path to the directory that will hold user-uploaded files.
# Example: "/home/media/media.lawrence.com/media/"
MEDIA_ROOT = os.path.join(VCT_SERVER_ROOT, 'media')
PRIVATE_MEDIA_ROOT = os.path.join(VCT_SERVER_ROOT, 'private')


# Absolute path to the directory static files should be collected to.
# Don't put anything in this directory yourself; store your static files
# in apps' "static/" subdirectories and in STATICFILES_DIRS.
# Example: "/home/media/media.lawrence.com/static/"
STATIC_ROOT = os.path.join(VCT_SERVER_ROOT, 'static')

# Install / uninstall modules
INSTALLED_APPS = add_app(INSTALLED_APPS, 'vct', prepend=True)
INSTALLED_APPS = remove_app(INSTALLED_APPS, 'gis')
INSTALLED_APPS = remove_app(INSTALLED_APPS, 'issues')
INSTALLED_APPS = remove_app(INSTALLED_APPS, 'registration')
INSTALLED_APPS = remove_app(INSTALLED_APPS, 'communitynetworks')

# Confine params
DEBUG_IPV6_PREFIX = get_vct_config('VCT_CONFINE_DEBUG_IPV6_PREFIX48') + '::/48'
PRIV_IPV6_PREFIX = get_vct_config('VCT_CONFINE_PRIV_IPV6_PREFIX48') + '::/48'

# Testbed params
PRIV_IPV4_PREFIX_DFLT = get_vct_config('VCT_TESTBED_PRIV_IPV4_PREFIX24') + '.0/24'
SLIVER_MAC_PREFIX_DFLT = '0x' + get_vct_config('VCT_TESTBED_MAC_PREFIX16')[0:2] + get_vct_config('VCT_TESTBED_MAC_PREFIX16')[3:6]
MGMT_IPV6_PREFIX = get_vct_config('VCT_TESTBED_MGMT_IPV6_PREFIX48') + '::/48'

# Nodes
NODES_NODE_LOCAL_IFACE_DFLT = get_vct_config('VCT_NODE_LOCAL_IFNAME')
NODES_NODE_ARCH_DFLT = 'i686'
NODES_NODE_ARCHS = (('i686', 'i686'),)

# Firmware generation
FIRMWARE_BUILD_PATH = get_vct_config('VCT_SYS_DIR')
FIRMWARE_BASE_IMAGE_PATH = get_vct_config('VCT_DL_DIR')

# Tinc
TINC_TINCD_ROOT = get_vct_config('VCT_TINC_DIR')
TINC_NET_NAME = get_vct_config('VCT_TINC_NET')
TINC_PORT_DFLT = get_vct_config('VCT_SERVER_TINC_PORT')

# Slices and slivers
SLICES_TEMPLATE_IMAGE_DIR = os.path.join(MEDIA_ROOT, 'templates') # VCT_DL_DIR
SLICES_SLICE_EXP_DATA_DIR = os.path.join(PRIVATE_MEDIA_ROOT, 'exp_data')


# TODO add support for:
#   VCT_NODE_ISOLATED_PARENTS="eth1 eth2 wlan0 wlan1"  
#   VCT_NODE_RD_PUBLIC_IPV4_PROTO=dhcp       # dhcp or static 
#   VCT_NODE_SL_PUBLIC_IPV4_PROTO=dhcp       # dhcp or static and following addresses
#   VCT_NODE_PUBLIC_IPV4_AVAIL="8"
