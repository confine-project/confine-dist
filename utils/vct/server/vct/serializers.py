from __future__ import absolute_import

from api import serializers

from .utils import get_vct_node_state


class VMSerializer(serializers.Serializer):
    state = serializers.CharField(read_only=True)
    start = serializers.BooleanField(required=False)
    stop = serializers.BooleanField(required=False)
    
    def validate(self, data):
        data = super(VMSerializer, self).validate(data)
        true = []
        for action in ['create', 'stop']:
            if data.get(action, False):
               true.append(action)
        if len(true) > 1:
            raise serializers.ValidationError("%s?" % ' or '.join(true))
        return data
