from __future__ import absolute_import

from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from api.utils import insert_ctl
from nodes.api import NodeDetail
from nodes.models import Node

from .serializers import VMSerializer
from .utils import vct_node, get_vct_node_state


class VMManagementView(APIView):
    """ VCT Virtual Machine managemente """
    url_name = 'vm'
    
    def get(self, request, pk, format=None):
        node = get_object_or_404(Node, pk=pk)
        serializer = VMSerializer(context={'request': request})
        state = get_vct_node_state(node)
        if not state:
            return 'novm'
        serializer.data['state'] = state
        return Response(serializer.data)
    
    def post(self, request, pk, *args, **kwargs):
        node = get_object_or_404(Node, pk=pk)
        serializer = VMSerializer(data=request.DATA)
        if serializer.is_valid():
            data = serializer.data
            for action in ['stop', 'start', 'create']:
                if data.get(action):
                    vct_node(action, node)
            state = get_vct_node_state(node)
            if not state:
                return 'novm'
            serializer.data['state'] = state
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    def delete(self, request, pk, format=None):
        node = get_object_or_404(Node, pk=pk)
        vct_node('remove', node)
        return Response(status=status.HTTP_204_NO_CONTENT)


insert_ctl(NodeDetail, VMManagementView)
