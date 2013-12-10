from subprocess import Popen, PIPE

def get_ip6 (interface):
    #"ifconfig confine | grep 'inet6 addr'| cut -d/ -f1| cut -d: -f2-8"

    p1 = Popen(['ifconfig', interface], stdout=PIPE)
    p2 = Popen(['grep', 'inet6 addr' ], stdin=p1.stdout, stdout=PIPE)
    p3 = Popen(['cut', '-d/', '-f1'],stdin=p2.stdout, stdout=PIPE)
    p4 = Popen(['cut', '-d:', '-f2-9'],stdin=p3.stdout, stdout=PIPE)
    output = p4.stdout.read()
    return output.strip()

#value = get_ip6('confine')
#print value