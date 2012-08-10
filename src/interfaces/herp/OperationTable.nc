
 #include <OperationTable.h>
 #include <AM.h>

interface OperationTable<user_data> {

    /** Fetch a record for a new internal operation.
     *
     * @retval A pointer to the record on success;
     * @retval NULL on failure (no resources available).
     */
    command herp_oprec_t new_internal ();

    /** Fetch a record for an existing internal operation.
     *
     * @param IntOpId The internal operation id.
     *
     * @retval A pointer to the record on success;
     * @retval NULL on failure (no resources available).
     */
    command herp_oprec_t internal (herp_opid_t IntOpId);

    /** Fetch a record for an external operation.
     *
     * @param Owner The node owning the operation;
     * @param ExtOpId The external operation id declared by the Owner.
     *
     * @retval A pointer to the record on success;
     * @retval NULL on failure (no resources available).
     */
    command herp_oprec_t external (am_addr_t Owner, herp_opid_t ExtOpId);

    command void free_record (herp_oprec_t Rec);

    command void free_internal (herp_opid_t IntOpId);

    command void free_external (am_addr_t Owner, herp_opid_t ExtOpId);

    command herp_opid_t fetch_external_id (herp_oprec_t Rec);

    command herp_opid_t fetch_internal_id (herp_oprec_t Rec);

    command user_data * fetch_user_data (herp_oprec_t Rec);

    command am_addr_t fetch_owner (herp_oprec_t Rec);
}
