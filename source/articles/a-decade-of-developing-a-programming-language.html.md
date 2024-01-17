---
title: "A decade of developing a programming language"
date: "2023-11-14 11:00:00 UTC"
---

In 2013, I had an idea: "what if I were to build my programming language?". Back
then my idea came down to "an interpreted language that mixes elements from Ruby
and Smalltalk", and not much more.

Between 2013 and 2015 I spent time on and off trying different languages (C,
C++, [D](https://dlang.org/) and various others I can't remember) to see which
one I would use to build my language in. While this didn't help me find a
language I _did_ want to use, it did help me eliminate others. For example, C
proved to be too difficult to work with. D seemed more interesting and I managed
to implement something that vaguely resembles a virtual machine, but I
ultimately decided against using it. I don't remember exactly why, but I believe
it was due to the rift caused by the differences between D version 1 and 2, the
general lack of learning resources and packages, and the presence of a garbage
collector.

Somewhere towards the end of 2014 I discovered
[Rust](https://www.rust-lang.org/). While the state Rust was in at the time is
best described as "rough", and learning it (especially at the time with the lack
of guides) was difficult, I enjoyed using it; much more so than the other
languages I had experimented until that point.

2015 saw the release of [Rust 1.0](https://blog.rust-lang.org/2015/05/15/Rust-1.0.html),
and that same year I committed the [first few lines of Rust
code](https://github.com/inko-lang/inko/commit/f8cf2530e26042515ed4a6b06eabf46c425bc87e)
for [Inko](https://inko-lang.org/), though it would take another two months or
so before the code started to (vaguely) resemble that of a programming language.

Fast-forward to 2023, and Inko is in a state where one can write meaningful
programs in it (e.g. [HVAC automation
software](https://github.com/yorickpeterse/openflow), a [Markdown
parser](https://github.com/yorickpeterse/inko-markdown), a [changelog
generator](https://github.com/yorickpeterse/clogs) and more). Inko has also
changed considerably over the years: whereas it was once a gradually typed
interpreted language, it's now statically typed and compiles to machine code
using [LLVM](https://llvm.org/). And whereas Inko used to draw inspiration
heavily from Ruby and Smalltalk, these days it's closer to Rust,
[Erlang](https://www.erlang.org/) and [Pony](https://www.ponylang.io/) than it
is to Ruby or Smalltalk.

Given it's been 10 years since I first started working towards Inko, I'd like to
highlight (in no particular order) a few of the things I've learned about
building a programming language since first starting work on Inko. This is by no
means an exhaustive list, rather it's what I can remember at the time of
writing.

<div class="note" markdown="0">
<i class="icon icon-comments" markdown="0"></i>
<div class="text" markdown="1">

You can find discussions about this article on Reddit
[here](https://www.reddit.com/r/ProgrammingLanguages/comments/17v05xd/a_decade_of_developing_a_programming_language/)
and [here](https://www.reddit.com/r/programming/comments/17v0avj/a_decade_of_developing_a_programming_language/),
on [Hacker News](https://news.ycombinator.com/item?id=38261982), and on
[Lobsters](https://lobste.rs/s/wyeffq/decade_developing_programming_language).

</div>
</div>

## Table of contents
{:.no_toc}

- TOC
{:toc}

## Avoid gradual typing

A big change I made was to switch Inko from being a gradually typed language to
a statically typed language. The idea behind gradual typing was that it would
allow you to build a prototype or simple scripts in a short amount of time using
dynamic typing, then over time turn the program into a statically typed program
(where beneficial).

In reality, gradual typing ends up giving you the worst of both dynamic and
static typing: you get the uncertainty and lack of safety (in dynamically typed
contexts) of dynamic typing, and the cost of trying to fit your ideas into a
statically typed type system. I also found that the use of gradual typing didn't
actually make me more productive compared to using static typing. The result was
that I found myself avoiding dynamic typing in both Inko's standard library and
the programs I wrote. In fact, the few places where dynamic typing _was_ used in
the standard library was due to the type system not being powerful enough to
provide a better alternative.

Gradual typing also has performance implications. Consider this example using
keyword arguments:

```inko
let x: Any = some_value

x.foo(b: 42, a: 10)
```

Here `x` is typed as `Any`, which used to mean the value is dynamically typed.
Because we don't know the type of `x` in `x.foo(...)`, we can't resolve the
keyword arguments to positional arguments at compile-time. This meant Inko's
virtual machine had to provide a runtime fallback, and the keyword arguments had
to be encoded into the bytecode. While the cost wasn't significant, in a
statically typed language the cost is zero because we can resolve the arguments
at compile-time.

Another issue is that the presence of dynamic types can inhibit compile-time
optimizations, such as compile-time inlining (and all the optimizations that
depend on it). If a language uses a Just In Time (JIT) compiler, such as
JavaScript (and by extension [TypeScript](https://www.typescriptlang.org/)), you
can optimize the code at runtime, but that means having to write a JIT compiler
which itself is a massive undertaking.

The presence of dynamic types also means that even statically typed code may
be incorrect, though this depends on how you approach casting dynamically typed
values to statically typed values. If such a cast doesn't require a runtime
check, you may end up passing incorrectly typed data to statically typed code.
If you do perform some sort of runtime check, this may affect performance when
such casts are common.

**Recommendation:** either make your language statically typed or
dynamically typed (preferably statically typed, but that's a different topic),
as gradual typing just doesn't make sense for new languages.

<div class="note" markdown="0">
<i class="icon icon-info-circle" markdown="0"></i>
<div class="text" markdown="1">

The emphasis here is on _new_ languages, as applying gradual typing to an
existing language _can_ be useful, especially as an intermediate step towards
the language becoming fully statically typed.

</div>
</div>

## Avoid self-hosting your compiler

Early in the development of Inko, I decided that I wanted to write the compiler
in Inko itself, commonly referred to as a "self-hosted compiler". The idea was
that by doing so, the compiler could be exposed through the standard library,
and to have a sufficiently complicated program to test everything Inko has to
offer.

While this seems great on paper, in practise it turns into a real challenge.
Maintaining a single compiler is already a challenge, but maintaining two
compilers (one to bootstrap your self-hosted compiler, and the self-hosted
compiler itself) is even more difficult. The process of building the compiler is
also more complicated: first you have to build the bootstrapping compiler, then
you can use that to build the self-hosted compiler. Ideally you then use that
self-hosted compiler to compile itself a second time, so you can ensure the
behaviour doesn't subtly change depending on what compiler (the bootstrapping or
self-hosted compiler) is used to compile your self-hosted compiler.

Because of these challenges, I abandoned this idea in favour of writing the
compiler in Rust, and keeping it that way for the foreseeable future.

**Recommendation:** defer writing a self-hosted compiler until you have a solid
language and ecosystem. A solid language and ecosystem is infinitely more useful
to your users than a self-hosted compiler.

## Avoid writing your own code generator, linker, etc

When writing a language, it's tempting to take on more than you can or probably
should handle. In particular, it may be tempting to write your own native code
generator, linker, C standard library, and so on (i.e what languages such as
[Zig](https://ziglang.org/) and [Roc](https://www.roc-lang.org/) are doing).

My general recommendation is to avoid this unless you have established a clear
need for this. And when you do think there's a need, I'd still avoid it. Writing
a language is hard enough as-is and can easily take years. For every such
component (a linker, a code generator, etc) you add on top, it will take
several more years before the stack as a whole becomes useful. That's ignoring
the painful fact that such bespoke components are highly unlikely to outperform
the established alternatives.

**Recommendation:** there are many developers who think they can write a
better linker, code generator, and so on, but few developers who actually
succeed in doing so. As harsh as it may sound, you are probably not one of them.
Of course once you have an established language, you're free to reinvent as many
of these wheels as you see fit.

<div class="note" markdown="0">
<i class="icon icon-info-circle" markdown="0"></i>
<div class="text" markdown="1">

If you're writing an interpreted language, it's fine and probably even needed to
write your own (byte)code generator (unless you target an existing virtual
machine such as the JVM), as bytecode generators are typically not that
complicated to implement.

</div>
</div>

## Avoid bike shedding about syntax

The syntax of a language and how its parsed is one of the most boring aspects of
building a language. Writing parsers in general is pretty dull, and there's not
a lot you can innovate upon.

And yet, it's a subject many developers building their own language seem to
spend _way_ too much time on. There are also plenty of articles titled something
along the lines of "How to build your own programming language", only covering
the basics of writing a parser and nothing more.

For Inko I took a different approach in its early days: I used an
[S-expression](https://en.wikipedia.org/wiki/S-expression) syntax, instead of
designing my own syntax and writing a parser for it. This meant I was able to
experiment with the semantics and virtual machine of the language, instead of
worrying over what keyword to use for function definitions.

**Recommendation:** use an existing syntax and parser when prototyping your
language, allowing you to focus on the semantics instead of the syntax. Once you
develop a better understanding of your language you can switch to your own
syntax.

## Cross-platform support is a challenge

This shouldn't be entirely surprising, but supporting different platforms
(Linux, macOS, Windows, etc) is _hard_. For example, Inko used to support
Windows when it used an interpreter. When switching to a compiled language, I
had to drop support for Windows as I couldn't get certain things to work (e.g.
the assembly used for switching thread stacks).

Running tests on different platforms is also not nearly as easy as it should be.
Take [GitHub Actions](https://github.com/features/actions): you can use it to
run tests on Linux, macOS, and Windows. Unfortunately, the free tier (at the
time of writing) only supports AMD64 runners, and while it _does_ support macOS
ARM64 runners, these cost $0.16 per minute.

The cost isn't even the biggest problem here, because depending on how often
tests run it may not be that big. Rather, the problem is that paid runners
typically aren't available for forks, meaning pull requests from third-party
contributors won't be able to run the tests using these runners.

And this is ignoring the problem of supporting platforms not supported by your
continuous integration platform (e.g. GitHub Actions) of choice. FreeBSD is a
good example of this: GitHub Actions just doesn't support it, so you need to use
[qemu](https://www.qemu.org/) or similar software to run FreeBSD in a VM.

Even if you _just_ support Linux, you still have to deal with the differences
between Linux distributions. For example, Inko uses a Rust wrapper for LLVM
([Inkwell](https://github.com/TheDan64/inkwell)), but the low-level LLVM wrapper
([llvm-sys](https://gitlab.com/taricorp/llvm-sys.rs)) it uses [doesn't compile
on Alpine Linux](https://gitlab.com/taricorp/llvm-sys.rs/-/issues/44), and so
Inko doesn't support Alpine Linux for the time being.

The extend to which this is a problem depends on the language you're trying to
build. For example, if you're building an interpreter written in Rust it
probably won't be that bad (though Windows is always going to be a challenge),
but it _is_ something you need to be prepared for.

**Recommendation:** if you're uncertain about supporting a certain platform, err
on the side of not supporting it and document this, instead of
sort-of-but-not-quite supporting it.

## Compiler books aren't worth the money

While there are plenty of books on compiler development, they tend to not be
that useful. In particular, such books tend to dedicate a significant amount of
time to parsing, arguably the most boring part of a compiler, then only briefly
cover the more interesting topics such as optimizations. Oh, and good luck
finding a book that explains how to write a type-checker, let alone
one that covers more practical topics such as supporting sub-typing, generics,
and so on.

**Recommendation:** start with reading [Crafting
Interpreters](https://craftinginterpreters.com/), and read through
[/r/ProgrammingLanguages](https://www.reddit.com/r/ProgrammingLanguages/) on
Reddit. If you're interested in learning more about pattern matching, [this Git
repository may prove
useful](https://github.com/yorickpeterse/pattern-matching-in-rust).

## Growing a language is hard

Building a language is a significant challenge on its own. Growing the number of
users using your language and the libraries written in your language? That's
even more difficult. In particular, it seems languages either explode in terms
of popularity/interest, even if that may not be warranted (looking at you,
[V](https://vlang.io/)), or it takes _years_ for them to get even a handful of
users.

Making a living off a programming language is _exceptionally_ difficult, as the
number of people willing to donate money is even smaller than those willing to
try out your new language. This means either dedicating a lot of spare time
towards building your language, or quitting your job and funding the development
yourself (e.g. using your savings). This is what I did by the end of 2021 and
while I don't regret doing so, it's a bit painful to watch your wallet shrink
over time.

As far as advice goes, I'm not sure how to approach this as I'm still figuring
that out myself. What I do know is that a lot of existing advice isn't helpful
at all, as it amounts to "Just get more users, LOL". Perhaps in another 10 years
from now I'll know the answer.

## The best test suite is a real application

This one is a bit obvious, but worth highlighting regardless: writing unit tests
for your language (e.g. for the standard library functions) is important and
useful, but nowhere near as useful as writing a real application in the
language. For example, I wrote a program to [control my house's HVAC
system](https://github.com/yorickpeterse/openflow) in Inko, revealing various
bugs and areas of improvement in the process. Such applications also act as a
showcase for your language, making it easier for potential users to develop an
understanding of what an average project in your language might look like.

**Recommendation:** write a few sufficiently complicated programs that are
actually useful in your language, then use these as a way of testing
functionality and stability of your language. If you can't think of any programs
to write, consider porting [this changelog generator written in
Inko](https://github.com/yorickpeterse/clogs), as it's complex enough to
act as a good stress test for your language, but not so complex it will take
weeks to port.

## Don't prioritize performance over functionality

When building a language, it can be tempting to focus heavily on providing a
fast implementation, such as a fast and memory efficient compiler, and one can
easily spend months working on this. Potential users of your language may care
about performance to some degree, but what they care about more is being able to
_use_ your language, write libraries in it, and not having to reimplement every
basic feature themselves because of a lacking standard library.

To put it differently: the value of good performance is proportional to the
amount of meaningful code (= real applications) written in a language.

**Recommendation:** as the saying goes: first make it work, then make it fast.
This doesn't mean you should not care about performance at all, rather 70-80% of
your energy should be directed towards functionality, with the remaining 20-30%
directed towards making the language not unreasonably slow.

## Building a language takes time

To wrap things up, here's another observation that should be obvious but is
worth bringing up regardless: building a simple language for yourself in a short
amount of time is doable. Building a language meant to be used by many for many
years to come is going to take a _long_ time. To illustrate, here are some
examples of a few languages and when they released their first stable release (a
`?` indicates no stable release is available at the time of writing):

| Language | Started in | Release of 1.0.0
|----------|------------|-----------------
| Python   | 1989       | 1994
| Ruby     | 1993       | 1996
| Scala    | 2001       | 2004
| Rust     | 2006       | 2015
| Go       | 2007       | 2012
| Elixir   | 2011       | 2014
| Crystal  | 2011       | 2021
| Vale     | 2012       | ?
| Inko     | 2013       | ?
| Gleam    | 2016       | ?
| V        | 2019       | ?

On top of that, there can be significant time between a language becoming stable
and it becoming popular. Ruby 1.0 released in 1996, but it wouldn't be until
2005 or so that Ruby became popular with the release of Ruby on Rails. Rust in
turn saw a rise in popularity following its first stable release, but it would
still take a few years for the language to take off. Scala released version
1.0.0 in 2004, but didn't see widespread adoption until some time between 2010
and 2015.

Based on these patterns, I suspect that most languages will need at least 5-10
years of development before reaching their first stable release, followed by
another 5 years or so before it starts to take off. That's all assuming you end
up lucky enough for it to actually take off, as there are many languages that
instead fade into obscurity.

**Recommendation:** if you want your language to succeed, be prepared for it to
take at least 10-15 years. If you expect it to take the world by storm in just a
year, you'll be sorely disappointed.
