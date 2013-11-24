from django.views import debug
debug.TECHNICAL_500_TEMPLATE = """<!--{% load firstof from future %}{% firstof exception_type 'Report' %}{% if request %} at {{ request.path_info }}{% endif %}:
{% firstof exception_value 'No exception message supplied' %}-->"""+debug.TECHNICAL_500_TEMPLATE
