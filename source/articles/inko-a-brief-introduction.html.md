---
title: "Inko: a brief introduction"
date: 2018-05-02 22:00 CEST
tags: inko, introduction, concurrent, object oriented, programming language
description: >
  A brief introduction to Inko: a safe, interpreted, garbage collected,
  gradually typed, object-oriented programming language for writing concurrent
  programs.
---
<!-- vale off -->

[Inko][inko] is a programming language I started working on in early 2015. The
goal of the project is to create a gradually typed, object-oriented programming
language with a focus on safety and concurrency. Inko draws inspiration from
various other languages, such as Smalltalk, Erlang, Rust, and Ruby. Like any
other language, it is not perfect but the more time I spend working on it, the
more I believe it could turn out to be a useful programming language.

While the language is still quite far from being usable, I have been making a
lot of progress with both the compiler and the standard library. As a result, I
think it's time to start writing a bit more about the language, starting with a
brief introduction of what Inko is all about.

Keep in mind that the exact syntax is subject to change and that some
topics/features discussed in this article might not yet be available. In
particular, large parts of the compiler's type system and syntax are being
rewritten as part of the ["Rewrite the Ruby compiler's type system"][mr1] merge
request.

## Table of contents
{:.no_toc}

* TOC
{:toc}

## History

The idea of building my own programming language dates to early 2013. Back then,
I knew little about programming languages, parser, virtual machines, and so
on. I also wasn't quite sure what I was looking for in this language. It wasn't
until early 2015 that I started writing code for the project, starting with the
virtual machine. It was also around this time that I started to have a better
understanding of what I was looking for: a language with a strong
object-oriented model and excellent support for concurrency, borrowing various
features from languages I admire, such as Smalltalk and Erlang.

I ended up writing the virtual machine in Rust, though Rust wasn't my first
choice. At the time Rust was still new and unstable, with both the syntax
and functionality changing frequently. So I first looked into other languages
such as C, C++, and D. While I made quite a bit of progress with using D, I felt
that using a garbage collected language for a virtual machine was less than
ideal. Ultimately I decided to go with Rust since it seemed to be the most
suitable. At first, this was quite frustrating, but as Rust began settling in
the frustration fortunately went away.

Today I'm quite happy with the choice of using Rust for the VM. Rust certainly
has its flaws, but I find it much easier and much more pleasant to use than
languages such as C/C++ and similar low-level programming languages.

## Object model

Inko is a [prototype-based][prototypes] object-oriented programming language,
though the use of prototypes is mostly hidden from the user. Instead of
inheritance, Inko uses composition using [traits][traits]. I never really
enjoyed the use of inheritance as I feel it couples objects too tightly, and
composition through traits feels like the right answer to this problem. While
Inko supports the creation of class-like objects using an `object` keyword, we
simply call these "objects". This may seem odd but it helps clarify that these
aren't traditional classes that support inheritance. For example, if we want to
define a "Person" object of sorts, you could do so as follows in Ruby:

```ruby
class Person
  def initialize(name)
    @name = name
  end
end
```

The equivalent Inko code would be:

```inko
object Person {
  def init(name: String) {
    let @name = name
  }
}
```

Here `let @name = name` defines an instance attribute called `@name` set to the
value of the `name` argument, with the type of `name` being a `String`. If we
wanted to use dynamic typing, we would simply leave out the type signature:

```inko
object Person {
  def init(name) {
    let @name = name
  }
}
```

## Message passing

Inko uses message passing for pretty much everything, including constructs such
as "if" and "while"., allowing objects to decide how such constructs should
behave, instead of the language dictating what evaluates to be true and false,
for example. This means that instead of using an "if statement", you would use
the "if" _message_.

Say you want to check if `x` is greater than 10. In Ruby (and many other
programming languages) you may write such code as follows:

```ruby
if x > 10
  do_something
else
  do_something_else
end
```

In Inko we would instead write:

```inko
x > 10
  .if true: {
    do_something
  }, false: {
    do_something_else
  }
```

