---
{
  "title": "Building a simple key-value database in Inko",
  "date": "2025-03-24T00:00:00Z"
}
---

After publishing the recent [0.18.1 release of
Inko](https://inko-lang.org/news/inko-0-18-1-is-released/), I spent a few weeks
building a simple key-value database in Inko. The result of this work is
[KVI](https://github.com/yorickpeterse/kvi), a Key Value database written in
Inko. One might wonder: why exactly write a simple key-value database when so
many already exist? Let's find out!

## [Table of contents]{toc-ignore}

::: toc
:::

## Why?

Inko being a young language means there's not much written in it. Yes, I wrote a
[program to control my HVAC system](https://github.com/yorickpeterse/openflow)
or to [generate changelogs](https://github.com/yorickpeterse/clogs), but both
programs are quite niche. To give potential users a better understanding of what
programs written in Inko look like, I want to showcase something a little more
complex and something that caters towards a wider audience. I also want a set
of programs that can be used to test new Inko features, and measure its
performance over time.

A (simple) key-value database is perfect for this: it involves a bit of network
IO, some parsing, use of various data structures, concurrency, and more, but the
complexity is still manageable.

## The architecture

KVI uses the [Redis serialization
protocol](https://redis.io/docs/latest/develop/reference/protocol-spec/),
specifically version three. The choice to use an existing protocol is
deliberate:

1. It means you can use existing tools (e.g. the Redis CLI) to interact with the
   database
1. It makes for a more realistic application as it has to deal with an existing
   (and rather messy, but more on that later) protocol, instead of using a
   custom and hyper optimized (binary) protocol
1. I didn't want to get distracted designing the "perfect" protocol, similar to
   how many people that want to write a game get distracted by building a game
   engine from scratch and never actually release a game as a result

### Supported commands

To keep things simple, KVI only implements the following Redis commands:

- `HELLO` with protocol version 3
- `GET key`
- `SET key value` (no support for timeouts)
- `DEL key` (only a single key can be removed per command)
- `KEYS` (patterns aren't supported)

### Signal handling

The database responds to the following signals: `SIGINT`, `SIGTERM` and
`SIGQUIT`, ignoring other signals. To handle signals, a process is spawned for
each signal. Upon receiving the signal, the main process is notified about the
signal, which then determines how to handle it. This is achieved using the
[`std.signal.Signals`](https://docs.inko-lang.org/std/main/module/std/signal/Signals/)
type, which will be available in the upcoming 0.19.0 release:

```inko
fn start(config: Config) -> Result[Nil, String] {
 ...

  let signals = Signals.new

  signals.add(Signal.Interrupt)
  signals.add(Signal.Terminate)
  signals.add(Signal.Quit)

  loop {
    match signals.wait {
      case Interrupt or Terminate -> {
        logger.info('shutting down gracefully')
        break
      }
      case _ -> return Result.Ok(nil)
    }
  }

  ...
}
```

### Logging

KVI logs some basic information in a few places, such as when establishing a new
connection or rejecting an invalid command. This is done using the `Logger`
type, which is backed by a `LogWriter` process. The `Logger` type determines if
a log message should be published based on its log level. If so, it sends the
message to the `LogWriter` which writes it to STDERR. The `Logger` type is
cloned whenever a process needs to log messages, resulting in all processes
using the same underlying `LogWriter` and allowing for concurrent logging.


```graph
┌───────────┒      ┌────────┒      ┌───────────┒      ┌────────┒
│ Process 1 ┠─────►│ Logger ┠─────►│ LogWriter ┠─────►│ STDERR ┃
┕━━━━━━━━━━━┛      ┕━━━━━━━━┛      ┕━━━━━━━━━━━┛      ┕━━━━━━━━┛
                                         ▲
┌───────────┒      ┌────────┒            │
│ Process 2 ┠─────►│ Logger ┠────────────┘
┕━━━━━━━━━━━┛      ┕━━━━━━━━┛
```

When running unit tests logging should be disabled such that it doesn't clutter
the test output. Rather than apply a complex setup involving mocks and what not,
the `Logger` type supports a `none` log level which results in it ignoring all
log messages:

```inko
type copy enum Level {
  case Debug
  case Info
  case Warn
  case Error
  case None

  ...
}

type inline Logger {
  let @writer: LogWriter
  let @level: Level
  let @label: String

  ...

  fn mut info(message: String) {
    write(Level.Info, message)
  }

  fn mut write(level: Level, message: String) {
    if level >= @level { @writer.write(level, @label, message) }
  }
}
```

Look ma, no mocks!

::: info
In Inko, you define fields using the syntax `let @name: Type` and refer to them
using the syntax `@name`.
:::

### Requests and responses

Handling of requests and their responses is done using a set of sockets and
Inko's lightweight processes.

One or more sockets wait for incoming connections. Each such socket is backed by
an Inko process, and is referred to as an "accepter" because it _accepts_ new
connections. By default only a single accepter process is started, but the KVI
CLI allows you to specify a different number of processes, all listening on the
same address. These sockets use the `SO_REUSEADDR` and `SO_REUSEPORT` options
(where available) such that incoming connections can be distributed across these
sockets.

```graph
                        ┌────────────┒
                    ┌──►│ Accepter 1 ┃
                    │   ┕━━━━━━━━━━━━┛
┌────────────────┒  │   ┌────────────┒
│ New connection ┠──┼──►│ Accepter 2 ┃
┕━━━━━━━━━━━━━━━━┛  │   ┕━━━━━━━━━━━━┛
                    │   ┌────────────┒
                    └──►│ Accepter 3 ┃
                        ┕━━━━━━━━━━━━┛
```


This is useful for servers that have to handle _many_ incoming
connections, as using a single socket in such cases may result in the accept
loop becoming a bottleneck.

Each accepter process spawns a separate "connection" process that's in charge
of handling the new connection, such as processing incoming commands. Inko
processes are lightweight, meaning it's fine to spawn tens of thousands of such
processes to handle many connections concurrently.

```graph
                        ┌────────────┒    ┌──────────────┒
                    ┌──►│ Accepter 1 ┠───►│ Connection 1 ┃
                    │   ┕━━━━━━━━━━━━┛    ┕━━━━━━━━━━━━━━┛
┌────────────────┒  │   ┌────────────┒    ┌──────────────┒
│ New connection ┠──┼──►│ Accepter 2 ┠───►│ Connection 2 ┃
┕━━━━━━━━━━━━━━━━┛  │   ┕━━━━━━━━━━━━┛    ┕━━━━━━━━━━━━━━┛
                    │   ┌────────────┒    ┌──────────────┒
                    └──►│ Accepter 3 ┠───►│ Connection 3 ┃
                        ┕━━━━━━━━━━━━┛    ┕━━━━━━━━━━━━━━┛
```

The connection processes don't store any key-value pairs though, those are
instead stored in a "shard". A shard is just a process that owns a hash map that
maps the keys to their values. By default the number of shards is equal to the
number of CPU cores, but again one can change this using the CLI.

To determine which shard to use for operations on different keys, KVI uses
[rendezvous hashing](https://en.wikipedia.org/wiki/Rendezvous_hashing). First,
the connection process reads the key name and generates a hash code for it. The
same key always hashes to the same hash code within the same OS process, though
the hash codes may differ between restarts of the server. The hash function used
is SipHash-1-3, mainly because Inko's standard library provides [an
implementation of this hash
function](https://docs.inko-lang.org/std/v0.18.1/module/std/hash/siphash/SipHasher13/)
and I didn't want to implement a faster hash function just for KVI.

Once the hash code is generated, it's used as part of the rendezvous hash
function to determine the shard to use. For this to work, each connection
process is given a copy of the list of shards. This may sound expensive, but
this list is just a list of references to process (i.e. pointers) and thus needs
only a little bit of memory.

```inko
type inline Shards {
  let @shards: Array[Shard]

  ...

  fn select(hasher: Hasher, hash: Int) -> Shard {
    let mut shard = 0
    let mut max = 0
    let len = @shards.size

    for idx in 0.until(len) {
      let shard_hash = hasher.hash((idx, hash))

      if shard_hash > max {
        shard = idx
        max = shard_hash
      }
    }

    @shards.get(shard).or_panic
  }
}
```

Once the connection determines which shard to use, it sends the shard process a
message corresponding to the operation (e.g. "get" for the `GET` command). The
exact list of arguments differs per message, but at minimum each message expects
the following arguments:

1. A reference to the connection that requested the operation, such that the
   shard knows where to send the socket back to
1. The socket to write the data to
1. The key to operate on, if relevant

For example, the definition of the `get` message (with the types simplified for
the sake of readability) is as follows:

```inko
type async Shard {
  ...

  fn async mut get(connection: Connection, key: uni Key, socket: uni Socket) {
    ...
  }
}
```

If you're not familiar with what this means: `type async` defines a process, an
`fn async` defines a message you can send to the process. The `async` keyword
has nothing to do with async/await as found in other languages, and there's no
function coloring in Inko. The `uni` keyword is used to signal that a value is
_unique_, meaning there's only a single reference to it (at least from the
outside world) and thus makes it safe to move the value between processes.

::: info
To learn more, refer to the [Hello,
concurrency!](https://docs.inko-lang.org/manual/v0.18.1/getting-started/hello-concurrency/)
and [Concurrency and recovery](https://docs.inko-lang.org/manual/v0.18.1/getting-started/concurrency/)
guides in the Inko manual.
:::

Upon receiving the message the shard performs the necessary work, writes the
result to the socket, then sends the socket back to its connection process (by
sending it the `resume` message) such that it can process the next command.

```graph
                 1: key
┌────────────┒ ───────────► ╭───────────────────╮
│ Connection ┃ ◄─────────── │ rendezvous-hash() │
┕━━━━━━━━━┯━━┛   2: shard   ╰───────────────────╯
    ▲     │
    │     │
    │     │
    │     │      3: get(socket)        ┌───────┒  4: response   ┌────────┒
    │     └───────────────────────────►│ Shard ┠───────────────►│ Socket ┃
    │                                  ┕━━━┯━━━┛                ┕━━━━━━━━┛
    │                                      │
    └──────────────────────────────────────┘
                 5: resume(socket)
```

Moving the socket between the connection and shard processes is necessary due to
Inko processes not sharing memory. This means a connection process can't do
anything while the shard is performing it's work but that's OK, because there's
nothing meaningful it can do during this time anyway.

If the shard encounters an error while performing its work, instead of sending
the `resume` message to a connection process it sends it the `error` message,
with the socket and the error as its arguments. The connection process then
determines what should be done in response to the error.

For the `KEYS` command the approach is a little different. The connection
process creates a copy of the list of shards, and a list of keys that's
initially empty. It then removes a shard from the list and sends it the `keys`
message, with the following arguments:

1. A reference to the connection to send the results back to
1. The list of shards that have yet to process the message
1. The list of keys collected thus far

Upon receiving the message the shard adds its keys to the list, pops a shard
from the list of shards and sends it the `keys` message with the same arguments.
When the last shard in the list finishes its work, it sends the results back to
the connection process, which in turn writes the results to the socket.

```graph
┌────────────┒  1: keys(con, socket, shards: [shard 2], keys: [])   ┌─────────┒
│ Connection ┠─────────────────────────────────────────────────────►│ Shard 1 ┃
┕━━━━━━━━━━━━┛                                                      ┕━━━━┯━━━━┛
      ▲                                                                  │
      │         2: keys(con, socket, shards: [], keys: [key 1, key 2])   │
      │                                                                  │
      │                                                                  ▼
      │                                                             ┌─────────┒
      └─────────────────────────────────────────────────────────────┤ Shard 2 ┃
                3: write_keys(socket, keys: [key 1, key 2, key 3])  ┕━━━━━━━━━┛
```

This may sound complicated, but the implementation is straightforward:

```inko
type async Shard {
  ...

  fn async keys(
    connection: Connection,
    socket: uni Socket,
    shards: uni Array[Shard],
    keys: uni Array[Key],
  ) {
    for key in @keys.keys { keys.push(recover key.clone) }

    match shards.pop {
      case Some(s) -> s.keys(connection, socket, shards, keys)
      case _ -> connection.write_keys(stream, keys)
    }
  }
}
```

::: info
The expression `recover key.clone` clones the key (here of type `Key`) and then
turns that into a unique value (a `uni Key`). This allows it to be sent between
processes.
:::

The result of this setup (more commonly known as a ["shared-nothing
architecture"](https://en.wikipedia.org/wiki/Shared-nothing_architecture)) is
that connection processes concern themselves with determining what to do or how
to respond to the result of an operation, while shards perform the actual work
such as retrieving and assigning keys.

## Performance

So how does KVI perform? It should totally outperform Redis right?

Well, no. To get a better understanding of the performance, I used
[Valkey](https://github.com/valkey-io/valkey) (a FOSS fork of Redis) and its
benchmarking tool (`valkey-benchmark`) to get a rough understanding of the
performance of Valkey versus that of KVI. For example, I used the following
command:

```bash
valkey-benchmark -t get -n 500000 -r 1000 -q -c 8 -d 1024
```

Using Valkey the result is around 112 000 requests per second, while using KVI
results in 60 000 requests per second. This means that Valkey is about two times
faster.

On the surface that doesn't seem great: a language that's all about concurrency
that performs worse? Get the pitchforks!

If you take a step back and think about it, it's not so surprising. For one,
Redis (and thus by extension Valkey) has been around since 2009, while KVI has
only been around for a little less than a month. Second, Redis has seen a lot of
optimizations over the years, while KVI has seen exactly zero. Third, the code
generated by Inko's compiler could probably be optimized a lot better.

Oh, and Redis uses jemalloc while KVI (or more precisely, any Inko program) uses
the system allocator by default. Using KVI with jemalloc results in it
performing at a rate of around 74 000 requests/second, which _is_ better but not
as good as Redis. Still, it's a nice improvement considering it requires no code
changes.

The point here is that we're essentially comparing two different things: Redis
is a highly optimized production database, while KVI is a showcase application
that focuses on being easy to understand and has no intention of ever becoming a
production database. Still, half the performance in a fraction of the code
(ignoring the many features KVI doesn't implement of course) and effort isn't
all that bad.

## Missing features and the Redis protocol

KVI only implements a tiny subset of the Redis protocol. There are two reasons
for this:

1. I just didn't feel like implementing more, because for the purpose that KVI
   serves that just isn't necessary
1. The Redis protocol is clunky, and I got fed up with it after a while, and
   thus only implemented the basics of a few commands

That second point deserves some extra attention.

The Redis serialization protocol (RESP) is a weird hybrid between a text and
binary protocol, but without the benefits of a binary-only protocol. In
addition, it's an unstructured protocol: commands are just a series of strings
with no clear relation between them. The result is that parsing and generating
RESP messages is far more costly than necessary.

To better understand this, let's look at a basic command: `SET`. In it's most
basic form, `SET` takes two arguments: the key to set, and the value to assign
to the key. In RESP, commands are part of a pipeline and a pipeline can contain
multiple commands and their arguments. In a sensible protocol, a pipeline would
specify the number of commands and each command would specify the number of
arguments. This makes it clear at any given point how much data remains to be
parsed.

Naturally, RESP doesn't do that, because that would make too much sense.
Instead, it encodes pipelines as an [array of bulk
strings](https://redis.io/docs/latest/develop/reference/protocol-spec/#sending-commands-to-a-redis-server).
For example, the command `SET name Yorick` is encoded as follows:

```
*3\r\n$3\r\nSET\r\n$4\r\nname\r\n$6\r\nYorick\r\n
```

The start of an array is signalled using the character `*` followed by one or
more _digits_ that represent the number of values in the array. `\r\n` is used
as a separator between values. Bulk strings start with a `$`, followed by the
digits, `\r\n`, and the raw bytes:

```
*3\r\n    $3\r\nSET\r\n    $4\r\nname\r\n    $6\r\nYorick\r\n
───┬──    ──────┬──────    ──────┬───────    ────────┬───────
   │            │                │                   │
   ▼            ▼                ▼                   ▼
 Array     Bulk string      Bulk string         Bulk string
3 values     3 bytes          4 bytes             6 bytes
```

The first issue here is that the characters used to signal values aren't
monotonic (i.e. 0, 1, 2, etc) but instead (more or less) random. This means that
when parsing these values you (most likely) can't use a jump table and instead
have to resort to a linear or binary scan.

Second, the use of the `\r\n` separator sequence adds unnecessary bloat to each
message. While this won't matter much bandwith wise (given you'll most likely
access the database using an internal network), you still have to read the
sequences and verify they are present when required, wasting CPU time.

Third, the sizes of values are ASCII digits instead of e.g. little endian byte
arrays. This means that to parse the size you can't just read N bytes head and
interpret that as an integer, instead you need to read input 1-2 bytes at a time
until you reach the last digit, then use the usual "parse a string to an
integer" routine provided by your language (or implement one yourself) to turn
that data into an integer. When generating sizes that means you have to first
convert the integer to a string, then write it to the output stream.

The last issue is that there's no clear connection between the different
strings. That is, when processing the `SET` string there's no value of any kind
that signals "Hey, I require two additional values". Instead, you have to derive
this from the size of the array as a whole and how many values you have yet to
process. For commands that take optional arguments such as `SET`, this means you
also have to be able to peek ahead at least one bulk string to determine if that
is an optional argument (e.g. `NX` for the `SET` command) or some unrelated
separate command. Some commands may also support different optional arguments
but only allow one to be specified at a time. For example, `SET` takes the
optional `NX` and `XX` arguments but you can't specify _both_.

The result of all this is that a lot of time is unnecessarily spent in just
encoding and decoding RESP messages. Perhaps in 2009 this made sense, but in
2025 there are so many better alternatives.

To help understand this better, imagine that we introduce RESP version 4 and
make it a binary-only protocol, and we ignore existing protocols such as
[MessagePack](https://msgpack.org/index.html), [Protocol
Buffers](https://protobuf.dev/) and so on. In this protocol, the top-level value
is a command. Each command starts with a single byte, or maybe two bytes if you
want to support more than 255 commands. For the `SET` command we could do the
following:

1. The byte `1` signals the command is the `SET` command
1. The next 8 bytes represent the size (in bytes) of the key name, encoded using
   little endian (because there's no reason to use big endian these days)
1. The next 8 bytes represent the size (in bytes) of the key's value, using the
   same encoding as the key name
1. For commands that support optional arguments, the byte `0` would signal "no
   optional arguments are present", while bytes `1`, `2`, etc would signal what
   the next argument is. Values would be encoded in a way similar to key names
   and values: 8 bytes for the size, then N bytes for the value

Thus for the command `SET name Yorick` we'd end up with the following sequence
of bytes (from top to bottom):

```
1                     = SET

4 0 0 0 0 0 0 0       = 4 bytes for the key name
110 97 109 101        = "name"

6 0 0 0 0 0 0 0       = 6 bytes for the value
89 111 114 105 99 107 = "Yorick"
```

That's 27 bytes versus 35 bytes when using RESP3. The difference in size isn't
the selling point though, instead it's about how trivial it's to parse this new
format:

1. Read one byte to determine the command you're dealing with
1. Read 8 bytes in a single call and interpret this as an integer. On a little
   endian platform (which is basically everything these days) interpreting a
   sequence of bytes as an integer comes at almost no cost
1. Read N bytes to get the key name
1. Read the size of the value the same way as done in step two
1. Read N bytes to get the key's value

You could in theory optimize this further by encoding the size of the entire
command after the command byte, then read the data into an in-memory buffer
using a single IO operation. In contrast, when using RESP3 there are many places
where at most you can read two bytes ahead, resulting in many more IO
operations.

The size of each command could also be reduced by applying compression to the
byte sequences used to specify the size of some value. For example, we could
start each size sequence with a single extra byte that specifies the number of
bytes used by the size sequence (`0` for 0 bytes, `1` for 1 byte/8 bits, etc).
This makes interpreting the sequence of bytes as an integer a little more tricky
(though not that much), but can save quite a bit of space. Using such an
approach we can encode `SET name Yorick` as follows (from top to bottom):


```
1                     = SET

1                     = the size only needs 1 byte
4                     = 4 bytes for the key name
110 97 109 101        = "name"

1                     = the size only needs 1 byte
6                     = 6 bytes for the value
89 111 114 105 99 107 = "Yorick"
```

The resulting command only needs 15 bytes, 60% compared to using RESP3.

Generating data using this format is also trivial and doesn't rely on
potentially complex routines such as those used for converting numbers to
strings. For example, you can generate the above sequence of bytes using Inko
like so:

```inko
type async Main {
  fn async main {
    let buf = ByteArray.new

    buf.push(1)          # SET
    buf.push(1)          # The amount of bytes to use for the key size
    buf.push(4)          # The size of the key
    buf.append('name')   # The key
    buf.push(1)          # The amount of bytes to use for the value size
    buf.push(6)          # The size of the value
    buf.append('Yorick') # The value
  }
}
```

Of course it will get a bit more complicated once we stop using static data as
done above, but even then the resulting setup will be straightforward and offer
excellent performance.

To summarize it all, RESP3 is unnecessarily bloated and computationally complex
to generate and parse. If I were to build a key-value database today with the
intention of it being suitable for production environments, I would not bother
with RESP3 and instead use a more sensible binary protocol.

## Changes made to Inko

Part of this exercise was to determine what changes needed to be made to Inko,
if any. Indeed, some improvements had to be made to make implementing certain
parts of KVI easier or even possible in the first place.

### A new slicing and Write API

The `String` and `ByteArray` types supported a slicing API as found in many
languages: a `slice` function that takes a range, then returns a copy of the
data covered by this range. So given the `String` `hello`, slicing the
(exclusive) range 0 until 3 would produce a new `String` with value `hel`.

In an early iteration I was playing around with a custom allocator for the
values stored in the database. Instead of allocating values individually, values
would be bump allocated into larger (e.g. 2 MiB) blocks. This meant that when
writing the values to a socket in response to a `GET` command, I'd need the
ability to take a slice into these blocks and write the slice to the socket,
without copying the value first.

This introduced two problems:

1. Creating a slice would result in a copy of the underlying data. So a 1 MiB
   value would require 2 MiB: one 1 MiB for the storage, and 1 MiB for the
   temporary copy written to the socket
1. Writing to output streams (files, sockets, etc) involved the methods
   `write_string` and `write_bytes`, provided by implementing the `std.io.Write`
   trait. `Write.write_string` required a `String` while `Write.write_bytes`
   required a `ref ByteArray`. This meant that even if the slicing API were
   changed to not create copies, we'd still have to create a new `ByteArray` or
   `String` just so we can write it to an output stream.

To resolve these problems, I first changed the slicing API to [not require
copying](https://github.com/inko-lang/inko/commit/7f201d9ebc9c766a0c93b218ab7c605025863054).
Instead, slicing produces a (stack allocated) `Slice` value that stores a
reference to the source (e.g. a `ByteArray`) and the slice range.

With the new slicing API in place, I changed the `Write` trait such that it only
[requires a `write` method to be
implemented](https://github.com/inko-lang/inko/commit/d566a34b9f67cd3c216ea3004f7850ae5e43cac6)
instead of requiring both `write_string` and `write_bytes`. This `write` method
in turn is implemented such that it accepts any type of input, as long as the
type implements the `std.bytes.Bytes` trait. This trait in turn is implemented
by `String`, `ByteArray`, and the new `Slice` type.

```inko
trait pub Write {
  fn pub mut write[B: Bytes](bytes: ref B) -> Result[Nil, Error]

  ...
}
```

The combination of these two changes means that you can now create a slice of a
`String`, `ByteArray` or another `Slice` and write it directly to (for example)
a socket, without the need for intermediate copies:

```inko
import std.stdio (Stdout)

type async Main {
  fn async main {
    let stdout = Stdout.new
    let input = 'Hello, this is an example String'

    let slice1 = input.slice(start: 0, end: 12) # Neither of these calls creates
    let slice2 = slice1.slice(start: 0, end: 5) # a copy of the String.

    stdout.write(slice2) # => "Hello"
  }
}
```

Neat!

### Making it easier to work with unique values

In Inko a `uni T` value is some type `T` that is unique. A value being unique
means that there's only one reference to it that you can use from the outside.
Due to move semantics, moving such a value to a different process means giving
up ownership which combined with the uniqueness constraint means the data can't
be accessed concurrently. Thus, no data race conditions are possible. Nice!

A value being unique does impose various restrictions on how you can use it. For
example, while you _can_ call methods on such values the compiler only allows
this if it's certain no aliases can be introduced or the arguments are
"sendable". A "sendable" argument is either a unique value or a value type.
Basically something we can move around without introducing aliases in a way that
would violate the uniqueness constraint of a unique value.

The compiler applies a set of checks to determine if it can relax these
restrictions in certain cases, such as when the method doesn't allow mutating
its receiver and all its arguments are immutable.

As part of the work on KVI, I implemented the following additional improvements:

1. If the method _does_ allow mutations but the receiver never stores a borrow,
   and all arguments are immutable borrows or unique values, we now [allow such
   method calls](https://github.com/inko-lang/inko/commit/3949a367f82e42f197456d762d285da240c0daf6)
   instead of rejecting them
1. If the method _does_ allow mutations, the receiver never stores any borrows,
   then mutable borrows _are_ allowed as arguments [_if_ the borrowed data only
   stores value types.](https://github.com/inko-lang/inko/commit/f0fa8604d3c5dcb391e1741a5d1911e1cb3d3d49)

The first improvement means that if you have a unique socket or file, you can
call `write` on it to write data to it, because these types never store any
borrows. Previously this wasn't possible because `write` is a mutating method
and it requires an immutable borrow as its argument, and borrows aren't sendable
(by default at least):

```inko
import std.stdio (Stdout)

type async Main {
  fn async main {
    let out = recover Stdout.new      # => uni Stdout
    let msg = 'Hello!'.to_byte_array  # => ByteArray

    out.write(msg) # => "Hello!"
  }
}
```

The second improvement means that if you have a unique socket or file (or a
similar value), you can call `read` on it to read data from it:

```inko
import std.stdio (Stdin, Stdout)

type async Main {
  fn async main {
    let inp = recover Stdin.new
    let out = Stdout.new
    let buf = ByteArray.new

    let _ = inp.read(into: buf, size: 8).or_panic
    let _ = out.write(buf).or_panic
  }
}
```

Similar to the `write` example, this previously wasn't possible because `read`
too is a mutating method, and its argument is a mutable borrow.

These checks don't just apply to IO related types, but any type that doesn't
store any borrows (either directly or indirectly).

### Waiting for multiple signals

Inko 0.15.0 [introduced support for handling
signals](https://inko-lang.org/news/inko-0-15-0-released/#support-for-handling-unix-signals),
but it only provided a way of handling individual signals. If you wanted to
handle multiple signals you had to spawn a bunch of processes yourself.

For KVI I needed to handle multiple signals such as `SIGTERM` and `SIGQUIT`. To
make this easier [I added the
`std.signal.Signals`](https://github.com/inko-lang/inko/commit/ed4d3240ac5107cedf324a2b1d168d6cdf055300)
type. This means you can now wait for multiple signals like so:

```inko
import std.signal (Signal, Signals)
import std.stdio (Stdout)

let signals = Signals.new
let stdout = Stdout.new

signals.add(Signal.Quit)
signals.add(Signal.Terminate)

loop {
  match signals.wait {
    case Quit -> stdout.print('received SIGQUIT')
    case Terminate -> stdout.print('received SIGTERM')
    case _ -> {}
  }
}
```

### A better API for indexing collections

The various collection types provided by the standard library (`Array`, `Map`,
etc) typically provided two sets of methods for indexing:

- `get(index)` and `get_mut(index)` for getting an immutable or mutable borrow
  respectively, panicking if the index is out of bounds
- `opt(index)` and `opt_mut(index)` for getting an `Option[ref T]` or
  `Option[mut T]` respectively, returning an `Option.None` if the index is out
  of bounds

For example, to get the value at index 42 for an `Array` you'd write the
following:

```inko
values.get(42) # => returns the value, or panics
```

The problem with this approach is not so much that some methods panic and others
don't, that was in fact deliberate (see also [The Error
Model](https://joeduffyblog.com/2016/02/07/the-error-model/)). Rather, it's that
in the worst case one has to implement four methods for each type, resulting in
a lot of duplication. The names also don't communicate that they may panic (or
not).

To solve this, the upcoming 0.19.0 release provides [a new indexing
API](https://github.com/inko-lang/inko/commit/09653162c184b53b44d08e824acbef510479bec4).
Instead of these different methods, types provide a `get` and (if relevant) a
`get_mut` method. These methods return a
[`std.result.Result`](https://docs.inko-lang.org/std/main/module/std/result/Result/).
If the index is valid, a `Result.Ok` is returned that wraps the desired value.
If the index is out of bounds, a dedicated error type is returned (e.g.
[`std.array.OutOfBounds`](https://docs.inko-lang.org/std/main/module/std/array/OutOfBounds/)).

If the index must be present and you wish to panic if it isn't, you now use
[`Result.or_panic`](https://docs.inko-lang.org/std/main/module/std/result/Result/#method.or_panic).
This method checks if the `Result` is an `Ok` or `Error`. If the value is an
`Ok` it's unwrapped and returned, otherwise the error value is converted to a
`String`, which is then used as the panic message:

```inko
type async Main {
  fn async main {
    [10, 20, 30].get(10).or_panic # => Process 'Main' (0x3eec470) panicked: the index 10 is out of bounds (size: 3)
  }
}
```

This new API gives you the choice to choose between panicking or not panicking,
without having to remember different method names. The presence of `or_panic`
also makes it obvious the code might panic. If you don't want to panic, you can
instead use pattern matching:

```inko
type async Main {
  fn async main {
    match [10, 20, 30].get(10) {
      case Ok(val) -> {
        # Do something with the value here
      }
      case Error(err) -> {
        # Handle the index being invalid
      }
    }
  }
}
```

### The introduction of for loops

To iterate over data, Inko 0.18.1 and older versions required you to create an
iterator (using e.g. [`Array.iter`](https://docs.inko-lang.org/std/main/module/std/array/Array/#method.iter)),
then call `each` on the resulting iterator and give it a closure to call for
each value:

```inko
import std.stdio (Stdout)

type async Main {
  fn async main {
    let numbers = [10, 20, 30]
    let stdout = Stdout.new

    numbers.iter.each(fn (v) { stdout.print(v.to_string) })
  }
}
```

The use of closures poses a challenge when working with unique values, as such
values can only be captured by _moving_ them into the closure, turning the
values into regular owned values in the process. In practice this meant that
using a unique value during iteration was difficult, especially if you wanted to
keep the value unique _after_ the iteration finished.

Inko now has support for a `for` loop:

```inko
import std.stdio (Stdout)

type async Main {
  fn async main {
    let numbers = [10, 20, 30]
    let stdout = Stdout.new

    for v in numbers.iter { stdout.print(v.to_string) }
  }
}
```

While I didn't add `for` loops _just_ to make working with unique values easier,
it certainly helps. `for` loops are just syntax sugar for a `loop` combined with
a `match`. For example, the above loop is lowered into (more or less) the
following:

```inko
import std.stdio (Stdout)

type async Main {
  fn async main {
    let numbers = [10, 20, 30]
    let stdout = Stdout.new

    {
      let iter = numbers.iter.into_iter

      loop {
        match iter.next {
          case Some(v) -> stdout.print(v.to_string)
          case _ -> break
        }
      }
    }
  }
}
```

This means you can also use pattern matching in the `for` loop:

```inko
import std.stdio (Stdout)

type async Main {
  fn async main {
    let numbers = [('Alice', 10), ('Bob', 20)]
    let stdout = Stdout.new

    for (name, num) in numbers {
      stdout.print(name)           # => "Alice", "Bob"
      stdout.print(num.to_string)  # => 10, 20
    }
  }
}
```

Using the old closure based approach this wasn't possible, as Inko doesn't
support pattern matching in method/closure arguments.

## Conclusion

Writing a key-value database proved to be a fun and valuable exercise: it lead
to various language improvements, I learned several new things (including that
RESP is rather clunky, unfortunately), and I hope it will serve as a useful
reference application to those looking to learn more about Inko. In the future
I also want to use it for benchmarking Inko's performance over time, though at
this stage I'm not sure yet what such a setup would look like.

If you'd like to follow the development of Inko, consider joining the [Discord
server](https://discord.gg/seeURxHxCb) or star the [project on
GitHub](https://github.com/inko-lang/inko). You can also subscribe to the
[/r/inko subreddit](https://www.reddit.com/r/inko/).

If you'd like to support the development of Inko and can spare $5/month,
_please_ become a [GitHub sponsor](https://github.com/sponsors/YorickPeterse) as
this allows me to continue working on Inko full-time.
