---
{
  "title": "Asynchronous IO: the next billion-dollar mistake?",
  "date": "2024-09-06T16:00:00Z"
}
---

Asynchronous IO (also known as "non-blocking IO") is a technique applications
use to allow performing of many IO operations without blocking the calling OS
thread, and without needing to spawn many threads (i.e. one thread per
operation). In the late 1990s/early 2000s, an increasing amount of people using
the internet meant an increasing amount of traffic web services needed to
handle, better known as the [C10K
problem](https://en.wikipedia.org/wiki/C10k_problem).

Using asynchronous IO to approach this problem appears compelling: it allows you
to handle many connections at once, without needing to increase the number of OS
threads. This is especially compelling if you consider that support for good
multi-threading was still a hit a miss at the time. For example, Linux didn't
have good support for threads until the 2.6 release in December 2003.

Since then the use of and support for asynchronous IO has grown. Languages such
as Go and Erlang bake support for asynchronous IO directly into the language,
while others such as Rust rely on third-party libraries such as
[Tokio](https://tokio.rs/).

[Inko](https://inko-lang.org/), a language that I'm working on, also includes
built-in support for asynchronous IO. Similar to Go and Erlang, this is hidden
from the user. For example, when reading from a socket there's no need to
explicitly poll or "await" anything, as the language takes care of it for you:

```inko
import std.net.ip (IpAddress)
import std.net.socket (TcpClient)

class async Main {
  fn async main {
    let client = TcpClient.new(ip: IpAddress.v4(1, 1, 1, 1), port: 80).or_panic(
      'failed to connect',
    )

    client
      .write_string('GET / HTTP/1.0\r\nHost: one.one.one.one\r\n\r\n')
      .or_panic('failed to write the request')

    ...
  }
}
```

If the write would block, Inko's scheduler sets aside the calling process and
reschedules it when the write can be performed without blocking. Other languages
use a different mechanism, such as callbacks or
[async/await](https://en.wikipedia.org/wiki/Async/await). Each approach comes
with its own set of benefits, drawbacks and challenges.

Not every IO operation can be performed asynchronously though. File IO is
perhaps the best example of this (at least on Linux). To handle such cases,
languages must provide some sort of alternative strategy such as performing the
work in a dedicated pool of OS threads.

::: info
Using [io\_uring](https://en.wikipedia.org/wiki/Io_uring) is another approach,
but it's a recent addition to Linux, specific _to_ Linux (meaning you need a
fallback for other platforms), and [disabled entirely by
some](https://www.phoronix.com/news/Google-Restricting-IO_uring). Either way,
the point still stands: you end up having to handle sockets and files (and
potentially other types of "files") differently.
:::

For example, Inko handles this by the standard library signalling to the
scheduler it's about to perform a potentially blocking operation. The scheduler
periodically checks threads in a "we might be blocking" state. If the thread is
in such a state for too long, it's flagged as "blocking" and a backup thread is
woken up to take over its work. When the blocked thread finishes its work, it
reschedules the process it was running and becomes a backup thread itself. While
this works, it limits the amount of blocking IO operations you can perform
concurrently to the number of backup threads you have. Automatically adding and
removing threads can improve things, but increases the complexity of the system.

In 2009, [Tony Hoare](https://en.wikipedia.org/wiki/Tony_Hoare) stated that his
invention of NULL pointers was something he considers a "billion-dollar mistake"
due to the problems and headaches it brought with it. The more I work on systems
that use asynchronous IO, the more I wonder: is asynchronous IO the next
billion-dollar mistake?

More specifically, what if instead of spending 20 years developing various
approaches to dealing with asynchronous IO (e.g. async/await), we had instead
spent that time making OS threads more efficient, such that one wouldn't need
asynchronous IO in the first place?

To illustrate, consider the Linux kernel today: spawning an OS thread takes
somewhere between 10 and 20 microseconds ([based on my own
measurements](https://github.com/inko-lang/inko/issues/690)), while a context
switch takes somewhere in the range of [1-2
microseconds](https://eli.thegreenplace.net/2018/measuring-context-switching-and-memory-overheads-for-linux-threads/).
This becomes a problem when you want to spawn many threads such that each
blocking operation is performed on its own thread. Not only do you need many OS
threads, but the time to start them can also vary greatly, and the more OS
threads you have the more context switches occur. The end result is that while
you certainly can spawn many OS threads, performance will begin to deteriorate
as the number of threads increases.

Now imagine a parallel universe where instead of focusing on making asynchronous
IO work, we focused on improving the performance of OS threads such that one can
easily use hundreds of thousands of OS threads without negatively impacting
performance (= the cost to start threads is lower, context switches are cheaper,
etc). In this universe, asynchronous IO and async/await wouldn't need to exist
(or at least wouldn't be as widely used). You need to handle 100 000 requests
that perform a mixture of IO and CPU bound work? Just use 100 000 threads and
let the OS handle it.

Not only would this offer an easier mental model for developers, it also leads
to a simpler stack. Libraries such as epoll and kqueue wouldn't need to exist,
as one would just start a new OS thread for their blocking/polling needs.
Need to call a C function that may block the calling thread? Just run it on a
separate thread, instead of having to rely on some sort of mechanism provided by
the IO runtime/language to deal with blocking C function calls.

Unfortunately, we do not live in such a universe. Instead in our universe the
cost of OS threads is quite high, and inconsistent across platforms. Which
brings me back to Tony Hoare: over the decades, we invested a massive amount of
resources in dealing with asynchronous IO, perhaps billions of dollars worth of
resources. Was that a mistake and should we have instead invested that into
improving the performance of OS threads? I think so, but until an operating
system comes along that dramatically improves the performance of threads ,
becomes as popular as Linux, _and_ is capable of running everything you can run
on Linux or provide better alternatives (such that people will actually want to
switch), we're stuck with asynchronous IO.
