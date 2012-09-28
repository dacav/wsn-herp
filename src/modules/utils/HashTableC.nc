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

generic configuration HashTableC (typedef key, typedef value, uint8_t SIZE) {

    provides interface HashTable<key, value>;

}

implementation {

    components MainC;
    components new HashTableP(key, value, SIZE / 3),
               new PoolC(struct hash_slot, SIZE) as SlotPool,
               new PoolC(key, SIZE) as KeyPool,
               new PoolC(value, SIZE) as ValuePool;

    MainC.SoftwareInit -> HashTableP;

    HashTableP.SlotPool -> SlotPool;
    HashTableP.KeyPool -> KeyPool;
    HashTableP.ValuePool -> ValuePool;

    HashTable = HashTableP;

}
