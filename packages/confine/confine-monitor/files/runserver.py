import sys
from common import view
from  client.nodeinfo.sysinfo import getip

view.main(host= getip.get_ip6('confine'), port=8080)
