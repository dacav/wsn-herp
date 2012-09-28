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

generic configuration OperationIdC (uint16_t SIZE) {

    provides interface OperationId;

}

implementation {

    components MainC,
            new OperationIdP(SIZE),
            new BitVectorC(SIZE);

    MainC.SoftwareInit -> OperationIdP.Init;
    OperationIdP.InitBitVector -> BitVectorC.Init;
    OperationIdP.Free -> BitVectorC;

    OperationId = OperationIdP;

}
