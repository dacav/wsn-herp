 #include <Types.h>

interface OperationId {

    command error_t get (herp_opid_t * Id);

    command error_t put (herp_opid_t Id);

}
