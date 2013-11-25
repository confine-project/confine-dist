from django.views import debug
debug.TECHNICAL_500_TEMPLATE = """<!--{{ exception_type }}{% if request %} at {{ request.path_info }}{% endif %}:
{{ exception_value }} {{ lastframe.filename|escape }} in {{ lastframe.function|escape }}, line {{ lastframe.lineno }}-->"""+debug.TECHNICAL_500_TEMPLATE
