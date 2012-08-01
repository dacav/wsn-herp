 #include <TxTable.h>
 #include <AM.h>

interface TxTable<entry_data_t> {

    /** Build a new Entry.
     *
     * This call might fail if there's no more place in the table or if
     * there's already an active communication for the required target
     * node.
     *
     * @param Addr The address of the target node.
     *
     * @retval The Entry on success;
     * @retval NULL on failure.
     */
    command tx_entry_t new_entry (am_addr_t Addr);

    /** Retrieve the entry of a node.
     *
     * This call might fail if there's no active transmission for the
     * given Address/Id pair.
     *
     * @param Addr The address associated to the required entry;
     * @param Id The identifier associated to the required entry.
     */
    command tx_entry_t get_entry (am_addr_t Addr, uint16_t Id);

    /** Free the Entry.
     *
     * Release the resources associated to a data transmission.
     *
     * @param E The Entry to be freed.
     */
    command void free_entry (tx_entry_t E);

    /** Access the stored information.
     *
     * @param E The Entry to be accessed.
     *
     * @return The associated user data.
     */
    command entry_data_t * fetch_data (tx_entry_t E);

    command uint16_t fetch_id (tx_entry_t E);

}
