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
