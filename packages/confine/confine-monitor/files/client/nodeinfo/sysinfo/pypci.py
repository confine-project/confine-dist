# Copyright 2008 The Trustees of Princeton University
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

PCI_BASE_CLASS_NETWORK=0x02L
PCI_BASE_CLASS_STORAGE=0x01L
PCI_ANY=0xffffffffL

def get_devices():
    """ This is a replacement to the pypciscan library."""
    import os
    # changed /sbin/lspci to /usr/bin/lspci --NAV
    pci_cmd = os.popen("""/usr/bin/lspci -nvm | sed -e 's/\t/ /g' -e 's/ Class / /' -e 's/^/"/' -e 's/$/"/' -e 's/$/,/' -e 's/^"",$/],[/'""", 'r')
    pci_str = "[" + pci_cmd.read() + "]"
    pci_list = eval(pci_str)

    pci_devlist = []
    # convert each entry into a dict. and convert strings to ints.
    for dev in pci_list:
        rec = {}
        for field in dev:
            s = field.split(":")
            if len(s) > 2:
                # There are two 'device' fields in the output. Append
                # 'addr' for the bus address, identified by the extra ':'.
                end=":".join(s[1:])
                value = end.strip()
                key = s[0].lower() + "addr"
            else:
                value = int(s[1].strip(), 16)
                key = s[0].lower()

            rec[key] = value

        pci_devlist.append(rec)

    ret = {}
    # convert this list of devices into the format expected by the
    # consumer of get_devices()
    for dev in pci_devlist:
        if 'deviceaddr' not in dev:
            continue

        subdev = dev.get('sdevice',PCI_ANY)
        subvend = dev.get('svendor',PCI_ANY)
        progif = dev.get('progif',0)

        value = (dev['vendor'], dev['device'], subvend, subdev, dev['class'] << 8 | progif)
        ret[dev['deviceaddr']] = value

    return  ret

# for convenience for the clients of pypci
