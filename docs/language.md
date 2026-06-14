# quantumlang

quantumlang (or ql for short) is a language for the quantum vm, it takes inspiration from ocaml and sml on the type system side, c# and java for the oop-ish bits, and golang for the simplicity and concurrency model. its a weird blend but it works i think.

the current compiler implements the practical core first: functions, imports with source loading, `let`/`mut`/`const`, immutable binding checks, byte arrays, simple records, heap allocation, arithmetic, comparisons, `if`, `while`, counted `for`, `break`, `continue`, compound assignment, simple integer `case`, byte/char/string literals, assertions, memory access, string helpers, and the core library documented in [`stdlib.md`](stdlib.md). the rest of this file is the language direction, not a promise that every feature below is implemented today.

the core idea is that everything is an expression, types are inferred, and you dont need semicolons. like at all. the compiler figures it out.

## hello world

```
fn main() {
    print("hello, world")
}
```

simple. `fn` declares a function, `main` is the entry point, no parens needed around the args if theres none, and `print` is built in. no semicolons. no fuss.

## types

the type system is structural like go, not nominal like java. what matters is what a value can do, not what its named. but you CAN name types if you want, thats fine too.

```
// structural typing, this is the default
fn process(x) {
    // x just needs a .run() method, whatever type it is
    x.run()
}

// you can annotate if you want
fn process(x :: Runner) {
    x.run()
}
```

`::` is how you write type annotations. the `::` reads as "has type" in your head. `x :: i32` is "x has type i32".

### builtin types

```
i8, i16, i32, i64      // signed ints
u8, u16, u32, u64      // unsigned ints
f32, f64               // floats
bool                   // true or false
str                    // utf-8 string
char                   // single unicode codepoint
```

### compound types

```
[]i32                  // slice (dynamic array)
[i32; 10]              // fixed array of 10 elements
(i32, str)             // tuple of two elements
(i32, str, bool)       // tuple of three, etc
```

what works today is the byte-array core. array literals are memory objects with a length byte and byte elements:

```
let nums = [4, 5, 6]
println(len(nums))     // 3
println(nums[1])       // 5
```

so yes, arrays exist now, but theyre still byte arrays. generic slices are the direction, not the current implementation.

### records today

simple record types work too. fields are byte-sized for now and records live in vm memory.

```
type Point {
    x :: u8,
    y :: u8,
}

let p = Point { x: 3, y: 4 }
println(p.x)
```

this is the first useful version of structs: named fields, literals, and field reads. methods and richer field types come later.

### option and result

no null pointer dereferences. you get `Option[T]` and `Result[T, E]` instead. the compiler makes sure you handle both cases or it wont compile.

```
Option[T] = Some(T) | None
Result[T, E] = Ok(T) | Err(E)
```

```
fn find_user(id :: i32) -> Option[User] {
    if db.has(id) {
        Some(db.get(id))
    } else {
        None
    }
}

// usage
case find_user(42) {
    | Some(user) => greet(user)
    | None => print("not found")
}
```

## variables

`let` for stuff that doesnt change, `mut` for stuff that does, `const` for named values you want to read like part of the program. the compiler enforces this now: assign to a `let` or `const` and it fails before bytecode is written.

```
let x = 42              // x is i32, immutable
mut y = "hello"         // y is str, mutable
y = "world"              // fine
const answer = 42        // also immutable, good for top-level names

// explicit type if you want
let z :: f64 = 3.14
```

compound assignment works on mutable values:

```
mut total = 0
for i in 0..10 {
    total += i
}
```

right now values are still vm bytes unless youre dealing with string addresses. so think embedded/scripting language, not big integer math yet.

the type checker is small but real. it tracks byte values versus address values (`str`, `array`, heap addresses, and records), enforces immutable bindings, and rejects obvious byte/address assignment mistakes. it is not hindley-milner yet. thats still the plan, but this catches the mistakes that would corrupt the vm stack today.

## functions

functions are defined with `fn`, return type after `->`. the last expression is the return value, or you can use `return` early.

