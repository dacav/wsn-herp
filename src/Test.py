#!/usr/bin/env python

from __future__ import print_function, division
import sys, os
import itertools as it
import time

try: range = range
except: pass

from TOSSIM import *;

NOISE_FILE = os.path.join (
    os.environ['TOSROOT'],
    'tos/lib/tossim/noise/meyer-heavy.txt'
)

def load_noise (T, nodes_id):
    noise_file = open(NOISE_FILE)
    nodes_id = list(nodes_id)
    for line in noise_file:
        s = line.strip()
        if (s):
            val = int(s)
            for i in nodes_id:
                T.getNode(i).addNoiseTraceReading(val)
    for i in nodes_id:
        T.getNode(i).createNoiseModel()
    noise_file.close()

class Topology :

    @staticmethod
    def ring (N) :
        assert(N > 0)
        def sequence ():
            for i in range(N - 1):
                yield (i, i + 1)
            yield (N - 1, 0)
        return Topology(sequence())

    @staticmethod
    def load_file (FileName) :
        F = open(FileName, 'rt')
        lines = (line[:-1].split() for line in F.readlines())
        F.close()
        return Topology(((int(x), int(y)) for (x, y) in lines))

    def __init__ (self, sequence):
        self.nodes = dict()
        nodes = set()
        links = set()
        for (x, y) in sequence:
            nodes.update((x, y))
            links.add((x, y))
        self.nodes = nodes
        self.links = links

    def get_nodes (self):
        return iter(self.nodes)

    def get_links (self):
        for x, y in self.links:
            yield x, y
            yield y, x

def main (argv=None):

    NODE_COUNT = 8;

    topology = Topology.load_file('topology')

    log = open('what-happens.txt', 'wt')

    T = Tossim([])
    T.addChannel('Prot', log)
    T.addChannel('RTab', log);
    T.addChannel('Out', sys.stdout);

    R = T.radio()

    load_noise(T, topology.get_nodes())

    for x, y in topology.get_links():
        print("Linking ", x, "and", y)
        R.add(x, y, -40)

    for ni in topology.get_nodes():
        n = T.getNode(ni);
        n.turnOn()

    try:
        for i in it.count():
            T.runNextEvent();
            #time.sleep(0.25)
            if i == 3000:
                break;
    except KeyboardInterrupt:
        print('Terminated.')
    finally:
        log.close()
        print('Also everything fine...')

if __name__ == '__main__':
    sys.exit(main())

