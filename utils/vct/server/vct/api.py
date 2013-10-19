from __future__ import absolute_import

from django.core.management.base import CommandError
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from api import generics, exceptions
from api.utils import insert_ctl
from nodes.api import NodeDetail
from nodes.models import Node

from .serializers import VMSerializer
from .utils import vct_node, get_vct_node_state


class VMView(APIView):
    """ VCT Virtual Machine managemente """
    url_name = 'vm'
    rel = 'http://confine-project.eu/rel/controller/vm'
    serializer_class = VMSerializer
    
    def get(self, request, pk, format=None):
        node = get_object_or_404(Node, pk=pk)
        serializer = self.serializer_class(context={'request': request})
        state = get_vct_node_state(node)
        if not state:
            return Response({'detail': 'VM does not exists'}, status=status.HTTP_404_NOT_FOUND)
        serializer.data['state'] = state
        return Response(serializer.data)
    
    def post(self, request, pk, *args, **kwargs):
        node = get_object_or_404(Node, pk=pk)
        if request.DATA is None:
            try:
                cmd = vct_node('create', node, silent=False)
            except CommandError as e:
                return Response({"detail": str(e)},
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            state = get_vct_node_state(node)
            serializer.data['state'] = state
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        raise exceptions.ParseError(detail='This endpoint only accepts null data')
    
    def put(self, request, pk, **kwargs):
        node = get_object_or_404(Node, pk=pk)
        serializer = self.serializer_class(data=request.DATA)
        if serializer.is_valid():
            data = serializer.data
            for action in ['stop', 'start']:
                if data.get(action):
                    try:
                        vct_node(action, node)
                    except CommandError as e:
                        return Response({"detail": str(e)},
                                status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            state = get_vct_node_state(node)
            serializer.data['state'] = state
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    def delete(self, request, pk, format=None):
        node = get_object_or_404(Node, pk=pk)
        vct_node('remove', node)
        return self.get(request, pk, format=None)


insert_ctl(NodeDetail, VMView)
