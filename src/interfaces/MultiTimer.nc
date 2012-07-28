 #include <Timer.h>
 #include "MultiTimer.h"

interface MultiTimer <event_data_t>
{
    /** Schedule an Event
     *
     * @param T The time at which the event must be fired;
     * @param D The data (context) of the Event to be scheduled.
     *
     * @retval The Event Handler on success;
     * @retval NULL on failure (no space left in scheduler).
     */
    command sched_item_t schedule (uint32_t T, event_data_t *D);

    /** Nullify an Event.
     *
     * @param E The Handler for the Event to be nullified.
     */
    command void nullify (sched_item_t E)

    /** Event signaled.
     *
     * @param D The data for the Event, as specified in schedule().
     */
    event void fired (event_data_t *D);
}
