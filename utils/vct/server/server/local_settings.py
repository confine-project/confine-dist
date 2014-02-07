from controller.utils.apps import add_app, remove_app
from settings import *

INSTALLED_APPS = remove_app(INSTALLED_APPS, 'monitor')                                                                    
