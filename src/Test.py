#!/usr/bin/env python

from __future__ import print_function, division
import sys, os
import itertools as it
import time

try: range = range
except: pass

from TOSSIM import *;

def load_noise (T, nodes_id):
    noise = open(os.environ['TOSROOT'] +
                 '/tos/lib/tossim/noise/meyer-heavy.txt')
    for line in noise:
        s = line.strip()
        if (s):
            val = int(s)
            for i in nodes_id:
                T.getNode(i).addNoiseTraceReading(val)
    for i in nodes_id:
        T.getNode(i).createNoiseModel()
    noise.close()

def main (argv=None):

    T = Tossim([])
    T.addChannel('Out', sys.stdout)

    R = T.radio()

    nodes_id = list( range(1, 4) )
    load_noise(T, nodes_id)
    [R.add(x, y, -80) for x in nodes_id for y in nodes_id]

    for ni in nodes_id:
        n = T.getNode(ni);
        n.turnOn()

    for i in it.count():
        T.runNextEvent();
        print("step", i)
        time.sleep(0.25)

if __name__ == '__main__':
    sys.exit(main())

