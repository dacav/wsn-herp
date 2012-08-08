interface HashCmp <hash_res, key_type> {

    hash_res hash (const key_type *Key);

    bool equal (const key_type *Key1, const key_type *Key2);

}
