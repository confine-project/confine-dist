import os

from django import forms
from django.core import validators
from django.core.exceptions import ValidationError

from controller.models.utils import get_file_field_base_path
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


if is_installed('slices'):
    from slices.admin import TemplateAdmin, SliceAdmin, SliceSliversAdmin
    from slices.models import Template, Sliver, Slice
    TemplateAdmin.form = local_files_form_factory(Template, 'image')
    SliceAdmin.form = local_files_form_factory(Slice, 'exp_data', base_class=SliceAdmin.form)
    SliceSliversAdmin.form = local_files_form_factory(Sliver, 'exp_data')

