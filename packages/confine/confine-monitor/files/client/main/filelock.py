import os
import time
import errno

class FileLockException(Exception):
    pass

class FileLock(object):


    def __init__(self, file_name, timeout=10, delay=.05):

        self.is_locked = False
        self.lockfile = os.path.join(os.getcwd(), "%s.lock" % file_name)
        self.file_name = file_name
        self.timeout = timeout
        self.delay = delay


    def acquire(self):

        start_time = time.time()
        while True:
            try:
                self.fd = os.open(self.lockfile, os.O_CREAT|os.O_EXCL|os.O_RDWR)
                break;
            except OSError as e:
                if e.errno != errno.EEXIST:
                    raise
                if (time.time() - start_time) >= self.timeout:
                    raise FileLockException("Timeout occured.")
                time.sleep(self.delay)
        self.is_locked = True


    def release(self):

        if self.is_locked:
            os.close(self.fd)
            os.unlink(self.lockfile)
            self.is_locked = False


    def __enter__(self):

        if not self.is_locked:
            self.acquire()
        return self


    def __exit__(self, type, value, traceback):

        if self.is_locked:
            self.release()


    def __del__(self):

        self.release()