(module
  (type (;0;) (func))
  (type (;1;) (func (param i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)))
  (type (;2;) (func (param i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)))
  (type (;3;) (func (param i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) (result i32)))
  (start $main)
  (func $main (type 0)
    i32.const 0
    global.get $g0
    global.get $g1
    global.get $g2
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    call $store_vec10
    i32.const 40
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const -1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    call $store_vec10
    i32.const 80
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const -2
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    call $store_vec10
    i32.const 120
    i32.const 1
    i32.const 1
    i32.const 6
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    call $store_vec10
    i32.const 160
    i32.const 1
    i32.const 2
    i32.const 1
    i32.const 1
    i32.const 888
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    call $store_vec10
    i32.const 200
    i32.const 1
    i32.const 1
    i32.const 21
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 666
    i32.const 1
    i32.const 1
    i32.const 1
    call $store_vec10
    i32.const 240
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const -1
    i32.const 1
    i32.const 0
    i32.const 1
    i32.const 1
    i32.const 1
    call $store_vec10
    i32.const 280
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const -6
    i32.const 1
    i32.const 1
    call $store_vec10
    i32.const 320
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    call $store_vec10
    i32.const 360
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const -1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const 1
    i32.const -333
    call $store_vec10
    i32.const 0
    i32.const 0
    i32.const 0
    i32.const 1
    i32.const 2
    i32.const 3
    i32.const 4
    i32.const 5
    i32.const 6
    i32.const 7
    i32.const 8
    i32.const 9
    call $vmm10
    loop  ;; label = @1
      i32.const 0
      i32.const 20
      i32.const 1
      i32.const -1
      global.get $g10
      i32.const -1
      i32.const 0
      i32.const -1
      i32.const 1
      i32.const 2
      i32.const 1
      i32.const -1
      call $vmm10
      global.get $g10
      i32.const 1
      i32.add
      global.set $g10
      global.get $g10
      i32.const 1000000
      i32.lt_u
      br_if 0 (;@1;)
    end
    i32.const 0
    i32.const 40
    i32.const 4
    i32.const 3
    i32.const 7
    i32.const 9
    i32.const 0
    i32.const 9
    i32.const 6
    i32.const 6
    i32.const 5
    i32.const 7
    call $vmm10
    i32.const 0
    i32.const 60
    i32.const 2
    i32.const 3
    i32.const 12
    i32.const 3
    i32.const 0
    i32.const 9
    i32.const -1
    i32.const 8
    i32.const 5
    i32.const -1
    call $vmm10
    i32.const 0
    i32.const 80
    i32.const -1
    i32.const 1
    i32.const 30
    i32.const 2
    i32.const 6
    i32.const 9
    i32.const 26
    i32.const 8
    i32.const 1
    i32.const 12
    call $vmm10
    i32.const 0
    i32.const 63488
    i32.const -1
    i32.const 1
    i32.const 10
    i32.const 2
    i32.const 6
    i32.const 9
    i32.const 23
    i32.const 8
    i32.const 1
    i32.const 98
    call $vmm10
    i32.const 63488
    i32.load
    global.set $g0
    i32.const 63488
    i32.load offset=4
    global.set $g1
    i32.const 63488
    i32.load offset=8
    global.set $g2
    i32.const 63488
    i32.load offset=12
    global.set $g3
    i32.const 63488
    i32.load offset=16
    global.set $g4
    i32.const 63488
    i32.load offset=20
    global.set $g5
    i32.const 63488
    i32.load offset=24
    global.set $g6
    i32.const 63488
    i32.load offset=28
    global.set $g7
    i32.const 63488
    i32.load offset=32
    global.set $g8
    i32.const 63488
    i32.load offset=36
    global.set $g9)
  (func $store_vec10 (type 1) (param $addr i32) (param $0 i32) (param $1 i32) (param $2 i32) (param $3 i32) (param $4 i32) (param $5 i32) (param $6 i32) (param $7 i32) (param $8 i32) (param $9 i32)
    local.get $addr
    local.get $0
    i32.store
    local.get $addr
    local.get $1
    i32.store offset=4
    local.get $addr
    local.get $2
    i32.store offset=8
    local.get $addr
    local.get $3
    i32.store offset=12
    local.get $addr
    local.get $4
    i32.store offset=16
    local.get $addr
    local.get $5
    i32.store offset=20
    local.get $addr
    local.get $6
    i32.store offset=24
    local.get $addr
    local.get $7
    i32.store offset=28
    local.get $addr
    local.get $8
    i32.store offset=32
    local.get $addr
    local.get $9
    i32.store offset=36)
  (func $vmm10 (type 2) (param $addr_m i32) (param $addr_o i32) (param $0 i32) (param $1 i32) (param $2 i32) (param $3 i32) (param $4 i32) (param $5 i32) (param $6 i32) (param $7 i32) (param $8 i32) (param $9 i32)
    (local $flag i32)
    i32.const 0
    local.set $flag
    loop  ;; label = @1
      local.get $flag
      local.get $addr_o
      i32.add
      local.get $addr_m
      i32.load
      local.get $addr_m
      i32.load offset=4
      local.get $addr_m
      i32.load offset=8
      local.get $addr_m
      i32.load offset=12
      local.get $addr_m
      i32.load offset=16
      local.get $addr_m
      i32.load offset=20
      local.get $addr_m
      i32.load offset=24
      local.get $addr_m
      i32.load offset=28
      local.get $addr_m
      i32.load offset=32
      local.get $addr_m
      i32.load offset=36
      local.get $0
      local.get $1
      local.get $2
      local.get $3
      local.get $4
      local.get $5
      local.get $6
      local.get $7
      local.get $8
      local.get $9
      call $vmv10
      i32.store
      local.get $addr_m
      i32.const 40
      i32.add
      local.set $addr_m
      local.get $flag
      i32.const 4
      i32.add
      local.tee $flag
      i32.const 40
      i32.lt_u
      br_if 0 (;@1;)
    end)
  (func $vmv10 (type 3) (param $00 i32) (param $01 i32) (param $02 i32) (param $03 i32) (param $04 i32) (param $05 i32) (param $06 i32) (param $07 i32) (param $08 i32) (param $09 i32) (param $10 i32) (param $11 i32) (param $12 i32) (param $13 i32) (param $14 i32) (param $15 i32) (param $16 i32) (param $17 i32) (param $18 i32) (param $19 i32) (result i32)
    local.get $00
    local.get $10
    i32.mul
    local.get $01
    local.get $11
    i32.mul
    local.get $02
    local.get $12
    i32.mul
    local.get $03
    local.get $13
    i32.mul
    local.get $04
    local.get $14
    i32.mul
    local.get $05
    local.get $15
    i32.mul
    local.get $06
    local.get $16
    i32.mul
    local.get $07
    local.get $17
    i32.mul
    local.get $08
    local.get $18
    i32.mul
    local.get $09
    local.get $19
    i32.mul
    i32.add
    i32.add
    i32.add
    i32.add
    i32.add
    i32.add
    i32.add
    i32.add
    i32.add)
  (memory (;0;) 1)
  (global $g0 (mut i32) (i32.const 1))
  (global $g1 (mut i32) (i32.const 1))
  (global $g2 (mut i32) (i32.const 1))
  (global $g3 (mut i32) (i32.const 63488))
  (global $g4 (mut i32) (i32.const 0))
  (global $g5 (mut i32) (i32.const 0))
  (global $g6 (mut i32) (i32.const 0))
  (global $g7 (mut i32) (i32.const 0))
  (global $g8 (mut i32) (i32.const 0))
  (global $g9 (mut i32) (i32.const 0))
  (global $g10 (mut i32) (i32.const 0))
  (export "g0" (global 0))
  (export "g1" (global 1))
  (export "g2" (global 2))
  (export "g3" (global 3))
  (export "g4" (global 4))
  (export "g5" (global 5))
  (export "g6" (global 6))
  (export "g7" (global 7))
  (export "g8" (global 8))
  (export "g9" (global 9))
  (export "g10" (global 10))
  (export "_start" (func $main))
  (start $main))