Here `if` is a message sent to the result of `x > 10` (this relies on some
special syntax support so you don't have to write `(x > 10).if`). `true:` and
`false:` are simply keyword arguments sent to the `if` message, and the curly
braces are closures. The object the `if` message is sent two determines which of
the two closures is executed.

Methods can be defined using a `def` keyword, take an optional arguments list,
and may specify the throw and return type:

```inko
def example(argument: Type) -> ReturnType {
  # ...
}
```

If you leave out the argument types or the return type Inko will use a dynamic
type instead:

```inko
def example(argument: Type) {
  # This method can return values of any type since its return type is inferred
  # as a dynamic type.
}
```

## Type system

Inko is a gradually typed programming language. Gradual typing gives you the
benefits of a statically typed language while still allowing you to trade
type safety for flexibility where necessary. Gradual typing is also useful when
prototyping or when building a simple program that won't really benefit from
static typing (e.g. a quick script to manage some music files).

To ensure type safety, Inko uses static typing by default, requiring you to
opt-in to dynamic typing where desired. Using dynamic typing is straightforward:
simply leave out the type signature in various places and Inko will treat the
types as dynamic types.

Like any other reasonable statically typed language, Inko supports generics
programming. For example, we can define a generic "List" type like so:

```inko
object List!(T) {
  # ...
}
```

Here `!(T)` defines the list of type parameters of the "List" type. The type
parameter syntax is taken from [D][dlang]. While unusual it removes the need for
additional syntax when explicitly passing type parameters with a message. For
example, Rust uses `<T>` and requires you to write `foo::<T>()` when explicitly
passing a type parameter as `foo<T>` would be parsed as `(foo) < (T>)`.

Using `!(T)` means that we can instead write `foo!(T)`, which is much easier on
the fingers. Scala uses `[]` (e.g. `List[T]`), and while easier to type (on
QWERTY it doesn't require the use of the shift key) Inko isn't able to use this
syntax because `[]` is a valid message name. For example: `foo[10]` translates
to `foo.[](10)`.

Generics can be used in objects, traits, and methods. For example:

```inko
object Person {
  def ==(other: Self) -> Boolean {
    # ...
  }
}
```

Here `other` uses the "Self" type which tells the compiler that `other` is of
the same type as the enclosing object ("Person" in this case).

## Booleans and Nil

In many languages, the boolean values `true` and `false` are some kind of
primitive value instead of a structure or object. In Inko, they are just regular
objects like any other. The type `Boolean` in turn is just a trait implemented
by the Boolean objects `True` and `False`.

The absence of a value can be indicated using a `Nil`. `Nil` is just a regular
object like any other, but there's only one instance of this object. `Nil` is
set up in such a way that any message sent to it returns `Nil`, except for a few
messages that have a custom implementation. For example, `Nil.foo` would return
`Nil` but `Nil.to_integer` would return `0`. This greatly simplifies code as we
no longer need to constantly check if we're dealing with a value of type `T` or
`Nil`, though of course we still can if necessary.

Optional types can be used to indicate that something can be either of type `T`
or `Nil`. For example, to define an optional return value we would write:

```inko
def example -> ?Integer {
  Nil
}
```

It is an error to pass a `Nil` to a regular type (e.g. `String`), but it's
perfectly fine to pass a `Nil` to an optional type (e.g. `?String`).

One example of where this is useful is when retrieving an array value by its
index. Like Ruby, an array will return a `Nil` when there is no value for a
given index. In Ruby, this means you may need to check what type of value you
are dealing with, for example:

```ruby
user = list_of_users[4]

if user
  user.username
else
  ''
end
```

In Inko, we can instead write the following:

```inko
list_of_users[4].username.to_string
```

Should `list_of_users[4]` return a `Nil` then sending `username` will produce
another `Nil`. Sending `to_string` to `Nil` will produce an empty `String` since
`Nil` defines its own implementation of this method.

In short, by having `Nil` return a new `Nil` for unknown messages we can greatly
reduce the amount of code necessary to deal with values that might be absent
(but we can still check for a `Nil` where necessary).

## Error handling

Inko uses exceptions for error handling, drawing inspiration from an article
titled ["The Error Model"][the-error-model] by Joe Duffy. The article is quite
long but definitely worth the read.

I went with exception handling, since the happy path of the code should not be
slowed down by error handling code. For example, when using a more functional
approach, such as using a `Result` type, you always need to check what you're
dealing with and "unwrap" the underlying value. When using exceptions, on the
other hand, you just use the code as if it didn't throw an error, automatically
jumping to a different region of code when it does.

### Error handling principles

The basic principles of Inko's error handling system are that it should be clear
when something throws, what it throws, and most important of all that code
doesn't lie about any of this. To achieve this, Inko has a set of rules that
must be followed when working with errors.

#### Method signatures must include the error type

A method that throws an error must include the error type in its signature. This
can be done using the `!!` keyword in the method signature:

```inko
def foo !! SomeError {
  # ...
}
```

This ensures that by just looking at the method (signature) we immediately know
what errors we have to deal with.

A method that does not define an error type to throw _can not_ throw. This means
the following method would not compile:

```inko
def foo {
  throw 10
}
```

#### Only a single type can be thrown

A method can only throw an error of a single type, though you can specify the
type to be a trait and throw any value that implements this trait. By
restricting the number of possible types to just a single one we remove the need
for having to catch many different error types. It also simplifies the syntax.

#### Methods that define a throw type must actually throw it

A method that specifies a type to throw must actually throw this type at some
point, not doing so results in a compiler error. This means that the following
method would not compile since it never throws a value:

```inko
def foo !! Integer -> Integer {
  10
}
```

#### Sending a message that may throw requires explicit error handling

When sending a message that may throw, we _must_ wrap the send in a `try`
expression:

```inko
try foo
```

This makes it clear to the reader that `foo` may throw, without requiring them
to first find the implementation of the method to figure this out.

By default, the `try` expression will just re-throw the error type, but you can
explicitly handle the error by using an `else` expression:

```inko
try foo else (error) bar(error)
```

Here we would run `foo` and if it succeeds, we'd return whatever `foo` returned.
If `foo` threw an error, we'd run `bar` instead. Here the `error` variable would
contain the object that was thrown. The type of `error` is inferred by the
compiler.

The `else` expression supports multi-line expressions as well, which can be
useful when your error handling logic is more complex:

```inko
try foo else (error) {
  bar(error)
  baz(error)
}
```

Sometimes we just want to terminate the program if an operation failed. In this
case, we can use `try!` instead of `try`:

```inko
try! foo
```

#### The "try" keyword only supports a single expression

To prevent one from wrapping hundreds of lines of code in a single "try"
expression, the syntax simply doesn't support this; instead you can only use a
single expression with "try" expression. This means that the following code
would produce a syntax error:

```inko
try {
  foo
  bar
}
```

This however is perfectly fine:

```inko
try {
  foo
}
```

Curly braces can still be used in case the expression doesn't fit on a single
line, or it's simply more readable by using curly braces.

### Bugs are not recoverable

Many languages that use exceptions make the mistake of using exceptions for
errors caused by bugs. In Ruby, dividing by zero will result in a
`ZeroDivisionError` error being thrown. Inko instead uses "panics". When a panic
occurs, the virtual machine will print a stacktrace of the panicking process and
_terminate the entire program_. This ensures that bugs are caught as early as
possible, and more importantly can't be hidden by simply catching and ignoring
the exception. Some examples of operations that may panic:

1. Dividing by zero.
1. Formatting a time object using an incorrect string format.
1. Trying to allocate memory when no system memory is available.

The general idea is fairly straightforward: if an error is the result of a bug
or _shouldn't_ happen then it should be a panic. If an error is likely to occur
frequently (e.g. a network timeout) it should be an exception.

## Concurrency

Inko's concurrency model is heavily inspired by Erlang. Instead of using OS
threads directly Inko provides lightweight processes. These processes have their
own heap and are garbage collected independently.

Communication between these processes happens through message passing, with the
messages being deep copied. Certain permanent objects (e.g. modules) are
allocated on a separate permanent heap and processes can access these objects
without copying. While deep copying comes with a performance penalty (depending
on the size of the data being copied) it ensures that a process can never refer
to the memory of another process. This in turn ensures that the garbage
collector only has to suspend the process that it has to garbage collect,
instead of also having to suspend any processes that use this process' memory.

Processes use preemptive multitasking using a reduction system similar to
Erlang. In short: every process has a number of "reductions" it can perform.
Once this value reaches 0 the value is reset and the process is suspended. The
virtual machine provides two thread pools for executing processes: one for
regular processes, and one for processes that may perform blocking operations
(e.g. reading from a file).

Inko provides the means to move a process between these two pools whenever
necessary. This means that when performing a blocking operation we don't need to
spawn a separate process in a separate thread pool, instead we just move our
process from one pool to another; moving it back once our blocking operation has
been completed.

Sending and receiving messages uses dynamic typing as Inko's type system can not
be used to specify the types of messages a process may support. To work around
this Inko will eventually support a type-safe API. The exact semantics are not
yet defined, but if you're curious you can read more about this in the issue
["Type safe actor API"][issue-99].

## Memory management

Inko is a garbage collected language. The garbage collector is a parallel,
generational garbage collector based on [Immix][immix]. Fun fact: to the best of
my knowledge Inko's garbage collector is the only full implementation of Immix
apart from the one provided by [JikesRVM][jikes-rvm]. There are a few other
implementations of Immix, but the ones that I know of typically don't implement
evacuation or other parts of Immix.

The garbage collector can collect process independently, though a process will
be suspended during garbage collection. The collector being parallel means it
will use multiple threads to garbage collect the memory of a process.

How well the garbage collector performs is hard to say as I have only run a few
basic benchmarks. These benchmarks usually involved garbage collecting a few
million objects and from the top of my head this would usually only take a few
milliseconds. Once Inko matures a bit more I'll most likely spend more time
writing (and publishing) benchmarks.

## Portable bytecode

The bytecode of the virtual machine is portable between CPU architectures and
operating systems. This means that bytecode compiled on a 64 bits CPU can be run
on a 32 bits CPU. This may seem like a minor feature but it makes it easier to
distribute bytecode files as you no longer need to compile your program for
every architecture.

In the future Inko may support a way of bundling such bytecode files similar to
[JAR][jar], though this isn't supported at the moment.

## Examples

With all of that out of the way let's take a look at some examples of Inko
source code. The examples discussed below are all taken from the standard
library, which can be found [here][inko-stdlib].

### Checking if a String starts with another String

Checking if one `String` starts with another `String` can be done using the
method `String#starts_with?` in the `std::string` module. The implementation of
this method is pretty straightforward:

```inko
def starts_with?(prefix: String) -> Boolean {
  prefix.length > length
    .if_true {
      return False
    }

  slice(0, prefix.length) == prefix
}
```

The argument `prefix` is the `String` we are looking for, and our return value
is a `Boolean`. In the method we start with the following:

```inko
prefix.length > length
  .if_true {
    return False
  }
```

This is a simple optimisation: if the `String` we are looking for is greater
than the `String` we are checking then we can just return `False` right away
("hello" can never start with "hello world" for example). In Ruby you would
write this as follows:

```ruby
if prefix.length > length
  return false
end

# Alternatively:
return false if prefix.length > length
```

Next up we have the actual comparison:

```inko
slice(0, prefix.length) == prefix
```

This operation is pretty straightforward: first we generate a new `String`
starting at character 0 and include `prefix.length` characters. We then simply
check if this equals the given prefix `String`. Note that string slicing
operates on characters, not bytes.

### Loops and tail call elimination

Loops are created using closures, instead of using a special `while` or `loop`
keyword. A loop using a conditional is created by sending `while_true` or
`while_false` to a closure:

```inko
let mut number = 0

{ number < 10 }.while_true {
  number += 1
}
```

Here we create a loop that runs as long as the result of the closure `{ number <
10 }` evaluates to true. As long as this is the case we execute the closure
passed to the `while_true` message.

An infinite loop is created by sending `loop` to a closure:

```inko
{
  # This will run forever
}.loop
```

The `while_true` method is implemented as follows:

```inko
def while_true(block: do) -> Nil {
  call.if_false { return }
  block.call
  while_true(block)
}
```

Let's start with the signature. This method takes one argument `block`, which
has its type set to `do`. In this context `do` is used to specify that we expect
a closure with no arguments and a dynamic return type. If we required an
argument we would instead write `do (Integer)`. If we wanted to also include a
return type we could write `do (Integer) -> Integer`. We can also use the
`lambda` keyword to create a lambda. The difference between the two is simple: a
closure can capture outer local variables, a lambda can not. When the type
signature requires a closure you can also pass a lambda, but not the other way
around. Closures and lambdas are collectively referred to as "blocks".

Now let's look at the body of this method:

```inko
call.if_false { return }
block.call
while_true(block)
```

First we run the receiving block, returning early if it returned something that
evaluates to false. If it evaluates to true we'll simply execute the block
passed in the `block` argument, then we will call ourselves again. Inko supports
tail call elimination so we can simply keep calling `while_true` indefinitely
without blowing up the call stack.

The `loop` method is a simple method that also relies on tail call elimination:

```inko
def loop -> Nil {
  call
  loop
}
```

Here `call` will run the receiving block, then we simply recurse into `loop` to
repeat this process.

Because Inko uses preemptive multitasking, loops such as those shown above will
never block an OS thread indefinitely. Instead, the virtual machine will suspend
the process once it has consumed all of its reductions, resuming execution of
the process some time later.

### Processes and communication

To start a process, we first need to import the `std::process` module like so:

```inko
import std::process
```

Next we can start a process like so:

```inko
import std::process

let pid = process.spawn {
  # This runs in a separate process
}
```

We can send messages to a process using `process.send` and receive them using
`process.receive`:

```inko
import std::process

let pid = process.spawn {
  process.receive # This would produce 'hello'
}

process.send(pid, 'hello')
```

When using `process.receive` without any messages being available the process
will be suspended until a new message arrives.

### File operations

For our last example, we'll look at a simple file operation: reading a file. In
a typical language, you would open the file with a specific mode, then read from
it. For example, in Ruby you would do the following:

```ruby
file = File.open('example.txt', 'r')
file.read
```

Many languages will use the same data types for files opened in different file
modes. This means that the following Ruby code would compile, but produce a
runtime error (since the file is not opened for writing):

```ruby
file = File.open('example.txt', 'r')

file.write('hello')
```

Inko uses different types for files opened in different modes. For example, a
file opened in read-only mode is a `ReadOnlyFile` while a file opened in
write-only mode is a `WriteOnlyFile`. This means our first example is written as
follows:

```inko
import std::fs::file

let file = file.read_only('example.txt')

try! file.read # This will terminate the program if we couldn't read the data
```

Our second example would be as follows:

```inko
import std::fs::file

let file = file.read_only('example.txt')

try! file.write('hello')
```

This code however will not compile since a `ReadOnlyFile` does not respond to
the `write` message. I really like this API because it's straightforward to
implement and removes the need for having to worry about using the wrong file
mode for your operations.

## Trying it out

If you're curious about Inko, you can give it a try yourself, but keep in mind
that with Inko being a young language this process is a bit painful.

To try things out you need to have three things installed:

1. Ruby 2.4 or newer.
1. Bundler (`gem install bundler`).
1. Rust 1.10 or newer using a nightly build (stable Rust is unfortunately not
   supported at the moment).

Once these requirements are met you can clone the Git repository:

```bash
git clone git@gitlab.com:inko-lang/inko.git
cd inko
```

To build the compiler, you need to run:

```bash
cd compiler
bundle install
```

To build the virtual machine, you need to run (from the root directory):

```bash
cd vm
make release
```

Once done you can compile a program (from the root directory) as follows:

```bash
./compiler/bin/inkoc /tmp/test.inko -i ./runtime/ -t /tmp/inkoc-build
```

This will compile the program located at `/tmp/test.inko` and store all the
bytecode files in `/tmp/inkoc-build`. Once compiled the compiler will print the
file path of the bytecode file that belongs to the input file (`/tmp/test.inko`
in this case).

To run your program you start the VM as follows:

```bash
./vm/target/release/ivm \
    -I /tmp/inkoc-build \
    /tmp/inkoc-build/path/to/bytecode.inkoc
```

These two commands can be merged into a single one as follows:

```bash
./vm/target/release/ivm \
    -I /tmp/inkoc-build \
    $(./compiler/bin/inkoc /tmp/test.inko -i ./runtime/)
```

Of course this is far from ideal and in the future this will be greatly
simplified, but for now running a program sadly requires some additional work.

In the future I will be writing more about Inko's internals such as the garbage
collector and the allocator. If you want to stay up to date on the latest Inko
news the easiest ways of doing so are:

1. Star the project on [GitLab.com][inko].
1. Subscribe to my website's [Atom feed][atom].
1. Follow me on [Twitter][twitter].

[mr1]: https://gitlab.com/inko-lang/inko/merge_requests/1
[prototypes]: https://en.wikipedia.org/wiki/Prototype-based_programming
[inko]: https://gitlab.com/inko-lang/inko
[traits]: https://en.wikipedia.org/wiki/Trait_(computer_programming)
[dlang]: https://dlang.org/
[the-error-model]: http://joeduffyblog.com/2016/02/07/the-error-model/
[issue-99]: https://gitlab.com/inko-lang/inko/issues/99
[immix]: http://www.cs.utexas.edu/users/speedway/DaCapo/papers/immix-pldi-2008.pdf
[jikes-rvm]: https://github.com/JikesRVM/JikesRVM
[jar]: https://en.wikipedia.org/wiki/JAR_(file_format)
[inko-stdlib]: https://gitlab.com/inko-lang/inko/tree/master/runtime/std
[atom]: /feed.xml
[twitter]: https://archive.is/6LWOm
