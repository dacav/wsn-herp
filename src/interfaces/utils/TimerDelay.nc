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

interface TimerDelay {

    /** Time for reaching a node.
     *
     * This function yields the time required as round-trip-time to a node
     * which is `Hops` nodes distant. The time is estimated according to
     * implementation-dependent euristics.
     *
     * @param Hops The number of hops.
     *
     * @return The supposed round-trip-time for the given number of hops
     *         in milliseconds.
     */
    command uint32_t for_hops (uint8_t Hops);

    /** Time for reaching any node
     *
     * This function yields an estimate of the as round-trip-time to any
     * node in the network, regardless of the path.
     *
     * @return The required value in milliseconds.
     */
    command uint32_t for_any_node ();

}
