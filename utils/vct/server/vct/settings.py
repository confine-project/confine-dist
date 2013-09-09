from django.conf import settings


VCT_LOCAL_FILES = getattr(settings, 'VCT_LOCAL_FILES', True)


VCT_VM_MANAGEMENT = getattr(settings, 'VCT_VM_MANAGEMENT', True)
