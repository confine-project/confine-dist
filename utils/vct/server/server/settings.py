"""
Django settings for VCT server.

For more information on this file, see
https://docs.djangoproject.com/en//topics/settings/

For the full list of settings and their values, see
https://docs.djangoproject.com/en//ref/settings/
and particulary for this project:
$ find /usr/local/lib/python2.6/dist-packages/controller/ -iname '*settings.py'|xargs cat|grep "getattr(settings,"
"""

from django.core.files.storage import FileSystemStorage

from controller.utils import add_app, remove_app
from vct.utils import get_vct_config
# Production settings
#from controller.conf.production_settings import *
# Development settings
from controller.conf.devel_settings import *


# When DEBUG is enabled Django appends every executed SQL statement to django.db.connection.queries
# this will grow unbounded in a long running process environment like celeryd
if "celeryd" in sys.argv:
    DEBUG = False


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
#MEDIA_ROOT = os.path.join(VCT_SERVER_ROOT, 'media')
MEDIA_ROOT = get_vct_config('VCT_DL_DIR')
PRIVATE_MEDIA_ROOT = os.path.join(VCT_SERVER_ROOT, 'private')


# Absolute path to the directory static files should be collected to.
# Don't put anything in this directory yourself; store your static files
# in apps' "static/" subdirectories and in STATICFILES_DIRS.
# Example: "/home/media/media.lawrence.com/static/"
STATIC_ROOT = os.path.join(VCT_SERVER_ROOT, 'static')


# Install / uninstall modules
INSTALLED_APPS = add_app(INSTALLED_APPS, 'vct')
INSTALLED_APPS = remove_app(INSTALLED_APPS, 'gis')
INSTALLED_APPS = remove_app(INSTALLED_APPS, 'captcha')
INSTALLED_APPS = remove_app(INSTALLED_APPS, 'django_google_maps')
INSTALLED_APPS = remove_app(INSTALLED_APPS, 'issues')
INSTALLED_APPS = remove_app(INSTALLED_APPS, 'registration')
INSTALLED_APPS = remove_app(INSTALLED_APPS, 'communitynetworks')

# Confine params
DEBUG_IPV6_PREFIX = get_vct_config('VCT_CONFINE_DEBUG_IPV6_PREFIX48') + '::/48'
PRIV_IPV6_PREFIX = get_vct_config('VCT_CONFINE_PRIV_IPV6_PREFIX48') + '::/48'

# Testbed params
PRIV_IPV4_PREFIX_DFLT = get_vct_config('VCT_TESTBED_PRIV_IPV4_PREFIX24') + '.0/24'
SLIVER_MAC_PREFIX_DFLT = '0x{0}{1}{3}{4}'.format(*get_vct_config('VCT_TESTBED_MAC_PREFIX16'))
MGMT_IPV6_PREFIX = get_vct_config('VCT_TESTBED_MGMT_IPV6_PREFIX48') + '::/48'

# Nodes
NODES_NODE_LOCAL_IFACE_DFLT = get_vct_config('VCT_NODE_LOCAL_IFNAME')
NODES_NODE_ARCH_DFLT = 'i686'
NODES_NODE_SLIVER_PUB_IPV4_DFLT = get_vct_config('VCT_NODE_SL_PUBLIC_IPV4_PROTO')
NODES_NODE_SLIVER_PUB_IPV4_RANGE_DFLT = '#%s' % get_vct_config('VCT_NODE_PUBLIC_IPV4_AVAIL')
NODES_NODE_DIRECT_IFACES_DFLT = get_vct_config('VCT_NODE_ISOLATED_PARENTS').split(' ')

# Firmware generation
FIRMWARE_BUILD_IMAGE_STORAGE = FileSystemStorage(location=get_vct_config('VCT_SYS_DIR'))
FIRMWARE_BUILD_IMAGE_PATH = '.'
FIRMWARE_BASE_IMAGE_PATH = '.'

# Tinc
TINC_TINCD_ROOT = get_vct_config('VCT_TINC_DIR')
TINC_NET_NAME = get_vct_config('VCT_TINC_NET')
TINC_PORT_DFLT = get_vct_config('VCT_SERVER_TINC_PORT')

# Slices and slivers
SLICES_TEMPLATE_IMAGE_DIR = '.'
SLICES_TEMPLATE_IMAGE_NAME = None
SLICES_SLICE_EXP_DATA_DIR = '.'
SLICES_SLICE_EXP_DATA_NAME = None
SLICES_SLIVER_EXP_DATA_DIR = '.'
SLICES_SLIVER_EXP_DATA_NAME = None
SLICES_TEMPLATE_ARCH_DFLT = 'i686'

# State
STATE_NODESTATE_SCHEDULE = 10
STATE_NODESTATE_EXPIRE_WINDOW = 150
STATE_SLIVERSTATE_SCHEDULE = 10
STATE_SLIVERSTATE_EXPIRE_WINDOW = 150

# Public Key Infrastructure
PKI_CA_PRIV_KEY_PATH = os.path.join(VCT_SERVER_ROOT, 'pki/ca/key.priv')
PKI_CA_PUB_KEY_PATH = os.path.join(VCT_SERVER_ROOT, 'pki/ca/key.pub')
PKI_CA_CERT_PATH = os.path.join(VCT_SERVER_ROOT, 'pki/ca/cert')

# Maintenance operations
MAINTENANCE_KEY_PATH = os.path.join(get_vct_config('VCT_KEYS_DIR'), 'id_rsa')
MAINTENANCE_PUB_KEY_PATH = os.path.join(get_vct_config('VCT_KEYS_DIR'), 'id_rsa.pub')

# Branding
SITE_NAME = 'VCT'
SITE_VERBOSE_NAME = 'VCT Testbed Management'

