#!/usr/bin/python

# Copyright (c) 2003 Intel Corporation
# All rights reserved.
#
# Copyright (c) 2004-2006 The Trustees of Princeton University
# All rights reserved.


import string

MINHW   = 0x001
SMP     = 0x002
X86_64  = 0x004
INTEL   = 0x008
AMD     = 0x010
NUMA    = 0x020
GEODE   = 0x040
BADHD   = 0x080
LAST    = 0x100
RAWDISK = 0x200

modeloptions = {'smp':SMP,
                'x64':X86_64,
                'i64':X86_64|INTEL,
                'a64':X86_64|AMD,
                'i32':INTEL,
                'a32':AMD,
                'numa':NUMA,
                'geode':GEODE,
                'badhd':BADHD,
                'minhw':MINHW,
                'rawdisk':RAWDISK}

def Get(model):
    modelinfo = string.split(model,'/')
    options= 0
    for mi in modelinfo:
        info = string.strip(mi)
        info = info.lower()
        options = options | modeloptions.get(info,0)

    return options

