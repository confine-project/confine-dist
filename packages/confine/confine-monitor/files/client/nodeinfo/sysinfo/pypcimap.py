#!/usr/bin/python -tt
# Copyright 2007 The Trustees of Princeton University
# Author: Daniel Hokka Zakrisson
# $Id$
# vim:ts=4:expandtab
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met: 
# 
# * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#       
# * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following
# disclaimer in the documentation and/or other materials provided
# with the distribution.
#       
# * Neither the name of the copyright holder nor the names of its
# contributors may be used to endorse or promote products derived
# from this software without specific prior written permission.
#       
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL PRINCETON
# UNIVERSITY OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
# OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
# WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE. 

import os
import re

# These are modules which are only returned if no other driver is available
greylist = ["ata_generic", "eepro100", "8139cp"]

class PCIMap:
    """Encapsulates modules.pcimap"""
    def __init__(self, filename):
        self.list = []
        self.read(filename)
    def get(self, tuple):
        """Returns a list of candidate modules for the PCI device specified in tuple"""
        ret = []
        for i in self.list:
            if ((i[1] == tuple[0] or i[1] == 0xffffffffL) and
                (i[2] == tuple[1] or i[2] == 0xffffffffL) and
                (i[3] == tuple[2] or i[3] == 0xffffffffL) and
                (i[4] == tuple[3] or i[4] == 0xffffffffL) and
                (i[5] == (tuple[4] & i[6]))):
                ret.append(i[0])
        for i in greylist:
            if i in ret and len(ret) > 1:
                ret.remove(i)
        return ret
    def add(self, list):
        # FIXME: check values
        self.list.append(list)
    def read(self, filename):
        f = file(filename)
        pattern = re.compile("(\\S+)\\s+0x([0-9A-Fa-f]+)\\s0x([0-9A-Fa-f]+)\\s0x([0-9A-Fa-f]+)\\s0x([0-9A-Fa-f]+)\\s0x([0-9A-Fa-f]+)\\s0x([0-9A-Fa-f]+)\\s0x([0-9A-Fa-f]+)\\n")
        while True:
            line = f.readline()
            if line == "":
                break
            if line[0] == '#' or line[0] == '\n':
                continue
            match = pattern.match(line)
            if not match:
                continue
            self.add([match.group(1),
                int(match.group(2), 16),
                int(match.group(3), 16),
                int(match.group(4), 16),
                int(match.group(5), 16),
                int(match.group(6), 16),
                int(match.group(7), 16),
                int(match.group(8), 16)])
        f.close()
