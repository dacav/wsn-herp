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

generic configuration OperationTableC (typedef user_data, uint8_t SIZE) {
    provides interface OperationTable<user_data>;
}

implementation {

    components new OperationTableP(user_data) as OpTabP;

    components
            new PoolC(user_data, SIZE),
            new OperationIdC(SIZE),
            new HashTableC(herp_opid_t, struct herp_oprec, SIZE) as IntMapC,
            new HashTableC(herp_pair_t, herp_opid_t, SIZE) as ExtMapC;

    OpTabP.UserDataPool -> PoolC;
    OpTabP.OperationId -> OperationIdC;
    OpTabP.IntMap -> IntMapC;
    OpTabP.ExtMap -> ExtMapC;

    OperationTable = OpTabP;
}
