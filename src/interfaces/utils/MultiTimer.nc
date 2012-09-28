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

#include <Timer.h>
 #include "MultiTimer.h"

interface MultiTimer <event_data_t>
{
    /** Schedule an Event
     *
     * @param[in] T The time at which the event must be fired;
     * @param[in] D The data (context) of the Event to be scheduled.
     *
     * @note The returned Handler is a pointer, so it can be compared.
     *
     * @retval The Event Handler on success;
     * @retval NULL on failure (no space left in scheduler).
     */
    command sched_item_t schedule (uint32_t T, event_data_t *D);

    /** Nullify an Event.
     *
     * @param[in] E The Handler for the Event to be nullified.
     */
    command void nullify (sched_item_t E);

    /** Event signaled.
     *
     * @warn After an Event has been fired, the associated Schedule Item
     *             (sched_item_t) must not be used.
     *
     * @param[in] D The data for the Event, as specified in schedule().
     */
    event void fired (event_data_t *D);

}
