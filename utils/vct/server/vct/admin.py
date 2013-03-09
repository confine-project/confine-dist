import os

from django import forms
from django.core import validators
from django.core.exceptions import ValidationError

from controller.utils import is_installed


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
        field = model_class._meta.get_field_by_name(field_name)[0]
        path = os.path.abspath(os.path.join(field.storage.location, field.upload_to))
        choices = ( (name, name) for name in os.listdir(path) )
        self.fields[field_name].widget = forms.widgets.Select(choices=choices)
    
    attributes['__init__'] = __init__
    return type('VCTLocalFileForm', (base_class,), attributes)


if is_installed('firmware'):
    from firmware.admin import BaseImageInline
    from firmware.models import BaseImage
    BaseImageInline.form = local_files_form_factory(BaseImage, 'image')


if is_installed('slices'):
    from slices.admin import TemplateAdmin, SliceAdmin, SliceSliversAdmin
    from slices.models import Template, Sliver, Slice
    TemplateAdmin.form = local_files_form_factory(Template, 'image')
    SliceAdmin.form = local_files_form_factory(Slice, 'exp_data', base_class=SliceAdmin.form)
    SliceSliversAdmin.form = local_files_form_factory(Sliver, 'exp_data')

