from client.main import log

from common.schedule import Schedule
import storefile
import config

def start_monitoring():
    sched = Schedule(config.TIMEPERIOD)
    sched.schedule(storefile.monitorStore)

def main():
    start_monitoring()
