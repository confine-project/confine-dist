import os

from django import forms
from django.core import validators
from django.core.exceptions import ValidationError

from controller.admin.utils import insert_change_view_action, get_modeladmin, insertattr
from controller.models.utils import get_file_field_base_path

from controller.utils import is_installed
from nodes.models import Node
from slices.admin import TemplateAdmin, SliceAdmin, SliceSliversAdmin
from slices.models import Template, Sliver, Slice
from slices import settings as slices_settings

from . import settings 
from .actions import vm_management


class LocalFileField(forms.fields.FileField):
    def to_python(self, data):
        if data in validators.EMPTY_VALUES:
            return None
        return data


def local_files_form_factory(model_class, field_name, extensions=None, base_class=forms.ModelForm):
    attributes = {}
    attributes[field_name] = LocalFileField(required=True, label=field_name)
    
    def __init__(self, *args, **kwargs):
        base_class.__init__(self, *args, **kwargs)
        path = get_file_field_base_path(model_class, field_name)
        field = model_class._meta.get_field_by_name(field_name)[0]
        choices = []
        for name in os.listdir(path):
            if extensions:
                for extension in extensions:
                    if name.endswith(extension):
                        choices.append((name, name))
                        break
            else:
                choices.append((name, name))
        if field.blank:
            choices = (('empty', '---------'),) + tuple(choices)
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
    from firmware.settings import FIRMWARE_BASE_IMAGE_EXTENSIONS
    
    if settings.VCT_ENABLE_LOCAL_FILES:
        BaseImageInline.form = local_files_form_factory(BaseImage, 'image',
                extensions=FIRMWARE_BASE_IMAGE_EXTENSIONS)
    
    # Replace node firmware download for "VM manager"
    if settings.VCT_ENABLE_VM_MANAGEMENT:
        insert_change_view_action(Node, vm_management)
        insertattr(Node, 'actions', vm_management)
        node_modeladmin = get_modeladmin(Node)
        old_get_change_view_actions_as_class = node_modeladmin.get_change_view_actions_as_class
        def get_change_view_actions_as_class(self):
            actions = old_get_change_view_actions_as_class()
            return [ action for action in actions if action.url_name != 'firmware' ]
        type(node_modeladmin).get_change_view_actions_as_class = get_change_view_actions_as_class


# Slices customization
if settings.VCT_ENABLE_LOCAL_FILES:
    TemplateAdmin.form = local_files_form_factory(Template, 'image',
            extensions=slices_settings.SLICES_TEMPLATE_IMAGE_EXTENSIONS)
    SliceAdmin.form = local_files_form_factory(Slice, 'exp_data',
            base_class=SliceAdmin.form,
            extensions=slices_settings.SLICES_SLICE_EXP_DATA_EXTENSIONS)
    SliceSliversAdmin.form = local_files_form_factory(Sliver, 'exp_data',
            extensions=slices_settings.SLICES_SLIVER_EXP_DATA_EXTENSIONS)
