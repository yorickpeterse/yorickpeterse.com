---
title: Friendship ended with the garbage collector
date: 2021-08-24 18:00:00 UTC
---

It's been a while since the last update about my work on the [Inko programming
language](https://inko-lang.org/). Not because there hasn't been any progress,
but because I've been busy making changes. A _lot_ of changes.

For the past two years or so I have been toying with the idea of replacing
Inko's garbage collector with something else. The rationale for this is that at
some point, all garbage collected languages run into the same issue: the
workload is too great for the garbage collector to keep up.

The solutions to such problems vary. Sometimes one has to spend hours tweaking
garbage collection settings. Such settings often lack good documentation, and
are highly dependent on the infrastructure used to run the software. Other times
one has to use hacks such as [allocating a 10 GB byte
array](https://blog.twitch.tv/en/2019/04/10/go-memory-ballast-how-i-learnt-to-stop-worrying-and-love-the-heap-26c2462549a2/).

This got me thinking: what if for Inko I got rid of the garbage collector
entirely, preventing users from running into these problems? After spending some
time looking into this (see [this
issue](https://gitlab.com/inko-lang/inko/-/issues/207) for more details), I
decided to postpone the idea. I wasn't able to come up with a good solution at
the time, so I decided to take another look at it in the future.

Earlier this year I read the paper
["Ownership You Can Count On: A Hybrid Approach to Safe Explicit Memory Management"](https://researcher.watson.ibm.com/researcher/files/us-bacon/Dingle07Ownership.pdf).
This paper is from 2006, and describes a single ownership model for managing
memory. The approach outlined is pretty straightforward: you have owned values,
and references. When an owned value goes out of scope, it's deallocated. When
creating a reference, you increment a counter stored in the owned value the
reference points to. When the reference goes out of scope, the count is reduced.
When an owned value goes out of scope and its reference count is not zero, the
program terminates with an error (which I'll refer to as a "panic").

Of course this approach has its own downside: a program may panic at when
dropping an owned value, if it still has one or more references pointing to it.
This is something you can prevent from happening (at least as much as possible)
using compiler analysis. Since you still have a runtime mechanism to fall back
to, this analysis doesn't have to be perfect. The result is that you can decide
how you want to balance developer productivity, correctness, and the complexity
of the implementation.

In contrast, Rust has a strict and complex ownership model. This model ensures
that if your program compiles (and you don't use unsafe code), you won't run
into memory related issues such as dangling references or use-after-free errors.
The trade-off here is extra complexity, not being able to implement certain
patterns in safe code (e.g. linked lists), and possibly more.

The approach outlined here was compelling enough for me to take another look at
using a single ownership model for Inko. Along the way, I found out about a
language called [Vale](https://vale.dev/), which draws inspiration from the same
paper.

## The current status

Replacing the garbage collector with a single ownership model (amongst other
changes I'm making) is what I have been working on since March 2021. The
progress is tracked in the merge request ["Single ownership, move semantics, and
a new memory layout"](https://gitlab.com/inko-lang/inko/-/merge_requests/120).
Besides introducing a single ownership model, the merge request introduces
changes such as (but not limited to):

- Throwing errors is much cheaper, with the cost being similar to a regular
  function return.
- Defining processes is done similar to defining classes, and sending messages
  looks like regular method calls.
- A new compiler written in Rust, replacing the Ruby compiler. When our
  self-hosting compiler is mature enough, the Rust compiler will be used to
  bootstrap the self-hosting compiler.
- A greatly improved allocator. We still use the Immix heap layout, and heaps
  are now thread-local instead of process-local.
- Method calls and field lookups no longer use hashing, and instead use regular
  index lookups.
- Dynamic dispatch is handled using a hashing approach inspired by [Shenanigans
  With Hash Tables](https://thume.ca/2019/07/29/shenanigans-with-hash-tables/).
  Using this approach we allow reopening of classes and implementing of traits
  after defining a class, without the need for fat pointers. The compiler will
  generate code such that collisions are rare, and that the cost of handling
  collisions is as small as possible.

### Processes and messages

A big change that is the direct result of the single ownership model is how
processes send messages to each other. The released version of Inko takes an
approach similar to Erlang: each process has its own heap, and messages are deep
copied when sent. This removes the need for sharing memory, which in turn
removes the need for synchronisation. The cost is having to deep copy objects.
This can be time consuming, and handling circular objects is a challenge.
Copying of some objects can also fail at runtime (e.g. sockets), but there
wasn't a nice way of handling this.

When you use a single ownership model, you don't need copying. Instead, you just
transfer ownership to the receiving process. This also means you don't have to
maintain a heap per process. Instead, you can maintain a heap per OS thread (to
allow for fast thread-local allocations), as the ownership model guarantees no
two processes can access the same object concurrently. The result is a nicer
language, type-safe message passing, a reduction in memory usage due to
processes being smaller, and lots of other improvements.

To illustrate this, here is a simple example of implementing a distributed
counter:

```inko
async class Counter {
  @number: UnsignedInt

  async def increment {
    @number += 1
  }

  async def get -> UnsignedInt {
    @number
  }
}

def main {
  let counter = Counter { @number = 0 }

  counter.increment
  counter.increment
  counter.get # => 2
}
```

Defining processes is done using `async class`. When you create an instance of
an async class, a process is spawned that owns the instance. The process that
created the instance is given a value of type `async T`, or `async Counter` in
the above example. This type acts as the client, with the process acting as a
server. Clients can be copied and sent to other processes.

Messages are essentially remote procedure calls, and look like regular method
calls. When you create a process with one or more fields, or pass arguments
along with your message, the ownership of the values is transferred to the
receiving process. A few types can't be sent to different processes, such as
references, closures, and generators.

Message processing happens in FIFO order. When all clients disconnect, and the
process has no more messages to process, the process runs its destructor and
terminates.

When you send a message, the sender waits for a result to be produced, without
blocking the OS thread the process is running on. If you instead want a future
to resolve later, you can use the `async` keyword (`async counter.get`
instead of `counter.get`).

### Circular types

In languages with single ownership, circular types such as doubly linked lists
can be tricky to implement, typically requiring unsafe code such as raw
pointers. In Inko, such types are easy to implement:

```inko
class DoublyLinkedList[T] {
  @head: ?Node[T]
}

class Node[T] {
  @value: T
  @next: ?Node[T]
  @prev: ?ref Node[T]
}
```

Here `?T` is syntax sugar for `Option[T]`, meaning it's an optional value. `ref
T` is a reference to an owned value of type `T`.

We don't need destructors, as Inko drops fields in reverse lexical order. For
our linked list example with nodes A and B (with B coming after A), the drop
order is as follows:

```
1. A @prev
2. A @next --> 3. B @prev
               4. B @next
               5. B @value
6. B
7. A @value
8. A
```

When we reach step 8, the reference from B to A is dropped, so no error is
produced.

For more complex types a custom destructor may be needed to drop fields in a
different order, though such cases should be rare. Even then, you won't need any
unsafe code.

### Generics support both owned values and references

A challenge identified in the ownership paper is allowing generic types to
support both owned values and references. The paper doesn't provide a solution,
and instead mentions implementing different types (so one Array type for owned
values, and one for references).

Inko will start by using pointer tagging to differentiate between owned values
and references. We already use pointer tagging for immediate values, and had an
extra bit to spare anyway. Any generic code that isn't inlined will use a
runtime check of this bit when dropping a generically typed value.

I decided against the use of monomorphisation for several reasons:

- We don't have (and I can't think of any) optimisations that can take advantage
  of it.
- It increases compile times, and I want to keep these as low as possible.
- Through inlining most generic types can be removed.
- It increases memory usage.
- The Array type is built into the VM, and the VM uses it in several different
  places. If we monomorhpise generic types (including Array), the VM needs to be
  refactored such that it doesn't use the Array type directly. If we don't, the
  VM won't know which implementation of the Array type to use.

In the future Inko may use a different approach, but for the time being pointer
tagging should be good enough.

### Heap layout

A benefit of garbage collected languages is that they can allocate and reclaim
memory such that allocations are fast, and fragmentation is kept low. Inko
retains the
[Immix](https://www.cs.utexas.edu/users/speedway/DaCapo/papers/immix-pldi-2008.pdf)
heap layout and bump allocator. To reuse memory and combat fragmentation, Inko
threads scans a chunk of their heap before running a process. When a reusable
block of memory is found, it's moved to the end of the heap after the allocation
position. Scanning is done incrementally, ensuring that each scan takes a fixed
maximum amount of time. Objects are never moved around, as doing so requires
traversing all live objects (or read barriers) to update pointers to the moved
objects.

While this approach doesn't fully mitigate fragmentation, I believe it should be
good enough for the foreseeable future.

## Remaining work

While work on the new virtual machine is finished, I'm still working on the new
compiler. As part of this I'll also need to rewrite parts of the self-hosting
compiler code written thus far. I suspect it will take a few more months before
the work is finished. I'm _super_ excited about these changes, and I hope they
will make Inko a more compelling language to use. They will also make Inko a
much faster language.

If you'd like to stay up to date on the progress made, I recommend joining
Inko's [Matrix channel](https://matrix.to/#/#inko-lang:matrix.org), or
subscribing to [/r/inko](https://www.reddit.com/r/inko/) on Reddit.
