(module
  (start $main)
  (memory 1)
  (global $g0 (export "g0") (mut i32) (i32.const 12))
  (global $g1 (export "g1") (mut i32) (i32.const 0))
  (global $g2  (export "g2") (mut i32) (i32.const 0))
  (func $main
    (global.get $g0)
    (call $fac) 
    (global.set $g1)
  )
  (func $fac (param $a i32)(result i32)(local $b i32)
     (local.get $a)(local.set $b)
     (loop $l (result i32)
        (local.get $b)
        (local.get $a)(i32.const 1)(i32.sub)(local.tee $a)
        (i32.mul)(local.set $b)
        (local.get $a)(i32.const 1)(i32.gt_u)
        (br_if $l)(local.get $b)
     )
   )
)