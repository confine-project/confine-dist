#!/usr/bin/python

# Copyright (c) 2003 Intel Corporation
# All rights reserved.
#
# Copyright (c) 2004-2006 The Trustees of Princeton University
# All rights reserved.

class BootManagerException(Exception):
    def __init__( self, err ):
        self.__fault= err

    def __str__( self ):
        return self.__fault
    
class BootManagerAuthenticationException(Exception):
    def __init__( self, err ):
        self.__fault= err

    def __str__( self ):
        return self.__fault
