import socket
import time
import random

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("[kairosdb_ip]", 4242))

start_time = time.time()

start_range = 1
num_sensors = 25000
num_repeat = 2001

for x in range(1,num_repeat):
	str=""
	time.sleep(1)
	curr_epoch = int(round(time.time() * 1000))
#	print "======================"
#	print x
#	print "Current time " + time.strftime("%X")
#	print "======================"
	for y in range(start_range,start_range+num_sensors):
		statement = "put SENSOR_%d %d %d status=good\n" %(y,curr_epoch,random.randint(1,500))
#		print statement
		s.send(statement)

print("--- %s seconds ---" % (time.time() - start_time))
