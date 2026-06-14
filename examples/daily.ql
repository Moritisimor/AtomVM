import "math"

type Point {
  x :: u8,
  y :: u8,
}

fn main() {
  let nums = [1, 2, 3]
  arraySet(nums, 1, 9)

  let p = Point { x: 4, y: 5 }
  let buf = alloc(1)
  memoryWrite(buf, 65)

  println("QuantumLang daily demo")
  println(len(nums))
  println(nums[1])
  println(p.x)
  println(triple(4))
  putc(memoryRead(buf))
  newline()
}
