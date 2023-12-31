print "********************************************";
print "*                                          *";
print "*             TOSSIM Script                *";
print "*                                          *";
print "********************************************";

import sys;
import time;

from TOSSIM import *;

t = Tossim([]);


topofile="topology.txt";
modelfile="meyer-heavy.txt";


print "Initializing mac....";
mac = t.mac();
print "Initializing radio channels....";
radio=t.radio();
print "    using topology file:",topofile;
print "    using noise file:",modelfile;
print "Initializing simulator....";
t.init();


#simulation_outfile = "simulation.txt";
#print "Saving sensors simulation output to:", simulation_outfile;
#simulation_out = open(simulation_outfile, "w");

#out = open(simulation_outfile, "w");
out = sys.stdout;

#Add debug channel
#print "Activate debug message on channel init"
#t.addChannel("init",out);
#print "Activate debug message on channel boot"
#t.addChannel("boot",out);
#print "Activate debug message on channel timer"
#t.addChannel("timer",out);
#print "Activate debug message on channel radio"
#t.addChannel("radio",out);
#Add debug channel
print "Activate debug message on channel init"
t.addChannel("init",out);
print "Activate debug message on channel boot"
t.addChannel("boot",out);
print "Activate debug message on channel radio"
t.addChannel("radio",out);
print "Activate debug message on channel radio_send"
t.addChannel("radio_send",out);
print "Activate debug message on channel sensor_node"
t.addChannel("sensor_node",out);
print "Activate debug message on channel gateway_node"
t.addChannel("gateway_node",out);
print "Activate debug message on channel server_node"
t.addChannel("server_node",out);

#Creation of the 8 nodes
for i in range(1, 9):
	print "Creating node",i,"...";
	node =t.getNode(i);
	time = 0*t.ticksPerSecond(); #instant at which each node should be turned on
	node.bootAtTime(time);
	print ">>>Will boot at time",  time/t.ticksPerSecond(), "[sec]";

print "Creating radio channels..."
f = open(topofile, "r");
lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    print ">>>Setting radio channel from node ", s[0], " to node ", s[1], " with gain ", s[2], " dBm"
    radio.add(int(s[0]), int(s[1]), float(s[2]))


#Creation of channel model
print "Initializing Closest Pattern Matching (CPM)...";
noise = open(modelfile, "r")
lines = noise.readlines()
compl = 0;
mid_compl = 0;

print "Reading noise model data file:", modelfile;
print "Loading:",
for line in lines:
    str = line.strip()
    if (str != "") and ( compl < 10000 ):
        val = int(str)
        mid_compl = mid_compl + 1;
        if ( mid_compl > 5000 ):
            compl = compl + mid_compl;
            mid_compl = 0;
            sys.stdout.write ("#")
            sys.stdout.flush()
        for i in range(1, 9):
            t.getNode(i).addNoiseTraceReading(val)
print "Done!";

for i in range(1, 9):
    print ">>>Creating noise model for node:",i;
    t.getNode(i).createNoiseModel()

print "Start simulation with TOSSIM! \n\n\n";

for i in range(0,20000):
	t.runNextEvent()
	
print "\n\n\nSimulation finished!";



