import os

from django import forms
from django.core import validators
from django.core.exceptions import ValidationError

from controller.admin.utils import insert_change_view_action, get_modeladmin
from controller.models.utils import get_file_field_base_path
from controller.utils import is_installed
from nodes.models import Node
from slices.admin import TemplateAdmin, SliceAdmin, SliceSliversAdmin
from slices.models import Template, Sliver, Slice
from .actions import vct


class LocalFileField(forms.fields.FileField):
    def to_python(self, data):
        if data in validators.EMPTY_VALUES:
            return None
        return data


def local_files_form_factory(model_class, field_name, base_class=forms.ModelForm):
    attributes = {}
    attributes[field_name] = LocalFileField(required=True, label=field_name)
    
    def __init__(self, *args, **kwargs):
        base_class.__init__(self, *args, **kwargs)
        path = get_file_field_base_path(model_class, field_name)
        field = model_class._meta.get_field_by_name(field_name)[0]
        choices = tuple( (name, name) for name in os.listdir(path) )
        if field.blank:
            choices = (('empty', '---------'),) + choices
            self.fields[field_name].required = False
        self.fields[field_name].widget = forms.widgets.Select(choices=choices)
    
    def clean_field(self):
        value = self.cleaned_data.get(field_name)
        return value if value != 'empty' else ''
    
    attributes['__init__'] = __init__
    attributes['clean_' + field_name] = clean_field
    return type('VCTLocalFileForm', (base_class,), attributes)


if is_installed('firmware'):
    from firmware.admin import BaseImageInline
    from firmware.models import BaseImage
    BaseImageInline.form = local_files_form_factory(BaseImage, 'image')
    
    # Replace node firmware download for "VM manager"
    insert_change_view_action(Node, vct)
    try:
        from controller.admin.utils import insertattr
    except ImportError:
        from controller.admin.utils import insert_action
        insert_action(Node, vct)
    else:
        insertattr(Node, 'actions', vct)
    node_modeladmin = get_modeladmin(Node)
    old_get_change_view_actions_as_class = node_modeladmin.get_change_view_actions_as_class
    def get_change_view_actions_as_class(self):
        actions = old_get_change_view_actions_as_class()
        return [ action for action in actions if action.url_name != 'firmware' ]
    type(node_modeladmin).get_change_view_actions_as_class = get_change_view_actions_as_class
    
    # Select optional firmware files by default (tinc keys)
    from firmware.forms import OptionalFilesForm
    old_init = OptionalFilesForm.__init__
    def __init__(self, *args, **kwargs):
        old_init(self, *args, **kwargs)
        for __, field in self.fields.items():
            field.initial = True
    OptionalFilesForm.__init__ = __init__


# Slices customization
TemplateAdmin.form = local_files_form_factory(Template, 'image')
SliceAdmin.form = local_files_form_factory(Slice, 'exp_data', base_class=SliceAdmin.form)
SliceSliversAdmin.form = local_files_form_factory(Sliver, 'exp_data')
