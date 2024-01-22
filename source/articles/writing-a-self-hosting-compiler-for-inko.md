---
{
  "title": "Writing a self-hosting compiler for Inko",
  "date": "2019-06-08T00:00:00Z"
}
---

About a year ago I wrote ["Inko: a brief introduction"][inko-introduction], and
later published the [Inko website][inko-website]. Since then, I made a lot of
progress towards making it useful for everyday use. Some recent milestones
include:

- A Foreign Function Interface.
- A new process scheduler that is easier to maintain, and performs better.
- Non-blocking sockets, without the need for callbacks.
- Reduced memory usage per process.

The next milestone for Inko is having a self-hosting compiler. But why would one
want to write a self-hosting compiler? Why not use an already established
language? What are the benefits of writing a self-hosting compiler? Let's find
out!

## The first compiler

When creating a language, you need a way to compile its source code. But we
can't use our own language, since we are still developing it. To deal with this,
developers use a different language for the first compiler. Two examples of this
are Rust and Go. The first compiler for Rust was written in OCaml, and the first
compiler for Go was written in C.

For Inko's current compiler we use Ruby. Before writing the compiler in Ruby I
made an attempt at writing it in Rust. Inko's Virtual Machine is also written in
Rust, so using Rust for the compiler made sense at the time. Writing the
compiler in Rust turned out to be frustrating, as I kept running into minor
issues along the way. After about a month, I decided to cut my losses and use
Ruby instead. Using Ruby allowed me to deliver a working compiler faster.

There were also two others reasons for using Ruby instead of Rust:

1. The compiler would one day be rewritten in Inko. This meant that quality was
   not the focus of the first compiler. Instead, it had to focus getting enough
   done so I could start building the standard library.
1. Ruby is closer to Inko than Rust is, which makes it easier to port code to
   the new compiler.

Rust tends to be an unforgiving language, at least it feels that way. This makes
sense when you are writing production-ready software, but can slow you down when
trying to prototype a compiler.

## Benefits of a self-hosting compiler

If we have to use a different language for our first compiler, why not keep
using this compiler? Why should one spend the extra time and effort on making
their compiler self-hosting?

A typical compiler consist of different components, such as:

- A lexer.
- A parser (sometimes the parser also takes care of lexing the input).
- Type checking.
- Optimisation passes.
- Code generation.

To write our compiler in our own language, the language must provide the
necessary features. Such features might be:

- String slicing.
- Concurrency primitives.
- A unit testing framework.
- APIs for working with the filesystem.

Adding these features to the standard library benefits all users of the
language. We could come up with a list of features to add, without a reference
program. But it can be difficult to come up with every possible feature, before
there is a use case for them. Worse, we may end up adding features that turn
out to not be useful once actually used.

Performance is also important for a programming language. Your language can have
all the features in the world, but users will not use it if the language is too
slow. To ensure our language performs well, we need a way to measure and improve
its performance. One way of doing this is by writing synthetic benchmarks.
While useful for measuring specific sections of code, they are not useful for
determining the impact of a change on a larger program.

A more realistic way of measuring performance is using a program with users.
Compilers are an excellent reference. For example, a lexer operates on
sequences of characters or bytes, executing code for every value in the
sequence. Without any optimisations, such code could be slow. By writing our
compiler in our own language, we have a program to measure the performance
impact of changes made to the language.

While not a benefit per se, making the compiler self-hosting is a way of showing
the capabilities of the language. If you can write the language's compiler in
the language itself, you can write any other program in the language.

## Towards a self-hosting Inko compiler

The first step towards a self-hosting compiler was to simplify the syntax in
various places. For example, Inko allowed you to implement a trait in two
different ways: when defining an object, or separately. Implementing a trait
when defining an object looked like this:

```inko
object Person impl ToString {
  # ...
}
```

The alternative is to implement the trait separately:

```inko
impl ToString for Person {
  # ...
}
```

I added support for both so that object definitions and trait implementations
were closer together. This complicates various parts of the compiler. In
practise I also found it not to be as useful as anticipated.

Another syntax change is the removal of support for unicode identifiers. Being
able to use unicode identifiers could be useful, but it complicates the
lexer. I also doubt it will see much use in the coming years.

With the syntax simplified, I started implementing the lexer. The merge
request tracking progress is ["Implement Inko's lexer in Inko itself"][mr-59].

## Implementing Inko's lexer in Inko

As I work on the compiler I will write about the progress made, starting with
the lexer. After all, talking about the compiler and not showing anything would
be boring.

The basic idea of a lexer is simple: take a sequence of bytes or characters, and
produce one or more "tokens". A token is some sort of object containing at least
two values: a type indicator of some sort, and a value. The type indicator could
be a string, integer, enum, or something else. The value is typically a string.

Inko uses an object called `Token` for tokens, defined as follows (excluding
methods not relevant for this example):

```inko
object Token {
  def init(type: String, value: String, location: SourceLocation) {
    let @type = type
    let @value = value
    let @location = location
  }
}
```

