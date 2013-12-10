from client.main import main
import os
import shutil
import argparse

list_delete= ['log_shelf.db.dat', 'log_shelf.db.dir', 'log_shelf.db.bak', 'log_shelf.db', 'last_seen.db', 'last_seen.db.dat', 'last_seen.db.dir', 'last_seen.db.bak', 'Logs']

parser = argparse.ArgumentParser()
parser.add_argument('-c','--continue', action = "store_true", default = False, help = "Use this argument to continue without removing previous logs" )

args = vars(parser.parse_args())

if not args['continue']:
    for value in list_delete:
        path= os.path.join(os.path.dirname(__file__),value )

        if os.path.exists(path):
            if os.path.isdir(path):
                shutil.rmtree(path)
            else:
                os.remove(path)
            print("Removing: " + path)
    os.mkdir('Logs')

main.main()
