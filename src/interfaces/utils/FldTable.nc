
 #include <FldTable.h>
 #include <AM.h>

interface FldTable<entry_data_t> {

    command fld_entry_t get_entry (const fld_key_t *K);

    command void free_entry (fld_entry_t E);

    command entry_data_t * fetch_data (fld_entry_t E);

    command fld_key_t * fetch_key (fld_entry_t E);

}
