import os

from django import forms
from django.conf import settings
from django.core import validators
from django.core.exceptions import ValidationError

from controller.admin.utils import insert_change_view_action, get_modeladmin, insertattr
from controller.models.utils import get_file_field_base_path

try:
    from controller.utils.apps import is_installed
except ImportError:
    from controller.utils import is_installed
from nodes.models import Node
from slices.admin import SliceSliversAdmin, SliceAdmin, TemplateAdmin
from slices.models import Slice, Sliver, Template
try:
    from slices.admin import SliverAdmin, SliverDefaultsInline
    from slices.models import SliverDefaults
except ImportError:
    # enable backwards compatibility
    EXISTS_SLIVER_DEFAULTS = False
else:
    EXISTS_SLIVER_DEFAULTS = True
from slices import settings as slices_settings

from . import settings as vct_settings
from .actions import vm_management


class LocalFileField(forms.fields.FileField):
    def to_python(self, data):
        if data in validators.EMPTY_VALUES:
            return None
        return data


def local_files_form_factory(model_class, field_names, extensions=None, base_class=forms.ModelForm):
    if not hasattr(field_names, '__iter__'):
        field_names = [field_names]
    attributes = {}
    for field_name in field_names:
        field = model_class._meta.get_field_by_name(field_name)[0]
        attributes[field_name] = LocalFileField(required=True, help_text=field.help_text,
                label=field.verbose_name.capitalize())
    
    def __init__(self, *args, **kwargs):
        base_class.__init__(self, *args, **kwargs)
        for field_name in field_names:
            #FIXME path is invalid on dynamic upload_to + settings override
            path = get_file_field_base_path(model_class, field_name)
            field = model_class._meta.get_field_by_name(field_name)[0]
            choices = []
            for name in os.listdir(path):
                # get file path relative to MEDIA_ROOT
                file_path = os.path.join(path, name)
                file_path = os.path.relpath(file_path, settings.MEDIA_ROOT)
                if extensions:
                    for extension in extensions:
                        if name.endswith(extension):
                            choices.append((file_path, name))
                            break
                else:
                    choices.append((file_path, name))
            if field.blank:
                choices = (('empty', '---------'),) + tuple(choices)
                self.fields[field_name].required = False
            self.fields[field_name].widget = forms.widgets.Select(choices=choices)
    
    for field_name in field_names:
        def clean_field(self, field_name=field_name):
            value = self.cleaned_data.get(field_name)
            return value if value != 'empty' else ''
        attributes['clean_' + field_name] = clean_field
    
    attributes['__init__'] = __init__
    return type('VCTLocalFileForm', (base_class,), attributes)


if is_installed('firmware'):
    from firmware.admin import BaseImageInline
    from firmware.models import BaseImage
    from firmware.settings import FIRMWARE_BASE_IMAGE_EXTENSIONS
    
    if vct_settings.VCT_LOCAL_FILES:
        BaseImageInline.form = local_files_form_factory(BaseImage, 'image',
                extensions=FIRMWARE_BASE_IMAGE_EXTENSIONS)
    
    # Replace node firmware download for "VM manager"
    if vct_settings.VCT_VM_MANAGEMENT:
        insert_change_view_action(Node, vm_management)
        insertattr(Node, 'actions', vm_management)
        node_modeladmin = get_modeladmin(Node)
        old_get_change_view_actions_as_class = node_modeladmin.get_change_view_actions_as_class
        def get_change_view_actions_as_class(self):
            actions = old_get_change_view_actions_as_class()
            return [ action for action in actions if action.url_name != 'firmware' ]
        type(node_modeladmin).get_change_view_actions_as_class = get_change_view_actions_as_class


# Slices customization
if vct_settings.VCT_LOCAL_FILES:
    TemplateAdmin.form = local_files_form_factory(Template, 'image',
            extensions=slices_settings.SLICES_TEMPLATE_IMAGE_EXTENSIONS)
    if EXISTS_SLIVER_DEFAULTS:
        #200 drop overlay field but keep backwards compatibility
        FILE_FIELDS = ('data', 'overlay') if 'overlay' in dir(Sliver) else ('data',)
        SliverDefaultsInline.form = local_files_form_factory(SliverDefaults,
                FILE_FIELDS, base_class=SliverDefaultsInline.form)
        SliceSliversAdmin.form = local_files_form_factory(Sliver, FILE_FIELDS)
        SliverAdmin.form = local_files_form_factory(Sliver, FILE_FIELDS,
                base_class=SliverAdmin.form)
    else: #234 backwards compatibility
        SliceAdmin.form = local_files_form_factory(Slice, ('exp_data', 'overlay'),
                base_class=SliceAdmin.form)
        SliceSliversAdmin.form = local_files_form_factory(Sliver,
                ('exp_data', 'overlay'))
