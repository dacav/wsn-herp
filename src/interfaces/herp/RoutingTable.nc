
 #include <RoutingTable.h>

interface RoutingTable {

    /**
     *
     * @retval RT_NONE if there's no route;
     * @retval RT_FRESH if the yielded route is fresh;
     * @retval RT_VERIFY if the yielded route must be verified;
     * @retval RT_WORKING if there's no fresh route but an operation is
     *                    already working on this job.
     */
    command rt_res_t get_route (am_addr_t To, rt_route_t *Out);

    /**
     *
     * @retval RT_OK on success;
     * @retval RT_WORKING someone is working already;
     * @retval RT_FAIL on failure.
     */
    command rt_res_t promise_route (am_addr_t To);

    /**
     *
     * @retval RT_OK on success;
     * @retval RT_FAIL if nobody promised anything.
     */
    command rt_res_t fail_promise (am_addr_t To);

    /**
     *
     * @retval RT_OK on success;
     * @retval RT_FAIL on failure.
     */
    command rt_res_t add_route (am_addr_t To, const rt_route_t *Route);

    /**
     *
     * @retval RT_OK on success;
     * @retval RT_FAIL on failure;
     */
    command rt_res_t drop_route (am_addr_t To, am_addr_t FirstHop);

    /**
     *
     * @retval RT_OK on success;
     * @retval RT_FAIL on failure;
     * @retval RT_NOT_WORKING if nobody is working (operation would
     *                        stall, so not enqueued).
     */
    command rt_res_t enqueue_for (am_addr_t To, herp_opid_t OpId);

    /**
     *
     * @param OpId The enqueued operation id;
     * @param Res RT_NONE, RT_FRESH or RT_VERIFY, semantics as in
     *            get_route();
     */
    event void deliver (herp_opid_t OpId, rt_res_t Res, am_addr_t To,
                        const rt_route_t *Route);

}
