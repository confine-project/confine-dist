from django.conf.urls import patterns, include, url

# Uncomment the next two lines to enable the admin:
# from django.contrib import admin
# admin.autodiscover()

urlpatterns = patterns('',
    # Examples:
     #url(r'^get/([A-Za-z]+\/timestamp=\d+\.?\d*)/$', 'client.web.views.getinfo')
     url(r'^get/([A-Za-z]+\/seqnumber=\d+)/$', 'client.web.views.getinfo')
    # url(r'^confine_monitor/', include('confine_monitor.foo.urls')),

    # Uncomment the admin/doc line below to enable admin documentation:
    # url(r'^admin/doc/', include('django.contrib.admindocs.urls')),

    # Uncomment the next line to enable the admin:
    # url(r'^admin/', include(admin.site.urls)),
)
