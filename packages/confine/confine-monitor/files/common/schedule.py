import time

class Schedule:

    def __init__(self, time_period):
            self.time_period = time_period


    def schedule (self, function, *args):
        while(1):
            function( *args )
            time.sleep(self.time_period)
            print "scheduling next run"
