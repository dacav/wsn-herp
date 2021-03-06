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


 #include <HashTable.h>

interface HashTable <key_type, value_type> {

    /** Fetch an entry.
     *
     * Fetches an entry from the Hash Table, building non-existent entries
     * if required.
     *
     * This command will issue possibly multiple signals to the key_hash()
     * and key_equal() events.
     *
     * If a new entry is inserted, the value_init() event will be
     * triggered.
     *
     * @param Key The Key of the fetched item;
     * @param MustExist if FALSE, and if there's no item associated to the
     *        required Key, build a fresh one.
     *
     * @retval A new Slot on success;
     * @retval NULL on failure (table is full);
     * @retval NULL if there's nothing associated with the given Key and
     *         MustExist is FALSE.
     *
     */
    command hash_slot_t get (const key_type *Key, bool MustExist);

    command void del (hash_slot_t Slot);

    command value_type * item (const hash_slot_t Slot);

    command value_type * get_item (const key_type *Key, bool MustExist);

    command void get_del (const key_type *Key);

    command bool full ();

    event hash_index_t key_hash (const key_type *Key);

    event bool key_equal (const key_type *Key1, const key_type *Key2);

    event error_t value_init (const key_type *Key, value_type *Val);

    event void value_dispose (const key_type *Key, value_type *Val);

}
