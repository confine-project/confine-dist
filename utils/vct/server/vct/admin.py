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


class VCTImageForm(forms.ModelForm):
    image = LocalFileField(required=True, label='Image')
    
    def __init__(self, *args, **kwargs):
        super(VCTImageForm, self).__init__(*args, **kwargs)
        field = BaseImage._meta.get_field_by_name('image')[0]
        path = os.path.abspath(os.path.join(field.storage.location, field.upload_to))
        choices = ( (name, name) for name in os.listdir(path) )
        self.fields['image'].widget = forms.widgets.Select(choices=choices)


if is_installed('firmware'):
    from firmware.admin import BaseImageInline
    from firmware.models import BaseImage
    BaseImageInline.form = VCTImageForm


if is_installed('slices'):
    from slices.admin import TemplateAdmin
    from slices.models import Template
    TemplateAdmin.form = VCTImageForm
