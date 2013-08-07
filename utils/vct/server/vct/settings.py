from django.conf import settings


VCT_ENABLE_LOCAL_FILES = getattr(settings, 'VCT_ENABLE_LOCAL_FILES', True)


VCT_ENABLE_VM_MANAGEMENT = getattr(settings, 'VCT_ENABLE_VM_MANAGEMENT', True)
