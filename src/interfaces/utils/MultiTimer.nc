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
     * @param D The data for the Event, as specified in schedule().
     */
    event void fired (event_data_t *D);

}
