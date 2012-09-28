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


 #include <MultiTimer.h>
 #include <Types.h>

generic configuration MultiTimerC (typedef event_data_t,
                                   uint16_t QUEUE_SIZE) {
    provides {
        interface MultiTimer<event_data_t> [herp_opid_t];
    }
}

implementation {
    components new MultiTimerP(event_data_t),
               new PoolC(struct sched_item, QUEUE_SIZE),
               new TimerMilliC();

    MultiTimerP.BaseTimer -> TimerMilliC;
    MultiTimerP.Pool -> PoolC;

    MultiTimer = MultiTimerP;
}
