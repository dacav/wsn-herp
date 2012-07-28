 #include "TxOps.h"

interface TxOps<k_t,v_t> {

    /** Acquire a new Slot.
     *
     * Given a Key, retrieves the associated Slot. If there's no such a
     * Slot, it is allocated.
     *
     * @param Key The Key;
     *
     * @retval NULL if there's no space left;
     * @retval The associated Slot otherwise.
     */
    command slot_t acquire (k_t Key);

    /** Retrieve an existent Slot.
     *
     * Given a Key, retrieves the associated Slot. If there's no such a
     * Slot, NULL is returned.
     *
     * @param Key The Key;
     *
     * @retval NULL if there's no such a Slot;
     * @retval The associated Slot otherwise.
     */
    command slot_t retrieve (k_t Key);

    /** Access the Value stored in the Slot.
     *
     * @param Slot The Slot.
     *
     * @return The Value stored into the Slot.
     */
    command v_t * access (slot_t Slot);

    /** Drop the ownership of the Slot.
     *
     * Once a Slot has been released, it can be reused for another
     * allocation.
     *
     * @param Slot The Slot to be dropped.
     */
    command void drop (slot_t Slot);

}