For those unfamiliar with Inko's syntax, this defines and object called `Token`
and its constructor method `init`. The `init` method takes three arguments:

1. `type`: the type name of the token, such as `'integer'` or `'comma'`.
1. `value`: the value of the token, such as `'10'` for an integer.
1. `location`: an object that contains source location information, such as the
   line range and column number.

The `init` method sets three instance attributes: `@type`, `@value`, and
`@location`.

For the lexer, Inko uses an object called `Lexer`. Showing all the lexer's
source code would be a bit much. Instead, we'll highlight some interesting
parts. The constructor of the lexer is as follows:

```inko
object Lexer {
  def init(input: ToByteArray, file: ToPath) {
    let @input = input.to_byte_array
    let @file = file.to_path

    # ...
  }
}
```

`ToByteArray` is a trait that provides the method `to_byte_array`, for
converting a type to a `ByteArray`. When reading data from a file, Inko will
read it into a `ByteArray`. Converting this to a `String` requires allocating an
extra object, and twice the memory. The type `ByteArray` also implements the
`ToByteArray` trait. This allows lexing of files, without allocating a `String`:

`ToPath` is a trait that provides the method `to_path`, for converting a type to
a `Path`. `Path` is a type that represents file paths, providing a more
pleasant interface compared to using a `String`. Using this trait allows one to
supply either a `String` or a `Path` as the `file` argument:

```inko
import std::compiler::lexer::Lexer
import std::fs::path::Path

Lexer.new(input: '10', file: 'test.inko')
Lexer.new(input: '10', file: Path.new('test.inko'))
```

The `Lexer` type is an iterator, allowing the user to retrieve tokens one by
one:

```inko
import std::compiler::lexer::Lexer

let lexer = Lexer.new(input: '10', file: 'test.inko')
let token = lexer.next

token.type  # => 'integer'
token.value # => '10'
```

To determine what token to produce, a `Lexer` will look at the current byte in
the input. Based on the current byte, `next` sends different messages to the
`Lexer`. The implementation of `next` is a bit much to cover, but more or less
looks as follows:

```inko
def next -> ?Token {
  let current = current_byte

  current == A
    .if_true {
      return foo
    }

  current == B
    .if_true {
      return bar
    }

  Nil
}
```

The return type here is `?Token`, meaning it may return a `Token` or `Nil`.

Inko does not have a `match` or `switch` statement, instead we compare objects
for equality and use block returns. In the above example, if `current == A`
evaluates to true we return the result of `foo`, skipping the code that follows
it. Reading the above code, one might think that the code is incorrect. In most
languages, this code:

```inko
A == B
  .foo
```

Is parsed as this:

```inko
A == (B.foo)
```

In Inko this is not the case. _If_ the message that follows a binary operation
(`A == B`) is on a new line, it's sent to the _result_. This means it's parsed
as follows:

```inko
(A == B).foo
```

This allows one to write this:

```inko
A == B
  .and { C }
  .if_true {
    # ...
  }
```

Instead of this:

```inko
(A == B)
  .and { C }
  .if_true {
    # ...
  }
```

For certain tokens we need to perform more complex checks. For example, for
integers we can not compare for equality because an integer can start with
different values (`0`, `1`, etc). Instead, we use Inko's range type like so:

```inko
INTEGER_DIGIT_RANGE.cover?(current).if_true {
  return number
}
```

Here `INTEGER_DIGIT_RANGE` is a range (using the `Range` type) covering the
digits 0 to 9. The method `cover?` checks if its argument is contained in the
range, without evaluating all values in the range.

The implementations of the methods that produce tokens vary. Some are simple,
others are more complex. Strings in particular are tricky, as they can contain
escaped quotes and escape sequences (`\n`, `\r`, etc).

Numbers are also tricky, as there are different number types and formats:

- Regular integers: `123`.
- Hexadecimal integers: `0x123abc`, `0X123ABC`.
- Floats: `10.23`, `1e2`, `1E2`, `1e+2`, `1E+2`, `1e-2`, `1E-2`.

The difficulty here is that the type is not known until reaching a certain
character, such as `.` or `x`.

Covering all this would be far too much, so I recommend taking a closer look
at the merge request ["Implement Inko's lexer in Inko itself"][mr-59].

## Work after the lexer

After finishing work on the lexer, the parser is next. After that, I will
have to spend some time planning what steps would be next. I would like for the
compiler to be parallel and incremental, but I do not yet have an idea on how to
implement this. I also need to revisit the type system, as certain parts feel a
bit hacky.

Determining how long all this takes is difficult. After implementing the parser
I will have a better estimate. I expect it will take between three and six
months. I do have a three week vacation in a couple of weeks, and I tend to be
productive during my vacations. Perhaps a bit too productive.

[inko-introduction]: /articles/inko-a-brief-introduction/
[inko-website]: https://inko-lang.org
[mr-59]: https://gitlab.com/inko-lang/inko/merge_requests/59
