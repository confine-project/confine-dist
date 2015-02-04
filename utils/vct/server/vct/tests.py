from django.core.urlresolvers import reverse
from django.test import TestCase

from nodes.models import Node
from users.models import Group, User


class VctTests(TestCase):
    def test_incorrect_vm_creation(self):
        # test regression introduced by 01a07be8 on controller
        group = Group.objects.create(name='group', allow_nodes=True)
        node = Node.objects.create(name='node', group=group)
        vm_url = reverse('node-ctl-vm', kwargs={'pk': node.pk})
        
        # vm creation only accepts null data
        resp = self.client.post(vm_url, data={'bla': 'foo'})
        self.assertEqual(resp.status_code, 400)
