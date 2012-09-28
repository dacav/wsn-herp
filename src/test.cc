/*
   Copyright 2012 Giovanni [dacav] Simoni


   This file is part of HERP. HERP is free software: you can redistribute
   it and/or modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation, either version 3 of the
   License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License along
   with this program.  If not, see <http://www.gnu.org/licenses/>.

 */

#include <string>
#include <set>
#include <list>
#include <sstream>
#include <fstream>
#include <iostream>
#include <utility>
#include <locale>
#include <stdexcept>
#include <thread>

#include <cstdlib>
#include <cstdio>
#include <signal.h>
#include <unistd.h>

#include <tossim.h>

static std::string get_noise_file ()
{
    const char *root = getenv("TOSROOT");

    if (root == NULL) {
        throw std::invalid_argument("TOSROOT envvar not defined");
    }

    return std::string(root) + "tos/lib/tossim/noise/meyer-heavy.txt";
}

class Topology {

    private:

        typedef unsigned long NodeId;

        Tossim &tossim;

        std::set<NodeId> nodes;
        std::list<std::pair<NodeId, NodeId>> links;

    public:
        Topology (Tossim &t, const std::string & filename)
            : tossim(t)
        {
            std::fstream file(filename, std::ios::in);
            while (!file.eof() and file.good()) {
                int x, y;

                file >> x >> y;

                nodes.insert(x);
                if (x != y) {
                    nodes.insert(y);
                    links.push_front(std::make_pair(x, y));
                }
            }
            file.close();
        }

        void load_noise () const
        {
            std::cerr << "Loading noise..." << std::endl;

            std::fstream file(get_noise_file(), std::ios::in);
            while (!file.eof() and file.good()) {
                NodeId val;

                file >> val;
                for (auto id = nodes.begin(); id != nodes.end(); id ++) {
                    tossim.getNode(*id)->addNoiseTraceReading(val);
                }
            }

            for (auto id = nodes.begin(); id != nodes.end(); id ++) {
                tossim.getNode(*id)->createNoiseModel();
            }
        }

        void link_nodes () const
        {
            Radio &r = *(tossim.radio());
            for (auto pair = links.begin(); pair != links.end(); pair ++) {
                std::cerr << "Linking " << pair->first
                          << " and " << pair->second
                          << std::endl;
                r.add(pair->first, pair->second, -40.0);
                r.add(pair->second, pair->first, -40.0);
            }
        }

        void turn_on_all () const
        {
            for (auto id = nodes.begin(); id != nodes.end(); id ++) {
                tossim.getNode(*id)->turnOn();
                std::cerr << "Node " << (*id) << " running" << std::endl;
            }
        }

};

class LogFiles
{
    private:
        std::list<FILE *> files;

    public:
        FILE * open (const char * name)
        {
            FILE *ret = fopen(name, "wt");
            files.push_front(ret);
            return ret;
        }

        ~LogFiles ()
        {
            while (!files.empty()) {
                FILE *f = files.front();
                files.pop_front();
                fclose(f);
            }
        }

};

bool terminated;

static void set_terminated (int)
{
    terminated = true;
}

static void add_channels (Tossim &tossim, LogFiles &log)
{
    tossim.addChannel("Stats", log.open("stats.log"));
    tossim.addChannel("Out", stdout);
#ifdef DUMP
    tossim.addChannel("Prot", log.open("prot.log"));
    tossim.addChannel("RTab", log.open("rtab.log"));
    tossim.addChannel("OpId", log.open("opid.log"));
#endif
}

int main (int argc, char **argv)
{
    if (argc < 2) {
        std::cerr << "Requiring topology file!" << std::endl
                  << "Usage: " << argv[0] << " <topology-file>"
                  << std::endl;
        return 1;
    }

    terminated = false;
    signal(SIGINT, set_terminated);
    signal(SIGTERM, set_terminated);

    Tossim tossim(NULL);
    Topology topo(tossim, argv[1]);
    LogFiles log;

    add_channels(tossim, log);

    topo.load_noise();
    topo.link_nodes();
    topo.turn_on_all();

    long step = 0;
    while (!terminated) {
        //std::cout << (step ++) << std::endl;
        tossim.runNextEvent();
        usleep(50 * /* ms */ 1000);
    }

    return 0;
}
