#!/usr/bin/python

""" 
Author: Julia Niewiejska, Fraunhofer FKIE
Date: 16.07.2014
Task: Modify virtual interfaces in order to create connectivity between an NS3 instance and virtual nodes from the Virtual Confine Testbed.

Assumptions:
- Connectivity will be established for all running nodes, also those that are not visible in the controller (if any such nodes are present)
- Nodes are assigned to NS3 in the numerical order of their hex IDs
- eth1 is mapped to vct-direct-01, eth2 to vct-direct-02; no other interfaces are supported
- same direct interface should be used on each sliver that belongs to the same slice (either all use eth1 or all use eth2, not mixed up)
"""

import subprocess
import xml.etree.ElementTree as ET
import argparse

node_cnctvty = dict() # nodeID: 'eth1':(iface,bridge),'eth2':(iface,bridge)

def parse_domain_str(domstr):
	domains = []
	domstr_list = domstr.strip().split('\n')
	for e in domstr_list[2:]: # first 2 lines are output formatting
		id = e.split()[1] # id is on the second place
		domains.append(id[5:]) # omit 'vcrd-' at the beginning
	return domains

def hexstr_compare(x,y):
	""" Takes two hexadecimals as strings, e.g. '000a', and returns result of numerical comparison """
	xint = int(x, 16)
	yint = int(y, 16)
	return xint - yint
	
def get_nodes_info():
	""" Get a list of ids of all running nodes """
	print "Querying KVM for running nodes..."
	virsh_cmd = ["virsh", "-r", "-c", "qemu:///system"]
	list_cmd = ["list"]
	# get running domains (nodes)
	domains_str = subprocess.check_output(virsh_cmd+list_cmd)
	# parse running domains
	domains = parse_domain_str(domains_str)
	# sort numerically
	nodes = sorted(domains, cmp=hexstr_compare)
	print "Currently running nodes:", ", ".join(nodes)


	""" Now for each node get info about it and store in a dictionary """
	print "Querying KVM for detailed node information..."
	for nodeID in nodes:
	    print "NODE", nodeID
	    dominfo_cmd = ["dumpxml", "vcrd-"+nodeID]
	    xmldump = subprocess.check_output(virsh_cmd+dominfo_cmd)
	    root = ET.fromstring(xmldump)
	    node_cnctvty[nodeID]={'eth1':None,'eth2':None}
	    for iface in root.iter('interface'):
		mac = iface.find('mac').get('address')
		br = iface.find('source').get('bridge')
		ifname = iface.find('target').get('dev')
		print "IF:", ifname, "MAC:", mac, "BR:", br
		if br == 'vct-direct-01': eth='eth1'
		elif br == 'vct-direct-02': eth='eth2'
		else: continue
		node_cnctvty[nodeID][eth]=(ifname, br)
	print "...done."

""" Define commands for creating and restoring connectivity """
brctl = ['sudo', 'brctl']
delif = brctl+['delif']
delbr = brctl+['delbr']
addbr = brctl+['addbr']
addif = brctl+['addif']
ifconf = ['sudo', 'ifconfig']
tun = ['sudo', 'tunctl']
ipadd = ['sudo', 'ip', 'link', 'add', 'link']
ipdel = ['sudo', 'ip', 'link', 'del', 'link']
ipvlan = ['type', 'vlan', 'id']


def create_connectivity(vlan, iface):
	print "= Creating NS3 connectivity using following configuration:"
	print "= VLAN ID:", vlan
	print "= Node direct interface:", iface
	i=0
	for node in sorted(node_cnctvty.keys()):
		ifname, br = node_cnctvty[node][iface]
		print "************* Processing node", node, "*************"
		try:
			print "Deleting %s from bridge %s..."%(ifname, br)
			subprocess.check_call(delif+[br, ifname])
			print "OK"
			print "Creating necessary bridges and interfaces..."
			subprocess.check_output(ipadd+[ifname, ifname+"."+str(vlan)]+ipvlan+[str(vlan)])
			print subprocess.check_output(tun+['-t', 'tap'+str(i)])
			subprocess.check_output(addbr+['br-'+str(i)])
			subprocess.check_output(addif+['br-'+str(i), ifname+"."+str(vlan)])
			subprocess.check_output(addif+['br-'+str(i), "tap"+str(i)])
			subprocess.check_output(ifconf+['br-'+str(i), 'up'])
			subprocess.check_output(ifconf+['tap'+str(i), 'up'])
			subprocess.check_output(ifconf+[ifname+"."+str(vlan), 'up'])
			print "OK"
		except subprocess.CalledProcessError, e:
			print "======"
			print "Failed while calling:", e.cmd
			print "Return Code:", e.returncode
			print "Command output:"
			print e.output
			print "======="
			print "It is recommended to use the script with --restore to revert the changes."
			print "Aborting..."
			return
		i+=1

def restore_connectivity(vlan, iface):
	print "= Reverting changes done for NS3 connectivity using following configuration:"
	print "= VLAN ID:", vlan
	print "= Node direct interface:", iface
	i=0
	for node in sorted(node_cnctvty.keys()):
		ifname, br = node_cnctvty[node][iface]
		commands = [	ifconf+['br-'+str(i), 'down'],
				ifconf+['tap'+str(i), 'down'],
				ifconf+[ifname+"."+str(vlan), 'down'],
				delbr+['br-'+str(i)],
				ipdel+[ifname, ifname+"."+str(vlan)]+ipvlan+[str(vlan)],
				tun+['-d', 'tap'+str(i)],
				addif+[br, ifname]]
				
		print "************* Processing node", node, "*************"
		print "Removing added bridges and interfaces..."
		for cmd in commands:
			try:
				print " ".join(cmd)
				subprocess.check_output(cmd)
				print "OK"
			except subprocess.CalledProcessError, e:
				print "======"
				print "Failed while calling:", e.cmd
				print "Return Code:", e.returncode
				print "Command output:"
				print e.output
				print "======"
		i+=1


if __name__ == "__main__":
	
	# Parse command line parameters
	parser = argparse.ArgumentParser()
	parser.add_argument("--restore", help="Restore initial connectivity instead of creating a new one", 
						action="store_true")
	parser.add_argument("--vlan", help="VLAN ID of the relevant slice [default: 256]", type=int, default=256)
	parser.add_argument("-i", "--interface", help="Node's direct interface used to connect to NS3 [default: eth1]",
						choices=['eth1', 'eth2'], default='eth1')
	# TODO could extend by an option to choose relevant nodes
	args = parser.parse_args()
	vlanID = args.vlan
	restore = args.restore
	iface = args.interface

	# Fill node connectivity data
	get_nodes_info()

	if restore:
		restore_connectivity(vlanID, iface)
	else:
		create_connectivity(vlanID, iface)

