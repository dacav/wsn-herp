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
    command herp_oprec_t external (am_addr_t Owner, herp_opid_t ExtOpId,
                                   bool MustExist);

    command void free_record (herp_oprec_t Rec);

    command void free_internal (herp_opid_t IntOpId);

    command void free_external (am_addr_t Owner, herp_opid_t ExtOpId);

    command herp_opid_t fetch_external_id (const herp_oprec_t Rec);

    command herp_opid_t fetch_internal_id (const herp_oprec_t Rec);

    command user_data * fetch_user_data (const herp_oprec_t Rec);

    command am_addr_t fetch_owner (const herp_oprec_t Rec);

    event error_t data_init (herp_oprec_t Rec, user_data *UserData);

    event void data_dispose (user_data *UserData);

}
