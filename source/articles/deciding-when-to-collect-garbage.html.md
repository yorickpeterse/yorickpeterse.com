---
title: Deciding when to collect garbage
date: 2019-12-02 17:15:00 UTC
---

How to perform garbage collection is a widely explored topic, and there are all
sorts of different techniques. Sequential collectors, parallel collectors,
concurrent collectors, incremental collectors, real-time collectors, the list
goes on. There are also different techniques for allocators used, ranging from
free list allocators to bump allocators.

Deciding _when_ to perform garbage collection appears to be written
about less frequently. I suspect the reason for this is that deciding when
to collect is specific to a programming language's behaviour. For example,
languages using immutable objects will allocate a lot and thus more frequent
collections may be desired.

Let's illustrate this using the best book one can buy to learn more about
garbage collection: [The Garbage Collection Handbook, 2nd
Edition](http://gchandbook.org/). This book consists of 416 pages, excluding the
preface, table of contents, glossary, etc. These 416 pages cover pretty much
everything there is to know about garbage collectors, how to implement them,
what their trade-offs are, and so on.

Of these 416 pages, I could not find any that focus specifically on when to
collect garbage. I do vaguely recall it's discussed somewhere in the book, but I
was unable to find this by looking at the table of contents and skimming through
several chapters.

In this article we'll take a look at the different techniques that can be used
to decide when to collect garbage, how to implement such a technique, and what
techniques a few programming languages out there use.

## Table of contents
{:.no_toc}

* TOC
{:toc}

## Deciding when to collect

Let's start by taking a look at the different ways a collector can determine if
garbage collection is necessary, in no particular order.

### Collecting based on object allocation counts

This approach is the most simple, and a commonly used approach. When a certain
number of objects is allocated since the last collection, we trigger a
collection. At the end of a collection we reset this counter. This is repeated
until the program terminates.

Most collectors using this approach will increase the threshold as the program
runs, if needed. For example, a collector may decide to double the threshold if
it could not release enough memory during a collection. This ensures that
garbage collections don't happen too frequently.

### Collecting based on object sizes

A refinement of collecting based on object _counts_ is to trigger a collection
after allocating a certain number of _bytes_. This is useful when you have
objects of different sizes. Imagine a system where we collect based on object
counts, and we allocate lots of large objects, but not enough to cross the
allocation count threshold. Because we collect based on counts and not sizes, we
may end up wasting more memory than necessary.

Obtaining the size of an object may not always be easy, or cheaper than just
counting the number of objects. It's also not helpful if all objects are the
same size, as counting the size would thus be the same as just counting the
amount of objects.

### Collecting based on object weights

Just allocating memory is not always all that needs to be done to initialise an
object. Fields need to be filled in, synchronisation may be needed based on what
kind of object is allocated, and so on. Instead of collecting based on the
number of allocated objects, a collector may decide to assign a weight to every
object, triggering a collection when the total weight exceeds a certain
threshold.

### Collecting based on the number of memory blocks

Counting individual object allocations may get expensive if allocations happen
frequently. Allocators in turn frequently divide memory in blocks, such as a
block of 8 KB. A collector can then decide to not count the number of allocated
objects, but the number of blocks in use. If a block can contain 100 objects,
this means we only need to increment and check our statistics once every 100
allocations; instead of doing so on every allocation. This may improve
performance, but can also delay garbage collection.

### Collecting based on the usage percentage of a fixed-size heap

Instead of collecting based on a counter crossing a threshold, we assign a fixed
size to our heap. When a certain percentage of this heap is used we trigger a
collection. When the heap is full, we trigger a collection and/or error if no
additional memory is available.

This approach allows us to enforce an upper limit on the size of the heap, which
can be useful in memory constrained environments. The downside is that consuming
the entire heap may lead to the program terminating (depending on what the
collector does in this case), even when the system has memory available.

This approach also may not work well if tasks (lightweight processes, threads,
and so on) have their own heap, as preallocating memory for these heaps may be
expensive and end up consuming a lot of (virtual) memory.

### Collecting between web requests

A less common approach sometimes employed by web applications is to disable
garbage collection by default, and manually run it after completing a web
request. The idea of this approach is to defer any garbage collection pauses
until after a request, preventing garbage collections from negatively affecting
the user experience.

In practise I think this won't work as well as one might think. While an
accepted request won't be interrupted by a collection, future requests may take
longer to be handled due to a collection running between requests. With that
said, this can be influenced by the application's behaviour, so perhaps there
are cases where this does help.

### Collecting after a certain time has passed

Instead of collecting based on some incremented number, a collector may decide
to collect after a certain amount of time has passed. To the best of my
knowledge this approach is not commonly used on its own. Instead, it's sometimes
used as a backup of sorts to ensure collections run periodically, even when
allocating only a small number objects.

Using this approach on its own is unlikely to work well, as there is no
correlation between the time elapsed and the need to collect garbage. That is,
just because five minutes have passed does not mean a collection is needed.

[Go](https://golang.org/) appears to use (or at least has used) this approach to
force a garbage collection if no collection has taken place for more than two
minutes. I have not been able to confirm if Go still does this as of Go 1.13.

### Collecting when the system runs out of memory

When the operating system runs out of memory, we may want to trigger a
collection in an attempt to release memory back to the operating system. This
approach, if used, can be useful when used on top of another technique to
trigger regular collections.

The effectiveness of this is debatable. When collecting garbage we may need to
allocate some memory for temporary data structures (e.g. a queue to track
objects to scan), but this may result in the operating system terminating the
program as no memory is available. Since there is also no guarantee that a
collector is able to release memory back to the operating system, this may
result in collections wasting time.

### Collecting based on past collection statistics

This is another technique that may be applied on top of a previously mentioned
technique: trigger a collection (earlier) based on statistics gathered from a
previous collection cycle. For example, a collector may decide to delay a
collection if the previous collection spent too much time tracing objects. By
delaying the collection, the collector may need to trace fewer objects the next
time it runs.

## Deciding when to collect using Rust

Let's implement a simple strategy to determine when to collect by counting the
allocated objects. For these examples I'll use Rust. First we'll start with some
boilerplate:

```rust
use std::alloc::{alloc, handle_alloc_error, Layout};

pub struct Heap {
    /// The number of objects allocated since the last collection.
    allocations: usize,

    /// The number of objects to allocate to trigger a collection.
    threshold: usize,

    /// The factor to grow the threshold by (2.0 means a growth of 2x).
    growth_factor: f64,

    /// The percentage of the threshold (0.0 is 0% and 1.0 is 100%) that should
    /// still be in use after a collection before increasing the threshold.
    resize_threshold: f64,

    /// The number of objects marked during a collection.
    marked: usize,
}

impl Heap {
    pub fn new() -> Self {
        Self {
            allocations: 0,
            threshold: 32,
            growth_factor: 2.0,
            resize_threshold: 0.9,
            marked: 0
        }
    }
}
```

The `Heap` type would be used for storing heap information (e.g. a pointer to a
block of memory to allocate into), and the number of allocations. For the sake
of this article we keep this implementation as simple as possible. We use an
arbitrary growth factor of 2.0. We use a float to allow for more precise growth
factors, such as 1.5 or 2.3. Other values such as the threshold and resize
threshold are also arbitrary.

Let's add a method to allocate objects:

```rust
impl Heap {
    pub fn allocate(&mut self, size: usize) -> *mut u8 {
        let layout = Layout::from_size_align(size, 8)
          .expect("The size and/or alignment is invalid");

        let pointer = unsafe { alloc(layout) };

        if pointer.is_null() {
            handle_alloc_error(layout);
        }

        self.allocations += 1;

        pointer
    }
}
```

Our `Heap::allocate()` method takes the number of bytes to allocate as an
argument, returning a raw pointer to the allocated memory. For the sake of
simplicity we align memory to 8 bytes. If an allocation fails (NULL is
returned), we let Rust handle this for us.

Now that we have the method to allocate memory, let's add two methods: one to
check if a collection is needed, and one to increase the threshold if needed:

```rust
impl Heap {
    pub fn should_collect(&self) -> bool {
        self.allocations > self.threshold
    }

    pub fn increase_allocation_threshold(&mut self) {
        let threshold = self.threshold as f64;

        if (self.marked as f64 / threshold) < self.resize_threshold {
            return;
        }

        self.threshold = (threshold * self.growth_factor).ceil() as usize;
    }
}
```

`Heap::should_collect()` is simple and should not need any explaining.
`Heap::increase_allocation_threshold()` checks if the number of marked objects
(this value would be updated by the collector while tracing objects) is too
great, increasing the threshold (using a growth factor) if needed.

That's all there is to it. Well, almost: a real collector probably needs to
store more data, update the statistics in the right place, and so on; but _just_
the code for deciding when to collect is straightforward.

## Languages and what techniques they use

Now let's take a look at some programming languages out there, and what approach
they use to determine when a collection is needed.

### Inko

[Inko](https://inko-lang.org) uses lightweight processes, each process has its
own heap, and the collector collects each process independently. The process
heaps consists of one or more 8 KB blocks. After a collection, the collector
returns any free blocks to a global collector for later use. Any still full
blocks the collector puts aside so they won't be used for allocations. Any
blocks with space available can be reused once the process resumes.

Every time a block is requested from the global allocator, a block allocation
counter is incremented. This is done for both the young and mature generation.
When this counter exceeds a certain threshold, a collection is triggered. If
after a collection the collector determines not enough blocks could be returned
to the global allocator, it will increase the threshold for the next allocation.
The various settings used for this (the initial thresholds, growth factors,
etc.) can all be configured using environment variables.

The current block thresholds are 8 MB for the young generation, and 16 MB for
the mature generation. These thresholds are arbitrary, and they will probably
change in the future. The mature generation threshold in particular seems rather
high, as 16 MB of blocks translates to around half a million objects; far too
much for a single lightweight process.

### Java

The JVM enforces a maximum heap size that is configured when starting the JVM.
Due to all the different collectors the JVM supports it's hard to determine what
triggers a garbage collection. I suspect it's based on a variety of
statistics, such as how much of the (fixed-size) heap is in use, previous
collection timings, and so on.

### Lua

Per [this document](http://www.lua.org/manual/5.4/manual.html#2.5), Lua 5.4 has
two garbage collection modes: an incremental collector, and a generational
collector. Both collectors seem to use a similar approach to deciding when to
collect: when the amount of bytes allocated grows beyond a certain value, a
collection is triggered.

### Ruby

Ruby uses several statistics to determine when to collect, and if a minor or
full collection should be performed. The article [Understanding Ruby GC through
GC.stat](https://www.speedshop.co/2017/03/09/a-guide-to-gc-stat.html) covers
these various statistics pretty well.

When a certain number of objects is allocated, Ruby runs a minor collection.
Full collections can be triggered if the number of promoted objects exceeds a
threshold, or if one of several other conditions (which we won't cover here) is
met. Ruby will also increase these thresholds if needed, though I can't remember
if the collector always increases these thresholds, or only in certain cases.

## Conclusion

While this article is not the most in-depth overview of deciding when to trigger
a garbage collection, I hope it's useful enough to give a better understanding
of what may trigger a collection, and what impact the various techniques will
have.
