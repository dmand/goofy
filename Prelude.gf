module Prelude where

fun id x = x

fun f (x, _) = x
fun s (_, x) = x

val compose = (fn f => fn g => (fn x => (g (f x))))
val . = compose

fun not true = false
  | not false = true

fun or true = fn x => true
  | or false = fn x => x

fun and true = fn x => x
  | and false = fn x => false

fun xor true = fn x => not x
  | xor false = fn x => x

fun charToInt' "0" = 0
  | charToInt' "1" = 1
  | charToInt' "2" = 2
  | charToInt' "3" = 3
  | charToInt' "4" = 4
  | charToInt' "5" = 5
  | charToInt' "6" = 6
  | charToInt' "7" = 7
  | charToInt' "8" = 8
  | charToInt' "9" = 9
  | charToInt' _ = error "charToInt' got non-digit character"

fun charToInt x =
  if (length x) `eq` 1 then
    charToInt' x
  else
    error "charToInt can only handle 1-character strings"

fun strToInt' (x, acc)  =
  if (length x) `eq` 0 then
    acc
  else
    strToInt' (tail x, (acc `times` 10) `plus` (charToInt (head x)))

fun strToInt x = strToInt' (x, 0)

val readInt = read `compose` strToInt