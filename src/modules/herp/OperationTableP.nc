
 #include <OperationTable.h>
 #include <AM.h>
 #include <TinyError.h>

 #include <assert.h>

generic module OperationTableP(typedef user_data) {

    provides {
        interface OperationTable<user_data> as OpTab;
    }

    uses {
        interface Pool<user_data> as UserDataPool;
        interface OperationId;
        interface HashTable<herp_opid_t, struct herp_oprec> as IntMap;
        interface HashTable<herp_pair_t, herp_opid_t> as ExtMap;
    }

}

implementation {

    event hash_index_t IntMap.key_hash (const herp_opid_t *Key) {
        return *Key;
    }

    event bool IntMap.key_equal (const herp_opid_t *Key1, const herp_opid_t *Key2) {
        return (*Key1) == (*Key2);
    }

    event error_t IntMap.value_init (const herp_opid_t *K, herp_oprec_t V) {
        user_data *UserData;

        UserData = call UserDataPool.get();
        if (UserData == NULL) return FAIL;

        if (signal OpTab.data_init(V, UserData) != SUCCESS) {
            call UserDataPool.put(UserData);
            return FAIL;
        }

        V->ids.external = V->ids.internal = *K;
        V->store = (void *)UserData;
        V->owner = TOS_NODE_ID;

        return SUCCESS;
    }

    event void IntMap.value_dispose (const herp_opid_t *K, herp_oprec_t V) {
        call UserDataPool.put((user_data *) V->store);
        call OperationId.put(*K);
    }

    event hash_index_t ExtMap.key_hash (const herp_pair_t *Key) {
        return Key->node;
    }

    event bool ExtMap.key_equal (const herp_pair_t *Key1, const herp_pair_t *Key2) {
        return Key1->node == Key2->node && Key1->ext_id == Key2->ext_id;
    }

    event error_t ExtMap.value_init (const herp_pair_t *K, herp_opid_t *V) {
        herp_oprec_t IntRecord;

        IntRecord = call OpTab.new_internal();
        if (IntRecord == NULL) return FAIL;

        *V = IntRecord->ids.internal;

        return SUCCESS;
    }

    event void ExtMap.value_dispose (const herp_pair_t *K, herp_opid_t *V) {
        call OpTab.free_external(K->node, K->ext_id);
    }

    command herp_oprec_t OpTab.new_internal () {
        herp_opid_t Id;
        herp_oprec_t Ret;

        if (call UserDataPool.empty()) return NULL;
        if (call OperationId.get(&Id) != SUCCESS) return NULL;

        Ret = call IntMap.item( call IntMap.get(&Id, FALSE) );
        if (Ret == NULL) {
            call OperationId.put(Id);
        }
        return Ret;
    }

    command herp_oprec_t OpTab.internal (herp_opid_t IntOpId) {
        return call IntMap.get_item(&IntOpId, TRUE);
    }

    command herp_oprec_t OpTab.external (am_addr_t Owner, herp_opid_t ExtOpId) {

        if (Owner == TOS_NODE_ID) {
            return call OpTab.internal(ExtOpId);
        } else {
            herp_pair_t ExtKey;
            hash_slot_t Slot;
            herp_opid_t *IntOpId;
            herp_oprec_t Ret;

            ExtKey.node = Owner;
            ExtKey.ext_id = ExtOpId;

            Slot = call ExtMap.get(&ExtKey, FALSE);
            if (Slot == NULL) return NULL;

            IntOpId = call ExtMap.item(Slot);
            Ret = call IntMap.get_item(IntOpId, FALSE);
            if (Ret == NULL) {
                call ExtMap.del(Slot);
                return NULL;
            }

            Ret->ids.internal = *IntOpId;
            Ret->ids.external = ExtOpId;
            Ret->owner = Owner;

            return Ret;
        }
    }

    command void OpTab.free_record (herp_oprec_t Rec) {
        if (Rec->owner == TOS_NODE_ID) {
            assert(Rec->ids.internal == Rec->ids.external);
            call OpTab.free_internal(Rec->ids.internal);
        } else {
            call OpTab.free_external(Rec->owner, Rec->ids.external);
        }
    }

    command void OpTab.free_internal (herp_opid_t IntOpId) {

#define WITH_ASSERT
#ifdef WITH_ASSERT
        hash_slot_t Slot;
        herp_oprec_t Rec;

        Slot = call IntMap.get(&IntOpId, TRUE);
        if (Slot == NULL) return;

        Rec = call IntMap.item(Slot);
        /* FIXME: if needed, find a way of automatically redirect
         * non-internal records to free_external */
        assert(Rec->owner == TOS_NODE_ID);
        call IntMap.del(Slot);
#undef WITH_ASSERT
#else
        call IntMap.get_del(&IntOpId);
#endif
        call OperationId.put(IntOpId);
    }

    command void OpTab.free_external (am_addr_t Owner,
                                      herp_opid_t ExtOpId) {

        if (Owner == TOS_NODE_ID) {
            call OpTab.free_internal(ExtOpId);
        } else {
            herp_pair_t ExtKey;
            hash_slot_t Slot;

            ExtKey.node = Owner;
            ExtKey.ext_id = ExtOpId;

            Slot = call ExtMap.get(&ExtKey, FALSE);
            if (Slot != NULL) {
                herp_opid_t *IntOpId;

                IntOpId = call ExtMap.item(Slot);
                call OpTab.free_internal(*IntOpId);
                call ExtMap.del(Slot);
            }
        }
    }

    command herp_opid_t OpTab.fetch_external_id (const herp_oprec_t Rec) {
        return Rec->ids.external;
    }

    command herp_opid_t OpTab.fetch_internal_id (const herp_oprec_t Rec) {
        return Rec->ids.internal;
    }

    command user_data * OpTab.fetch_user_data (const herp_oprec_t Rec) {
        return (user_data *) Rec->store;
    }

    command am_addr_t OpTab.fetch_owner (const herp_oprec_t Rec) {
        return Rec->owner;
    }

}
