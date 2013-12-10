from django.shortcuts import render_to_response
from django.template.loader import get_template
from django.template import Context, RequestContext
from django.http import HttpResponse, Http404
import json
import string
from client.main import config, log
from client.nodeinfo.sysinfo import systeminfo


def hello(request):
  #  return HttpResponse("Monitoring Service")
  # return render_to_response('testing.html')
    import urllib2
    import json
    from BeautifulSoup import BeautifulSoup

#Download the graph page using Python's urllib2 from the demo URL
#The URL is shortened for the purposes of this demo.
#Feel free to use this URL for your own testing.
    page = urllib2.urlopen('http://glowfilter.com/media/static/glowfilter/articles/flot-beautiful-soup-demo/world_population.html')

#Create a BeautifulSoup object.
    soup = BeautifulSoup(page)

#Creating some variables to pass to the Django template
    data = ""
    countries = []

#Find all of the table rows
    for row in soup.findAll("tr",{"class":"dataRow"}):
        country = []

    #For each row, get the contents of the relevant cells, and place them into the countries array.
    #This array will be rendered as JSON into the view for populating the Flot graph
        for cell in row.findAll("td",{"class":"year"}):
            country.append(int(cell.contents[0].replace(",","")))
        for cell in row.findAll("td",{"class":"population"}):
            country.append(int(cell.contents[0].replace(",","")))

        countries.append(country)
        print countries

#Transform the countries array into JSON
    data = json.dumps(countries)

#Render the template, with the countries JSON string passed into the template context
    return render_to_response('testing.html',{'countries':data, 'monitor':'navaneeth'},context_instance=RequestContext(request))


def getinfo(request, parameter):

   # return HttpResponse(parameter)
    (info_requested, sequence) = string.split(parameter, '/')
    json_value = {}



    str_seqnumber = string.split(sequence, '=') [-1]
    seqnumber = int(str_seqnumber)
   # str_timestamp = string.split(timestamp, '=') [-1]
   # timestamp = float (str_timestamp)

   # return HttpResponse(seqnumber)

    config.update_last_seen_seq_number(seqnumber)
    # TODO: remove log entry for all entries until the last seen sequence number

    if info_requested == "memory":
        json_value = json.dumps(systeminfo.get_mem_info(), sort_keys=True, indent=4, separators=(',', ': '))

    elif info_requested == "cpu":
        json_value = json.dumps(systeminfo.get_cpu_info(), sort_keys=True, indent=4, separators=(',', ': '))

    elif info_requested == "loadavg":
        json_value = json.dumps(systeminfo.get_load_avg(), sort_keys=True, indent=4, separators=(',', ': '))

    elif info_requested == "uptime":
        json_value = json.dumps(systeminfo.get_uptime(), sort_keys=True, indent=4, separators=(',', ': '))

    elif info_requested == "disk":
        json_value = json.dumps(systeminfo.get_block_device_list(), sort_keys=True, indent=4, separators=(',', ': '))

    elif info_requested == "all":
        # uncomment later
       # json_value = json.dumps(systeminfo.get_all_info(), sort_keys=True, indent=4, separators=(',', ': '))
        #testing
        json_value = json.dumps(log.get_all_info_since(seqnumber), sort_keys=True, indent=4, separators=(',', ': '))

#        return HttpResponse(log.get_shelve_elements())



    if json_value:
        return HttpResponse(json_value, content_type= "application/json")

    else:
        raise Http404()