```
fn add(a :: i32, b :: i32) -> i32 {
    a + b    // implicit return
}

fn early(x :: i32) -> i32 {
    if x < 0 {
        return 0
    }
    x * 2
}
```

functions without a `->` dont return anything useful (they return `nil`).

closures are just anonymous functions:

```
let double = fn(x :: i32) -> i32 { x * 2 }
let numbers = map(double, [1, 2, 3])
```

## pipes

the `|>` operator pipes a value into a function call. its great for chaining.

```
let result = [1, 2, 3]
    |> filter(fn(x) { x > 1 })
    |> map(fn(x) { x * 2 })
    |> sum()
```

reads like "take this list, filter it, map it, sum it". no nesting hell.

## pattern matching

`case` is the match construct. its an expression, it returns a value. the compiler checks exhaustiveness so you cant forget a branch.

```
case x {
    | 0 => "zero"
    | 1 => "one"
    | n if n < 10 => "small"
    | _ => "big"
}
```

the `|` is optional on the first arm but required after that. `_` is the wildcard. `if` after the pattern is a guard.

you can destructure tuples and option types too:

```
let point = (10, 20)
case point {
    | (0, 0) => "origin"
    | (x, 0) => "on x axis at {x}"
    | (0, y) => "on y axis at {y}"
    | (x, y) => "at ({x}, {y})"
}
```

## algebraic types

you define them with `type` and `|` for variants:

```
type Color = Red | Green | Blue

fn main() {
    let c = Color::Green
    case c {
        | Red => { println("red") }
        | Green => { println("green") }
        | _ => { println("other") }
    }
}
```

that enum-style form works today. variants are byte-backed, and you can use either `Green` or `Color::Green`. payload-carrying variants are still the bigger next step:

```
type Tree[T] =
    | Leaf(T)
    | Node(Tree[T], Tree[T])

type Color =
    | Red
    | Green
    | Blue
    | Rgb(u8, u8, u8)
```

and pattern match on them:

```
fn depth(t :: Tree[i32]) -> i32 {
    case t {
        | Leaf(_) => 1
        | Node(left, right) => max(depth(left), depth(right)) + 1
    }
}
```

the second example is still the design target. the first enum example is the implemented one.

## shapes (interfaces)

shapes are structural interfaces. a type satisfies a shape automatically if it has the right methods. no `implements` keyword needed.

```
type Reader = shape {
    read(buf :: []u8) -> i64
}

// any type with a matching read method is a Reader
fn consume(r :: Reader) {
    // ...
}
```

## properties

like c# properties, get and set with custom logic but accessed like fields.

```
type Person {
    first :: str
    last :: str
    
    prop full_name :: str {
        get => "{self.first} {self.last}"
    }
    
    prop name_length :: i32 {
        get => self.full_name.len()
    }
}
```

## concurrency

goroutine-style with channels. `spawn` starts a lightweight thread, `wire` is a typed channel.

```
fn main() {
    ch = make(wire[i32], 10)  // buffered channel
    
    spawn fn() {
        for i in 0..10 {
            ch <- i            // send
        }
        close(ch)
    }
    
    for val in ch {             // receive until closed
        print(val)
    }
}
```

`wire[T]` is a typed channel. `<-` sends, the variable position receives. `for` over a wire iterates until closed.

## error handling with try

`try!` propagates errors through result types. if a function returns a Result, `try!` unwraps it or returns the error early.

```
fn read_config(path :: str) -> Result[Config, Error] {
    content = try! read_file(path)
    parsed = try! parse(content)
    Ok(parsed)
}
```

the `try!` is like `?` in rust but with a bang for visibility. if read_file returns Err, this function returns Err too. otherwise content is unwrapped.

## modules

every file is a module. explicit exports with `pub`.

```
// math.ql
pub fn square(x :: i32) -> i32 { x * x }
pub const PI :: f64 = 3.14159

fn internal_helper() { /* not exported */ }
```

```
// main.ql
import "math"

fn main() {
    print(math::square(5))
    print(math::PI)
}
```

`import` takes a string path (like go). the current compiler loads imported `.ql` files before the importing file, so functions and types from the imported file are available by name:

