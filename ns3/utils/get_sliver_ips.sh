#!/usr/bin/python

"""
Author: Henning Rogge, Fraunhofer FKIE
Date: 16.07.2014
Task: Extract management IPv6 addresses of all slivers for a given slice through the REST API.
"""

import json
import urllib
import sys

slice_url = "http://localhost:80/api/slices/" + sys.argv[1] + "?format=json"
slice_data = urllib.urlopen(slice_url, proxies={})

slice_json = json.loads(slice_data.read())

for slivers_url in slice_json['slivers']:
	sliver_local_data = urllib.urlopen(slivers_url['uri'], proxies={})
	sliver_local_json = json.loads(sliver_local_data.read())

	node_local_url = sliver_local_json['node']['uri']
	node_local_data = urllib.urlopen(node_local_url, proxies={})
	node_local_json = json.loads(node_local_data.read())

	node_mgmt = node_local_json['mgmt_net']['addr']

	sliver_remote_url = "http://[" + node_mgmt + "]/confine/api/slivers/" + sliver_local_json['uri'].split('/')[-1]
	sliver_remote_data = urllib.urlopen(sliver_remote_url, proxies={})
	sliver_remote_json = json.loads(sliver_remote_data.read())

	for interf in sliver_remote_json['interfaces']:
		if interf['type'] == "management":
			print interf['ipv6_addr']
#	print json.dumps(node_local_json, sort_keys=True, indent=4, separators=(',', ': '))
