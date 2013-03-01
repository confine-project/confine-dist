import os

from django import forms
from django.core import validators
from django.core.exceptions import ValidationError

from controller.utils import is_installed


if is_installed('firmware'):
    # Display local files rather than uploading, on firmware base image configuration
    
    from firmware.admin import BaseImageInline
    from firmware.models import BaseImage
    
    class LocalFileField(forms.fields.FileField):
        def to_python(self, data):
            if data in validators.EMPTY_VALUES:
                return None
            return data
    
    class VCTBaseImageInlineForm(forms.ModelForm):
        image = LocalFileField(required=True, label='Image')
        
        def __init__(self, *args, **kwargs):
            super(VCTBaseImageInlineForm, self).__init__(*args, **kwargs)
            field = BaseImage._meta.get_field_by_name('image')[0]
            path = os.path.abspath(os.path.join(field.storage.location, field.upload_to))
            choices = ( (name, name) for name in os.listdir(path) \
                if name.endswith('.img.gz') )
            self.fields['image'].widget = forms.widgets.Select(choices=choices)
    
    BaseImageInline.form = VCTBaseImageInlineForm

