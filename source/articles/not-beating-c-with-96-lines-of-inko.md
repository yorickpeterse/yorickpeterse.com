---
{
  "title": "Not beating C with 96 lines of Inko",
  "date": "2019-11-22T12:00:00Z"
}
---

The article ["Beating C with 80 Lines of
Haskell"](https://chrispenner.ca/posts/wc) discusses writing a simplified
version of `wc` using Haskell, and how it performs compared to the C
implementation. This resulted in various other people writing the same program
in different languages, and writing about doing so. At the time of writing,
there are implementations for:

- [Ada](http://verisimilitudes.net/2019-11-11)
- [C](https://github.com/expr-fi/fastlwc/)
- [Common Lisp](http://verisimilitudes.net/2019-11-12)
- [Dyalog APL](https://ummaycoc.github.io/wc.apl/)
- [Futhark](https://futhark-lang.org/blog/2019-10-25-beating-c-with-futhark-on-gpu.html)
- [Go](https://ajeetdsouza.github.io/blog/posts/beating-c-with-70-lines-of-go/)
- [Haskell](https://chrispenner.ca/posts/wc)
- [Rust](https://medium.com/@martinmroz/beating-c-with-120-lines-of-rust-wc-a0db679fe920)

Today we will be taking a look at writing a similar program in
[Inko](https://inko-lang.org/).

## Benchmarking & setup

Several articles mentioned above include some benchmarking data, such as how
long it takes to count the words of a file with a certain size (e.g. 1GB).
While we will also discuss some benchmarking data, it's important to not focus
on them too much. Instead, the numbers discussed below should be treated as
rough estimates at best.

For this article we will be comparing the Inko implementation to GNU `wc`
version 8.31, running on a 7th generation Thinkpad X1 Carbon. The CPU is a Intel
Core i5-8265U. The CPU governor used is the "performance" governor, and the
clock speed is 3.8 Ghz. The OS is Arch Linux running Linux kernel version
5.3.11. The storage device is an NVMe SSD.

## Implementation

Like the other implementations, our implementation expects ASCII input. We also
won't implement any command-line options, or other features of `wc`. Our input
set will be [this file](https://github.com/ChrisPenner/wc/blob/master/data/big.txt)
from the Haskell implementation. The file size is 6.2 MB.

For our Inko implementation we will take an approach to counting words similar
to the Go (and other) implementations: we read our input into a byte array, in
chunks of 64 KB. When we encounter a whitespace character, we set a flag and
increment the line count. When we reach a non-whitespace character and the flag
is set, we increment the word count and unset the flag. We repeat this until we
have consumed all input bytes.

## Importing our dependencies

Let's start by importing the types and modules we need:

```inko
import std::byte_array::ByteArray
import std::env
import std::fs::file
import std::pair::Pair
import std::process
import std::stdio::stdout
import std::string_buffer::StringBuffer
```

ByteArray stores a sequence of bytes, as actual bytes and not as (signed)
integers. This means a ByteArray of 4 bytes needs 1 byte per value, instead of 8
bytes (when using an integer). This type is not imported by default, so we have
to explicitly import it.

The module `std::fs::file` provides file IO types and methods. Inko uses
different types for files based on the open mode, such as `ReadOnlyFile` for
read-only files. We will see this in action later.

Pair is a binary tuple. We will use this so we don't have to define our own
types for in several places.

Unlike languages such as Ruby, operations using STDERR, STDOUT, and STDIN
require you to import the appropriate modules; instead of relying on global
methods or types. The module `std::stdio::stdout` is used for writing to STDOUT.

Our last import is the importing of the `StringBuffer` type. Inko does not have
string interpolation or formatting, so concatenating strings together (without
producing intermediate strings) requires the use of the `StringBuffer` type.
This is a bit clunky, but it's good enough for now.

## Constants

Next we will define several constants that we need to access in several methods:

```inko
let CONCURRENCY = 8
let MAIN = process.current
let NEWLINE = 10
let SINGLE_SPACE = 32
let SPACE_RANGE = 9..13
```

The `CONCURRENCY` constant controls the number of processes we will spawn to
count words. The simplest approach would be to spawn one process for every
chunk. Since the work is purely CPU bound doing so doesn't improve performance
if we end up spawning more processes than the number of CPU cores.

The `MAIN` constant stores an object containing information about the current
process. All processes we spawn for counting words will send their results to
this process.

The next three constants define some byte values: byte 10 is the Unix newline
separator, byte 32 is a single space, and the range `9..13` covers all ASCII
whitespace characters (newlines, tabs, etc). In Inko `A..B` creates an inclusive
range from A to B.

## Counting words

It's time to define the methods and types we need to count the words in a
`ByteArray`, starting with two methods: `space?` and `worker_loop`:

```inko
def space?(byte: Integer) -> Boolean {
  SPACE_RANGE.cover?(byte).or { byte == SINGLE_SPACE }
}

def worker_loop {
  let chunk = process.receive as Chunk

  MAIN.send(chunk.count)

  worker_loop
}
```

The `space?` method returns `True` if the input byte is a whitespace character,
such as a single space or a newline. Inko has no if/else/or/and statements,
instead it uses messages, methods, and closures. Instead of writing `A || B`,
you would write `A.or { B }`, where `or` is a message sent to `A`. The curly
braces `{ B }` denote a closure, which in this case returns whatever `B` is.

The `worker_loop` method is a tail-recursive method called by the processes that
count words. Each loop the process will wait for an incoming message using
`process.receive`. Sending messages to processes uses dynamic typing, and Inko
is pretty strict about dynamic typing. For example, passing a dynamic type
(`Dynamic`) as an argument does not work if a non-dynamic type (e.g. `Integer`)
is expected. Sending messages to a dynamic type is fine, and will produce a new
dynamic type. This means we could condense this method to the following:

```inko
def worker_loop {
  MAIN.send(process.receive.count)

  worker_loop
}
```

The reason we don't do this is to make it more clear what input we expect in
this method, and to prevent us from using the wrong method(s).

Inko supports tail call elimination, so our `worker_loop` method will not
overflow the stack. We could also use a closure and send the `loop` message to
it:

```inko
def worker_loop {
  {
    let chunk = process.receive as Chunk

    MAIN.send(chunk.count)
  }.loop
}
```

This achieves the same results and in fact `loop` is implemented using tail
recursion. Since using tail recursion ourselves in this method requires a little
less code we just use that, instead of using `loop`.

Now it's time to create an object used for counting words, which we will call
`Chunk`. This type will hold some state, such as the bytes to process and the
number of lines counted so far. We use a dedicated type so it's a bit easier to
send input to the word counting processes, and so we can use tail recursion when
iterating over the bytes to process. We define objects using the `object`
keyword:

```inko
object Chunk {

}
```

Object attributes need to be defined explicitly when we define the object, so
let's do that:

```inko
object Chunk {
  @previous_is_space: Boolean
  @bytes: ByteArray
  @lines: Integer
  @words: Integer
  @index: Integer
}
```

In Inko we define and refer to attributes using the syntax `@NAME`. The `@` is
part of the name, so it's valid to define both an attribute `@foo` and a method
`foo`. When defining attributes we must also specify the type, such as `Integer`
for the attribute `@index`. The attribute `@previous_is_space` is used to record
if a previously processed byte was a whitespace character.

Now we need to define our initialiser method, which is always called `init`:

```inko
def init(previous_is_space: Boolean, bytes: ByteArray) {
  @previous_is_space = previous_is_space
  @bytes = bytes
  @lines = 0
  @words = 0
  @index = 0
}
```

This method just sets the attributes to the right value. If we forget to set an
attribute in the `init` method, the compiler will produce an error.

We can now define a method to count words and lines, which we will creatively
name "count":

```inko
def count -> Pair!(Integer, Integer) {
  let byte = @bytes[@index]

  byte.nil?.if_true {
    return Pair.new(@lines, @words)
  }

  space?(byte!).if(
    true: {
      (byte == NEWLINE).if_true {
        @lines += 1
      }

      @previous_is_space = True
    },
    false: {
      @previous_is_space.if_true {
        @words += 1
        @previous_is_space = False
      }
    }
  )

  @index += 1

  count
}
```

That's quite a lot to take in, so let's break it down. We start by obtaining the
current byte, and checking if it's `Nil`. Accessing an out of bounds index in a
`ByteArray` is valid, and returns `Nil`. When this is the case we have consumed
all input, and we can return the number of lines and words we have counted.
Instead of creating a custom object to store the lines and words, we use the
`Pair` type.

Remember that Inko does not have `if` statements, and instead uses messages and
method calls. Here `if_true` is sent to the result of `byte.nil?`, and the
closure passed as its argument will only be run if `byte.nil?` produced boolean
true.

Next up we have the code that determines what to do with the current byte:

```inko
space?(byte!).if(
  true: {
    (byte == NEWLINE).if_true {
      @lines += 1
    }

    @previous_is_space = True
  },
  false: {
    @previous_is_space.if_true {
      @words += 1
      @previous_is_space = False
    }
  }
)
```

We use the `space?` method we defined earlier on, and pass it the current byte.
We use `byte!` instead of just `byte`, as the type of `byte` is `?Integer` (an
Integer or Nil). Since `space?` expects an `Integer`, we have to cast our `byte`
variable to the right type. Doing this by hand gets tedious, so Inko offers the
`!` postfix operator to do just that.

Once we have obtained the result of `space?`, we send the `if` message to it and
pass two arguments: a closure to run when the receiver is true, and a closure
for when the receiver is false. Here `true:` and `false:` are just keyword
arguments used to clarify the purpose of the closures.

The last two lines are pretty simple: we just increment the byte index by 1,
then tail recurse back into the `count` method.

## Scheduling work

Now that we have our methods and types in place, we can start scheduling the
work. We'll start by opening the file in read-only mode, making sure a file is
actually provided:

```inko
env.arguments[0].nil?.if_true {
  process.panic('You must specify a file to process')
}

let path = env.arguments[0]!
let input = try! file.read_only(path)
```

`env.arguments[0]` returns the first command-line argument, or `Nil` if no
there are no arguments. If this happens, we exit the program with a
[panic](https://inko-lang.org/manual/getting-started/error-handling/#header-panics).

Our file is opened using `file.read_only(path)`, which opens the file `path`
points to in read-only mode. We use `try!` to cause a panic if the file could
not be opened, since there isn't much we can do without being able to open the
file.

Bored yet? No? Good, we're almost there!

Now it's time to start our worker processes, and to start scheduling work:

```inko
let workers =
  CONCURRENCY.times.map do (_) { process.spawn { worker_loop } }.to_array

let mut bytes = 0
let mut words = 0
let mut lines = 0
let mut previous_is_space = True
let mut jobs = 0
let buffer = ByteArray.new
```

The `workers` assignment is the most interesting. The bit
`CONCURRENCY.times.map` creates an iterator that runs 8 times (since we set
`CONCURRENCY` to 8), mapping the input value (an integer ranging from 0 to 7) to
the result of `process.spawn`. Since we don't care about the input integer, we
define the argument name as `_`. We then collect the results into an `Array`
using the `to_array` message. Each spawned process runs the `worker_loop`
method, until the program is finished. The other variables are not interesting,
so let's skip those.

We will divide work across the processes in a round-robin fashion, until we run
out of bytes to read. Every process is given a chunk of equal size:

```inko
{
  try! input.read_bytes(bytes: buffer, size: CHUNK_SIZE).positive?
}.while_true {
  workers[jobs % workers.length]
    .send(Chunk.new(previous_is_space: previous_is_space, bytes: buffer))

  previous_is_space = space?(buffer[-1]!)

  bytes += buffer.length
  jobs += 1

  buffer.clear
}
```

We create a closure that returns the result of
`input.read_bytes(...).positive?`, which is a boolean. The result of
`input.read_bytes(...)` is an integer signaling the number of bytes read. If the
operation fails, we panic (by using the `try!` keyword). The method `read_bytes`
reads bytes _into_ a provided `ByteArray`, instead of returning a `ByteArray`.

`while_true` is a message sent to this closure, and will run its argument (also
a closure) as long as the receiver returns boolean true.

Work is balanced across processes by sending the chunks to processes:

```inko
workers[jobs % workers.length]
  .send(Chunk.new(previous_is_space: previous_is_space, bytes: buffer))
```

The expression `jobs % workers.length` produces an integer/index between zero
and the last index in the `workers` array. Since the `workers` `Array` stores
`Process` objects, we can just send `send` to them to have the message (a
`Chunk` object in this case) sent to the process.

Since we perform work in parallel, we have to determine if a chunk follows
whitespace when scheduling them. We do this using `previous_is_space =
space?(buffer[-1]!)`. Inko allows you to access negative indexes of `Array` and
`ByteArray` types, which translate to indexes from the end of the list. In other
words, the index -1 accesses the last element in the list.

After this we just increment the number of bytes read, the number of jobs
scheduled, and we clear our buffer. We reuse the same `ByteArray` so we don't
have to create a new one for every 64 KB of bytes that we read.

Now we can wait for all the results to be sent back from our workers, then
present them:

```inko
{ jobs.positive? }.while_true {
  let count = process.receive as Pair!(Integer, Integer)

  lines += count.first
  words += count.second

  jobs -= 1
}

stdout.print(StringBuffer.new(
  ' ',
  lines.to_string,
  ' ',
  words.to_string,
  ' ',
  bytes.to_string,
  ' ',
  path
))
```

Here we wait for incoming messages, cast them to the right type (a Pair
of the number of lines and words), then add the results to the total number of
lines and words. Lastly, we present the results by writing them to STDOUT.

Our final version looks like this:

```inko
import std::byte_array::ByteArray
import std::env
import std::fs::file
import std::pair::Pair
import std::process
import std::stdio::stdout
import std::string_buffer::StringBuffer

let CONCURRENCY = 8
let MAIN = process.current
let NEWLINE = 10
let SINGLE_SPACE = 32
let SPACE_RANGE = 9..13
let CHUNK_SIZE = 64 * 1024

def space?(byte: Integer) -> Boolean {
  SPACE_RANGE.cover?(byte).or { byte == SINGLE_SPACE }
}

def worker_loop {
  let chunk = process.receive as Chunk

  MAIN.send(chunk.count)

  worker_loop
}

object Chunk {
  @previous_is_space: Boolean
  @bytes: ByteArray
  @lines: Integer
  @words: Integer
  @index: Integer

  def init(previous_is_space: Boolean, bytes: ByteArray) {
    @previous_is_space = previous_is_space
    @bytes = bytes
    @lines = 0
    @words = 0
    @index = 0
  }

  def count -> Pair!(Integer, Integer) {
    let byte = @bytes[@index]

    byte.nil?.if_true {
      return Pair.new(@lines, @words)
    }

    space?(byte!).if(
      true: {
        (byte == NEWLINE).if_true {
          @lines += 1
        }

        @previous_is_space = True
      },
      false: {
        @previous_is_space.if_true {
          @words += 1
          @previous_is_space = False
        }
      }
    )

    @index += 1

    count
  }
}

env.arguments[0].nil?.if_true {
  process.panic('You must specify a file to process')
}

let path = env.arguments[0]!
let input = try! file.read_only(path)

let workers =
  CONCURRENCY.times.map do (_) { process.spawn { worker_loop } }.to_array

let mut bytes = 0
let mut words = 0
let mut lines = 0
let mut previous_is_space = True

let mut jobs = 0
let buffer = ByteArray.new

{
  try! input.read_bytes(bytes: buffer, size: CHUNK_SIZE).positive?
}.while_true {
  workers[jobs % workers.length]
    .send(Chunk.new(previous_is_space: previous_is_space, bytes: buffer))

  previous_is_space = space?(buffer[-1]!)

  bytes += buffer.length
  jobs += 1

  buffer.clear
}

{ jobs.positive? }.while_true {
  let count = process.receive as Pair!(Integer, Integer)

  lines += count.first
  words += count.second

  jobs -= 1
}

stdout.print(StringBuffer.new(
  ' ',
  lines.to_string,
  ' ',
  words.to_string,
  ' ',
  bytes.to_string,
  ' ',
  path
))
```

## Performance

Let's start by running GNU `wc` to see how it performs:

```
$ time -f "%es %MKB" wc big.txt
 128457 1095695 6488666 big.txt
0.03s 2136KB
```

This only took 0.03 seconds (30 milliseconds), and used a peak RSS of 2.08 MB.
Not bad!

Now let's see how our Inko implementation performs:

```
$ time -f "%es %MKB" inko wc.inko big.txt
 128457 1095695 6488666 big.txt
8.34s 260272KB
```

Ouch! Our implementation uses a peak RSS of 254 MB, and takes 8.34 seconds to
count the words and lines. What's going on here? Is our implementation bad, or
is Inko just slow?

Well, sort of. Our implementation isn't bad at all. Maybe it would be a bit
nicer if we wouldn't have to use the `StringBuffer` type, but apart from that
there is not a lot worth changing. Instead, the problem is Inko. More precisely,
the complete lack of optimisations applied by Inko's compiler.

### Optimisations, or lack thereof

When creating a programming language you need a compiler to compile your
language. The first compiler thus needs to be written in a different language.
For Inko I opted to use Ruby since it's widely available, and a language I have
worked with for almost ten years. The goal is to rewrite Inko's compiler in Inko
itself, something that is actively worked on.

Because we want to replace the Ruby compiler with a compiler written in Inko, we
spent little time on adding optimisations to the Ruby compiler. In fact, the
only optimisations it applies are:

1. Tail call elimination
1. Replacing keyword arguments passed in-order with positional arguments

Other languages typically perform some form of method inlining, constant
folding, optimising certain method calls into specialised instructions (e.g.
translating `A + B` into something that doesn't require a method call), etc.
Inko's current compiler does none of that, producing code that does not perform
as well as it should.

### Closure allocations

This brings us to the main problem of our implementation: closure allocations.
Specifically, the use of closures instead of statements such as `if` and
`while`. Allocating a closure is not that expensive, but in our implementation
of `wc` we are allocating a lot. Our `count` method alone will create at least
five closures for every byte. For a 64 KB chunk that results in a total of 327
680 closures. More allocations also means more garbage collections. While we can
reuse memory after a collection, collections still take up time.

To combat this we plan to add an optimisation pass to the self-hosting compiler
that will eliminate closure allocations where possible. For example, cases such
as `if_true` and `if_false` can be optimised to not use closures at all. It's
hard to say how big the impact of this would be on our `wc` implementation, but
I would not be surprised if we can cut the runtime in half; or maybe reduce it
even more.

### Garbage collection performance

Another problem we are running into is that Inko's garbage collector is spending
far more time tracing objects than should be necessary. Under normal
circumstances Inko's garbage collector is able to trace lots of objects in less
than one millisecond, but for our `wc` implementation it can take several
milliseconds to trace 20-30 objects. We can see this by running our `wc`
implementation while setting the environment variable `INKO_PRINT_GC_TIMINGS` to
`true` (some output is removed to keep things readable):

```
$ env INKO_PRINT_GC_TIMINGS=true time -f "%es %MKB" inko wc.inko big.txt
[0x7fb240004ec0] GC in 2.528122ms, 28 marked, 0 promoted, 0 evacuated
[0x7fb240004670] GC in 15.437073ms, 28 marked, 0 promoted, 0 evacuated
[0x7fb240005630] GC in 28.714244ms, 28 marked, 0 promoted, 0 evacuated
[0x7fb240007440] GC in 30.711002ms, 28 marked, 0 promoted, 0 evacuated
```

This even happens when we limit the number of tracing threads to 1, instead of
the default of half the number of CPU cores:

```
$ env INKO_TRACER_THREADS=1 \
    INKO_PRINT_GC_TIMINGS=true time -f "%es %MKB" inko wc.inko big.txt
[0x7fdbfc005dd0] GC in 581.006µs, 28 marked, 0 promoted, 0 evacuated
[0x7fdbfc005630] GC in 2.047803ms, 28 marked, 0 promoted, 0 evacuated
[0x7fdbfc007bb0] GC in 918.097µs, 28 marked, 0 promoted, 0 evacuated
[0x7fdbfc004ec0] GC in 1.104836ms, 28 marked, 0 promoted, 0 evacuated
```

The timings may be a bit better, but they are still pretty bad given we end up
only marking a small number of objects. Take the following program as an
example:

```inko
object Thing {}

let things = 28.times.map do (_) { Thing.new }.to_array

1_000_000.times.each do (integer) {
  integer.to_float
}
```

Here we create an array containing 28 `Thing` instances, which we keep around.
We then create one million float objects, which are heap allocated. If we run
this with the `INKO_PRINT_GC_TIMINGS` variable set, the output is as follows:

```
$ env INKO_PRINT_GC_TIMINGS=true inko foo.inko
[0x5620ad17df70] GC in 523.047µs, 44 marked, 0 promoted, 0 evacuated
[0x5620ad17df70] GC in 480.612µs, 46 marked, 0 promoted, 0 evacuated
[0x5620ad17df70] GC in 493.339µs, 63 marked, 43 promoted, 0 evacuated
[0x5620ad17df70] GC in 552.766µs, 9 marked, 0 promoted, 0 evacuated
```

These timings are much closer to what one would expect.

It's not quite clear yet what is causing this slowdown. Based on some profiling
using Valgrind I suspect the
[crossbeam](https://github.com/crossbeam-rs/crossbeam) library (which we use in
the garbage collector) is to blame, as Valgrind's data suggests most time is
spent in crossbeam code; even though the code should be fast. The crossbeam
types we use rely on an epoch based garbage collection mechanism, and per [this
crossbeam
RFC](https://github.com/crossbeam-rs/rfcs/blob/master/text/2017-05-23-epoch-gc.md#oversubscription)
it seems this may not work too well when spawning lots of short-lived threads;
as is done when tracing objects.

A possible solution would be to use a fixed-size thread pool for tracing
objects, instead of spawning tracing threads on-demand. We do not use this
approach at the moment because the current approach is easier to implement. An
approach I have been thinking of is to give each collector thread its own pool
of tracing threads, spawned when the collector threads first starts up. This
approach means a tracing pool only ever collects a single process at a time,
allowing us to pass certain data around once (= when starting the tracing),
instead of having to pass it around with every new job that is scheduled. This
is something I will have to take a look at in the coming weeks.

## Wrapping up

We did not manage to beat C with Inko, but that was never the goal of this
exercise. Instead, I merely wanted to showcase how one would approach the
problem using Inko, and get more people interested in Inko as a result.

The optimisations discussed will be applied over time, gradually improving
performance of Inko. One day we will also add a JIT, though I suspect it will
take several years before we will have a JIT. The potential crossbeam bottleneck
is also worth investigating.

I doubt a dynamic language such as Inko will be able to beat C, but if we can at
least beat other dynamic languages (e.g. Ruby) that is good enough.

For more information about Inko, take a look at the [Inko
website](https://inko-lang.org/) or the [Git
repository](https://gitlab.com/inko-lang/inko). If you would like to sponsor the
development of Inko with a small monthly contribution, please take a look at the
[sponsors page](https://inko-lang.org/sponsors/) for more information.