```
// math.ql
fn triple(x) { x * 3 }
```

```
// main.ql
import "math"

fn main() {
    println(triple(4))  // 12
}
```

namespaces with `math::triple` are still the design target. todays import system is real source loading and symbol sharing, not namespaced packages yet.

## for loops

```
// range
for i in 0..10 {
    print(i)
}

// collection
for item in items {
    process(item)
}

// wire (channel)
for msg in channel {
    handle(msg)
}

// conditional while
while condition {
    work()
}
```

`break` and `continue` do what you expect:

```
mut total = 0
for i in 0..10 {
    if i == 2 { continue }
    if i == 8 { break }
    total += i
}
```

the implemented `for` form today is the counted range form, `for i in start..end`. the more general collection and channel forms are still part of the design, not the current compiler.

## assertions

daily languages need a cheap way to say "this should be true". ql has `assert` and `assertEq` in the core library:

```
fn main() {
    const expected = 7
    assert(expected > 0)
    assertEq(expected, 7)
}
```

failed assertions exit the vm with code `1`. no fancy test runner yet, just something useful enough for scripts and examples.

## strings and memory today

strings are immutable literals stored in vm memory. you can print them, get their length, compare them, or print a fixed number of bytes:

```
println(len("hello"))       // 5
println(strcmp("a", "b"))  // 255, because byte -1 wraps on the vm
printBytes("abcdef", 3)     // abc
println("hello, " + "world") // literal concat
```

there are also raw memory helpers. theyre low level on purpose, because the vm is low level:

```
memoryWrite(300, 65)
putc(memoryRead(300))       // A
```

heap allocation exists now too:

```
let buf = alloc(2)
memoryWrite(buf, 65)
putc(memoryRead(buf))        // A
```

this is still manual and byte-level. it gives the language somewhere to put future dynamic strings, slices, maps, and channel buffers.

## the pipeline operator

`|>` is the star of the show. it takes the value on the left and passes it as the last argument to the call on the right.

```
"hello, world"
    |> str::to_upper()
    |> str::split(" ")
    |> array::map(fn(s) { s.len() })
```

## no classes

quantumlang doesnt have classes in the oop sense. you have types with functions that operate on them, and shapes for polymorphism. you can attach functions to types with `impl` blocks:

```
impl Point {
    fn magnitude(self) -> f64 {
        sqrt(self.x * self.x + self.y * self.y)
    }
}

let p = Point { x: 3.0, y: 4.0 }
print(p.magnitude())  // 5.0
```

its data and functions, just organized together.

## compiling

the quantum vm runs bytecode (`.bc` files). quantumlang compiles to that bytecode. the workflow is:

```
ql build file.ql -o file.bc   # compile
atomvm file.bc            # run
ql run file.ql            # compile and run, good for scripts
```

this is intentionally java-ish: `.ql` source turns into vm bytecode, and the vm runs the bytecode. the bytecode is not native machine code, so it can be inspected, moved around, and run anywhere atomvm runs.

## things that are different on purpose

- no semicolons. the compiler inserts them where they go
- no classes. you have types and impl blocks instead
- no null. option types for maybe-values
- no exceptions. result types for fallible operations
- no inheritance. shapes give you polymorphism without the class hierarchy
- no for loops with initializers or increments. just range iteration and while
- no checked exceptions (c# style) or throws declarations. result types handle everything
- no operator overloading (well maybe later)
- no macros (for now)
- no global mutable state (well you CAN but its frowned upon)
- no implicit conversions. types are strict
- no goto. obviously
- no pointer arithmetic. youre on a vm

## why would you use this

good question. its mostly an experiment in blending ml-style type systems with go-style simplicity and c#-style practicality. if you like ocaml but wish it had go channels and c# properties, this is for you. if you like go but wish it had algebraic types and pattern matching, this is also for you. if you like c# but wish it was simpler and had type inference, also for you.

its a vm language so it wont be as fast as native compiled stuff. but its supposed to be pleasant to write and reliable. the type system catches a lot of stuff at compile time.

## license

mit, same as the vm
