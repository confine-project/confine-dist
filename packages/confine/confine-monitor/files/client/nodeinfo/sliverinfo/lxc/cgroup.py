#!/usr/bin/env python
# -*- coding: utf8 -*- 

import os

class CGroupNotFound(Exception):
	pass

class CGroupNoSuchValue(Exception):
	pass

class cgroup:
	"""Get Cgroups"""
	def __init__(self, name,basepath="/cgroup/lxc"):
		self.cgroup=basepath+'/'+name
		if not os.path.isdir(self.cgroup):
			raise CGroupNotFound


	def getValue(self,name):
		try:
			return open(self.cgroup+'/'+name).read().rstrip('\n')
		except:
			raise CGroupNoSuchValue
			
