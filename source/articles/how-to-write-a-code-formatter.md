---
{
  "title": "How to write a code formatter",
  "date": "2024-04-12T12:00:00Z"
}
---

Ask ten developers how they think a certain piece of code should be formatted,
and you'll likely get ten different opinions. Worse, these opinions are almost
never based on facts. Instead, when you ask why they prefer style X over Y the
answer is almost always the equivalent of "I just do".

What if we could sidestep this entire debate and let a computer decide for us?
No, I'm not talking about asking ChatGPT to format your code for you, I'm
talking about "code formatters".

A code formatter is a program that takes your source code as its input, formats
it using a particular style and then writes it back to disk or STDOUT. While
such tools have existed for a long time, their usage has become increasingly
more popular in the last 15 years or so. Go's
[gofmt](https://pkg.go.dev/cmd/gofmt) in particular appears to have been a
driving force behind the move towards using code formatters more, as many
popular formatters in use today started showing up in the years following the
release of gofmt. To illustrate, here's a short list of various formatters that
appear to be reasonably popular, along with the year in which they were first
introduced:

|=
| Formatter
| Language
| First introduced in
|-
| [autopep8](https://github.com/hhatto/autopep8)
| Python
| 2010
|-
| [gofmt](https://pkg.go.dev/cmd/gofmt)
| Go
| 2013
|-
| [rustfmt](https://github.com/rust-lang/rustfmt)
| Rust
| 2015
|-
| [google-java-format](https://github.com/google/google-java-format)
| Java
| 2015
|-
| [prettier][prettier]
| JavaScript, HTML, and more
| 2016
|-
| [rufo](https://github.com/ruby-formatter/rufo)
| Ruby[^1]
| 2017
|-
| [Standard Ruby](https://github.com/standardrb/standard)
| Ruby[^1]
| 2018
|-
| [mix format](https://hexdocs.pm/mix/main/Mix.Tasks.Format.html)
| Elixir
| 2017
|-
| [black](https://github.com/psf/black)
| Python
| 2018
|-
| [erlfmt](https://github.com/WhatsApp/erlfmt)
| Erlang
| 2019
|-
| [inko fmt][inko]
| Inko[^2]
| 2024

I suspect it's not so much that gofmt in itself is a particular noteworthy
formatter (other than not allowing you to configure it in any way, as it should
be), but rather that Go itself is incredibly popular and thus subjected many
developers to the beauty of not having to worry about manually formatting your
code. This then caught on over time, resulting in an increase in the number of
available code formatters since the introduction of gofmt.

So how do you actually build a code formatter? Does it require decades of
experience working with Haskell and mastering the ways of the monad? Or maybe
you have to read hundreds of computer science papers to understand the deeper
meaning of the lambda? What about acquiring a crippling student debt by studying
at MIT for four years in an attempt to better understand computer science as a
whole?

No, writing a decent code formatter is in fact straightforward, it just isn't
explained in a simple way, like so many other topics in computer science. Lucky
for you, I recently spent several weeks writing a code formatter for
[Inko][inko], so naturally I'm now an expert on everything related to code
formatting.

The setup we'll take a look at in this article is based on Inko's formatter,
which in turn is based on [Prettier][prettier] and the paper ["A prettier
printer"](https://homepages.inf.ed.ac.uk/wadler/papers/prettier/prettier.pdf)
(which Prettier is also based on, if I'm not mistaken). The paper itself is
somewhat mundane and I've already forgotten 80% of it, but the concept is
deviously simple.

We'll be using Inko as the language of choice to show how to write a formatter,
but it should be easy enough to translate the code into different languages.

Oh, and before I forget: if you're also interested in learning how pattern
matching is implemented, take a look at [this Git
repository](https://github.com/yorickpeterse/pattern-matching-in-rust) that
contains two implementations in Rust. Like the code we'll discuss today, the
Rust code is well documented and should be easy to understand. Fun fact:
[Gleam](https://gleam.run/news/v0.33-exhaustive-gleam/) based its implementation
of pattern matching on this exact code. Neat!

## [Table of contents]{toc-ignore}

::: toc
:::

## Nodes and trees

The basic idea of the formatter is as follows: we take an Abstract Syntax Tree
(AST) of sorts, specifically one that includes comments, and convert that into a
formatting tree. The formatting tree has various nodes, such as "just render
this text" or "try to fit all sub nodes onto a single line". After constructing
the tree, we visit each node and render it to a string. The resulting string is
then written to a file or STDOUT.

Our tree will be created using a sum type, or "enum". In Inko, you define an
enum as follows:

```inko
class enum Letter {
  case A
  case B
  case C
}
```

The Rust equivalent is the following:

```rust
enum Letter {
  A,
  B,
  C,
}
```

In Inko, enum cases can wrap values when defined like so:

```inko
class enum Option[T] {
  # This case stores some value of type "T", whatever that is.
  case Some(T)
  case None
}
```

In Inko, you create an instance of an enum like so:

```inko
Option.Some(42)
Option.None
```

For our tree, we'll start with the basic definition:

```inko
class enum Node {}
```

Now let's look at the different nodes we'll need.

### Text

The two most basic nodes of our tree are `Text(value)` and `Unicode(value,
size)`.

The `Text` node stores an ASCII string (e.g. keywords in your language), while
the `Unicode` node stores a string containing one or more multi-byte characters,
along with its size expressed as the number of extended grapheme clusters. The
size for `Unicode` nodes is cached because depending on the structure of our
tree, we may end up having to calculate the width of such a node multiple times.
Since counting grapheme clusters is an `O(n)` operation, caching this value
speeds things up a bit.

We define these nodes as follows:

```inko
class enum Node {
  case Text(String)
  case Unicode(String, Int)
}
```

The `String` arguments store the string to render, while the `Int` argument is
used to store the number of extended grapheme clusters. For the `Unicode` node
we'll also add a helper method to make constructing them a little easier:

```inko
class enum Node {
  case Text(String)
  case Unicode(String, Int)

  fn static unicode(value: String) -> Node {
    # `value.chars` returns an iterator over the extended grapheme clusters,
    # and `count` simply counts them.
    Node.Unicode(value, value.chars.count)
  }
}
```

Using this method, we construct the `Unicode` nodes as follows:

```inko
Node.unicode('this is the string to render')
```

### Whitespace and indentation

For handling whitespace and indentation we'll define three nodes: `SpaceOrLine`,
`Line`, and `Indent`.

`SpaceOrLine` is a node that renders to a space if it resides in a group that
doesn't need wrapping, and renders to a line when wrapping _is_ needed.

`Line` is a node that renders to a new line if it resides in a group that needs
wrapping, otherwise it renders to nothing.

`Indent(nodes)` is a node that renders one or more nodes, indenting each new
line, but only if it resides in a group that for which wrapping is needed.

In Inko, we define these nodes like so:

```inko
class enum Node {
  ...
  case SpaceOrLine
  case Line
  case Indent(Array[Node])
}
```

To help understand these nodes and when to use them, consider the following
array we want to format:

```inko
[100, 200]
```

We'll construct the following tree to format this array:

```inko
# I'll explain what "Group" is in just a moment.
Node.Group(
  0,
  [
    Node.Text('['),
    Node.Line,
    Node.Indent(
      [
        Node.Text('100'),
        Node.Text(','),
        Node.SpaceOrLine,
        Node.Text('200')
      ]
    ),
    Node.Line,
    Node.Text(']')
  ]
)
```

When no wrapping is needed, the array is rendered as-is, because `Line` is
rendered to nothing, `Indent` only indents when wrapping is needed, and
`SpaceOrLine` renders to a space. When wrapping _is_ needed, the array is
rendered as follows:

```inko
[
  100,
  200
]
```

### Grouping nodes

To group nodes together, we can use one of two nodes: `Group` or `Nodes`.

`Group(id, nodes)` is a collection of nodes that we try to fit onto the current
line. If this doesn't fit, each sub node is placed on its own line. Each group
has an ID (just a number in the range `0 <= id <= N`) unique to the document
that we're formatting.

When nesting `Group` nodes (e.g. `Group -> something else -> Group`), the need
for wrapping is checked on a per group basis. This means that if an outer
`Group` requires wrapping, this doesn't immediately force all child groups to
also wrap.

`Nodes(nodes)` is a collection of nodes that we just render without any special
handling. This makes it easier code wise to have certain helper functions that
produce multiple nodes that we just want to concatenate together.

We define these nodes like so:

```inko
class enum Node {
  ...
  case Group(Int, Array[Node])
  case Nodes(Array[Node])
}
```

The `Int` argument is the group ID, while the `Array[Node]` arguments store the
child nodes.

When constructing the `Group` nodes we'll need to keep track of the next ID to
use. This is done by storing a counter somewhere, taking the existing value for
the new `Group`, followed by incrementing it:

```inko
let id = the_id_counter

the_id_counter += 1
Node.Group(id, nodes)
```

In Inko we can shorten this to the following:

```inko
Node.Group(the_id_counter := the_id_counter + 1, nodes)
```

The `:=` operator assigns the variable a new value, returning the previous
value. In contrast, the `=` operator discards the old value.

### Conditional formatting

The last node we'll introduce is the `IfWrap(id, A, B)` node. This is a node
that renders node A if the group using ID `id` needs to be wrapped, otherwise it
renders node B.

Using the array example shown earlier, we can use this node to add a trailing
comma when wrapping is necessary by using this tree:

```inko
Node.Group(
  0,
  [
    Node.Text('['),
    Node.Line,
    Node.Indent(
      [
        Node.Text('100'),
        Node.Text(','),
        Node.SpaceOrLine,
        Node.Text('200'),
        Node.IfWrap(0, Node.Text(','), Node.Text(''))
      ]
    ),
    Node.Line,
    Node.Text(']')
  ]
)
```

When wrapping is needed, the array is now rendered as follows:

```inko
[
  100,
  200,
]
```

## Computing widths

When formatting trees, we need to know how many characters a node occupies on
the current line, as this is used to determine if wrapping is needed. This means
we'll need a method to compute the width of a `Node`, which we'll define as
follows:

```inko
class enum Node {
  ...

  fn width(wrapped: ref Set[Int]) -> Int {
    match self {
      case Nodes(nodes) or Group(_, nodes) or Indent(nodes) -> {
        Int.sum(nodes.iter.map(fn (n) { n.width(wrapped) }))
      }
      case IfWrap(id, node, _) if wrapped.contains?(id) -> node.width(wrapped)
      case IfWrap(_, _, node) -> node.width(wrapped)
      case Text(str) -> str.size
      case Unicode(_, chars) -> chars
      case SpaceOrLine -> 1
      case _ -> 0
    }
  }
}
```

The `wrapped` argument is an immutable borrow of a hash set containing the IDs
of all groups that we've processed thus far and that needed to be wrapped. The
return value is the width as an integer. In the body we pattern match against
the current node (`self`). For nodes that contain other nodes, such as `Nodes`
and `Group`, the width is the sum of the widths of all child nodes.

For `IfWrap` we have to calculate the width differently based on whether
wrapping is needed or not. This is also why we can't compute the width once and
cache it: the width for a deeply nested node may change based on the wrapping
needs of parent nodes.

For `Text` we use `String.size` to get the size in bytes (which happens to also
be its character count, as `Text` nodes only store ASCII text), while for
`Unicode` nodes we use the pre-computed grapheme cluster count.

The implementation is a recursive algorithm instead of an iterative one, mainly
for the sake of simplicity and because it's good enough due to formatting trees
typically not being that deeply nested.

The final result is as follows:

```inko
class enum Node {
  case Group(Int, Array[Node])
  case Nodes(Array[Node])
  case IfWrap(Int, Node, Node)
  case Text(String)
  case Unicode(String, Int)
  case SpaceOrLine
  case Line
  case Indent(Array[Node])

  fn static unicode(value: String) -> Node {
    Node.Unicode(value, value.chars.count)
  }

  fn width(wrapped: ref Set[Int]) -> Int {
    match self {
      case Nodes(nodes) or Group(_, nodes) or Indent(nodes) -> {
        Int.sum(nodes.iter.map(fn (n) { n.width(wrapped) }))
      }
      case IfWrap(id, node, _) if wrapped.contains?(id) -> node.width(wrapped)
      case IfWrap(_, _, node) -> node.width(wrapped)
      case Text(str) -> str.size
      case Unicode(_, chars) -> chars
      case SpaceOrLine -> 1
      case _ -> 0
    }
  }
}
```

## Tracking the need for wrapping

When traversing the formatting tree, we need to record if wrapping is needed or
not for a particular sub tree. To do so, we'll introduce a `Wrap` enum that can
be in one of two states: `Enable`, meaning wrapping is needed, or `Detect`
meaning we need to detect it based on the width. `Detect` is the default state:

```inko
class enum Wrap {
  case Enable
  case Detect

  fn enable? -> Bool {
    match self {
      case Enable -> true
      case _ -> false
    }
  }
}
```

The `Wrap.enable?` method is added to make it a little easier to check if
wrapping is needed, without having to manually pattern match against the `Wrap`
enum.

## Lowering ASTs into formatting trees

To lower the AST into a formatting tree, we'll need a type that visits the nodes
in the AST and returns their corresponding `Node` values. We'll also need a type
that takes a `Node` and converts it to formatted source code as a string, along
with tracking the necessary state such as line lengths. For this we'll introduce
two types: `Builder` and `Generator`.

The `Builder` type is used to define the necessary methods for visiting the AST
nodes, returning their corresponding `Node` values. The `Generator` type is used
to convert those `Node` values to strings.

For the sake of simplicity, we'll restrict the code shown in this article to
handling simple function calls, text literals and strings.

### The Generator type

The basic layout of the `Generator` type is as follows:

```inko
class Generator {
  # This field is the buffer we'll write our formatted code into.
  let @buffer: StringBuffer

  # This field tracks the indentation levels, not the number of indentation
  # characters (i.e. if you use 2 spaces for indentation, you increment this
  # field by one).
  let @indent: Int

  # The number of characters/extended grapheme clusters on the current line.
  let @size: Int

  # The maximum number of characters we allow per line. If your formatter
  # doesn't allow users to change this value, you probably want to turn this
  # into a constant instead.
  let @max: Int

  # A hash set containing all the groups that need to be wrapped.
  let @wrapped: Set[Int]

  fn static new(max: Int) -> Generator {
    Generator {
      @buffer = StringBuffer.new,
      @indent = 0,
      @size = 0,
      @max = max,
      @wrapped = Set.new,
    }
  }
}
```

`StringBuffer` is a type that we can push `String` values in and concatenate
together, without producing intermediate `String` values.

To use this type, we define a `generate` method that takes a `Node`, renders it
to a `String` and stores the `String` in the buffer of the `Generator` type:

```inko
class Generator {
  ...

  fn mut generate(node: Node) {
    node(node, ref Wrap.Detect)
  }

  fn mut node(node: Node, wrap: ref Wrap) {

  }
}
```

The `generate` method just calls the `node` method with a default value for the
`wrap` argument. If your language of choice supports default arguments, this
won't be necessary and you can instead merge the two methods into a single
method.

Inko uses single ownership for memory management. The `generate` method takes
over ownership of the `Node` passed to it, because the type of the `node`
argument is `Node` and not e.g. `ref Node` (which is an immutable borrow). The
expression `ref Wrap.Detect` creates an instance of the `Wrap.Detect` case, then
passes an immutable borrow of that value to the `node` method. This borrow is
valid until we return from the call to `node`.

Before we implement the `node` method, we'll add two helper methods to the
`Generator` type and define a constant containing the characters to use for
indenting lines:

```inko
let INDENT = '  '

class Generator {
  ...

  fn mut text(value: String, chars: Int) {
    @size += chars
    @buffer.push(value)
  }

  fn mut new_line {
    @size = INDENT.size * @indent
    @buffer.push('\n')
    @indent.times(fn (_) { @buffer.push(INDENT) })
  }
}
```

::: info
In Inko, both single and double quoted string literals support escape sequences
such as `\n` and `\t`. In fact, they are exactly the same. In other languages
(e.g. Rust) you likely need to use double quotes, so keep that in mind.
:::

The `text` method adds a `String` of `chars` extended grapheme clusters to the
buffer. The `new_line` method adds a new line such, while making sure to indent
the new line. The `INDENT` constant defines the characters to use for indenting
lines. In this case we're using two spaces, but it could be four spaces, a tab,
a tab and three spaces, or something else.

Now we can take a look at the `node` method. We'll start with the basic
structure, then step through rendering each node one by one:

```inko
fn mut node(node: Node, wrap: ref Wrap) {
  match node {
    case Nodes(nodes) -> {}
    case Group(id, nodes) -> {}
    case IfWrap(id, node, _) if @wrapped.contains?(id) -> {}
    case IfWrap(_, _, node) -> {}
    case Text(str) -> {}
    case Unicode(str, width) -> {}
    case Line if wrap.enable? -> {}
    case SpaceOrLine if wrap.enable? -> {}
    case SpaceOrLine -> {}
    case Indent(nodes) if wrap.enable? -> {}
    case Indent(nodes) -> {}
    case _ -> {}
  }
}
```

::: info
If you're having a hard time understanding Inko's pattern matching syntax, you
can learn more about it in [the documentation](https://docs.inko-lang.org/manual/main/getting-started/pattern-matching/).
:::

#### Rendering Nodes

Rendering the `Nodes` node is easy: we iterate over the child nodes, and render
them individually. Similar to the `Node.width` method we'll be using a recursive
algorithm. While you can turn this into an iterative algorithm, it gets a bit
tricky and I'm not sure it would actually perform better in practice. The code
for rendering `Nodes` is as follows:

```inko
fn mut node(node: Node, wrap: ref Wrap) {
  match node {
    case Nodes(nodes) -> nodes.into_iter.each(fn (n) { node(n, wrap) })
    ...
  }
}
```

Inko doesn't have `for` loops, instead you use iterators and closures.
`nodes.into_iter` moves the `nodes` `Array` _into_ an iterator over the `Node`
values. We then use the `each` method of the iterator type to call `node` for
each value.

#### Rendering Group

Rendering `Group` nodes is where things get interesting. First, we need to
calculate the width of the child nodes, then we need to check if we can fit them
onto the current line. If so, we'll do just that, otherwise we'll render each
child node on its own line:

```inko
fn mut node(node: Node, wrap: ref Wrap) {
  match node {
    ...
    case Group(id, nodes) -> {
      let width = Int.sum(nodes.iter.map(fn (n) { n.width(@wrapped) }))
      let wrap = if @size + width > @max {
        @wrapped.insert(id)
        Wrap.Enable
      } else {
        Wrap.Detect
      }

      nodes.into_iter.each(fn (n) { node(n, wrap) })
    }
  }
}
```

Let's break this down, starting with this line:

```inko
let width = Int.sum(nodes.iter.map(fn (n) { n.width(@wrapped) }))
```

This iterates over the child nodes (without taking ownership, hence the use of
`iter` and not `into_iter`), computes the width for each node, then sums up the
result using `Int.sum()`. Note how we pass the `wrapped` hash set to each call
to `width`, this is needed so we can calculate the correct width based on the
wrapping needs of any `Group` nodes.

Next, we see if the nodes fit on the current line:

```inko
let wrap = if @size + width > @max {
  @wrapped.insert(id)
  Wrap.Enable
} else {
  Wrap.Detect
}
```

We check if the current line size plus the calculated width doesn't exceed the
line limit. If it does, we track the current `Group` ID in the `wrapped` hash
set, and use `Wrap.Enable` to signal wrapping of the child nodes is necessary,
otherwise we use `Wrap.Detect`. We when render the child nodes, passing this
`Wrap` value as an immutable borrow to each call to `node`:

```inko
nodes.into_iter.each(fn (n) { node(n, wrap) })
```

Performance wise it would be nice if we could somehow cache the output of
`width` to speed things up a bit, but I haven't found a way of doing so.
Fortunately, it shouldn't matter much as the resulting setup is fast enough. For
example, Inko's code formatter can process around 240 000 lines per second using
this exact algorithm, which is more than fast enough.

#### Rendering IfWrap

Rendering `IfWrap` nodes is straightforward: we check if the target group ID is
in the `wrapped` set or not, and render the appropriate child node:

```inko
fn mut node(node: Node, wrap: ref Wrap) {
  match node {
    ...
    case IfWrap(id, node, _) if @wrapped.contains?(id) -> {
      node(node, Wrap.Enable)
    }
    case IfWrap(_, _, node) -> node(node, wrap)
  }
}
```

The `if @wrapped` bit is a pattern matching guard, so the body is only evaluated
if both the pattern and the guard match.

#### Rendering Text and Unicode

Rendering of `Text` and `Unicode` nodes is straightforward:

```inko
fn mut node(node: Node, wrap: ref Wrap) {
  match node {
    ...
    case Text(str) -> text(str, str.size)
    case Unicode(str, width) -> text(str, width)
  }
}
```

We use the `text` helper method defined earlier. For the `Text` node we use
`String.size` to pass the byte size (and thus character, as `Text` is for
ASCII-only text), and for `Unicode` nodes we pass the pre-computed extended
grapheme clusters count.

#### Rendering whitespace

We render the various whitespace nodes (`Line`, `SpaceOrLine` and `Indent`) as
follows:

```inko
fn mut node(node: Node, wrap: ref Wrap) {
  match node {
    ...
    case Line if wrap.enable? -> new_line
    case SpaceOrLine if wrap.enable? -> new_line
    case SpaceOrLine -> text(' ', chars: 1)
    case Indent(nodes) if wrap.enable? -> {
      @size += INDENT.size
      @indent += 1
      @buffer.push(INDENT)
      nodes.into_iter.each(fn (n) { node(n, wrap) })
      @indent -= 1
    }
    case Indent(nodes) -> nodes.into_iter.each(fn (n) { node(n, wrap) })
    case _ -> {}
  }
}
```

For `Line` and `SpaceOrLine` we call `new_line` if wrapping is necessary. If no
wrapping is needed we ignore the `Line` node (covered by the wildcard `_`
pattern at the end), while a `SpaceOrLine` is turned into a single space by
calling the `text` helper method.

For `Indent` nodes we first increment the line size, because we start
indentation at the _current_ line, then we increment the indent _level_ (not the
number of indent characters) and add the indentation text to the current line.
We then render the child nodes, and reset the indentation level to its previous
value.

#### Converting Generator into a String

Once we're done with the `Generator` type, we want to turn the internal buffer
into a `String` we can write to a file or STDOUT. To make this easy, we'll
implement the `IntoString` trait from the `std.string` module:

```inko
impl IntoString for Generator {
  fn pub move into_string -> String {
    @buffer.into_string
  }
}
```

Given an instance of `Generator`, we can then use `Generator.into_string` to
move the `Generator` _into_ a `String`.

#### The final Generator type


Combining all this, our `Generator` type ends up looking like this:

```inko
class Generator {
  let @buffer: StringBuffer
  let @indent: Int
  let @size: Int
  let @max: Int
  let @wrapped: Set[Int]

  fn static new(max: Int) -> Generator {
    Generator {
      @buffer = StringBuffer.new,
      @indent = 0,
      @size = 0,
      @max = max,
      @wrapped = Set.new,
    }
  }

  fn mut generate(node: Node) {
    node(node, ref Wrap.Detect)
  }

  fn mut node(node: Node, wrap: ref Wrap) {
    match node {
      case Nodes(nodes) -> nodes.into_iter.each(fn (n) { node(n, wrap) })
      case Group(id, nodes) -> {
        let width = Int.sum(nodes.iter.map(fn (n) { n.width(@wrapped) }))
        let wrap = if @size + width > @max {
          @wrapped.insert(id)
          Wrap.Enable
        } else {
          Wrap.Detect
        }

        nodes.into_iter.each(fn (n) { node(n, wrap) })
      }
      case IfWrap(id, node, _) if @wrapped.contains?(id) -> {
        node(node, Wrap.Enable)
      }
      case IfWrap(_, _, node) -> node(node, wrap)
      case Text(str) -> text(str, str.size)
      case Unicode(str, width) -> text(str, width)
      case Line if wrap.enable? -> new_line
      case SpaceOrLine if wrap.enable? -> new_line
      case SpaceOrLine -> text(' ', chars: 1)
      case Indent(nodes) if wrap.enable? -> {
        @size += INDENT.size
        @indent += 1
        @buffer.push(INDENT)
        nodes.into_iter.each(fn (n) { node(n, wrap) })
        @indent -= 1
      }
      case Indent(nodes) -> nodes.into_iter.each(fn (n) { node(n, wrap) })
      case _ -> {}
    }
  }

  fn mut text(value: String, chars: Int) {
    @size += chars
    @buffer.push(value)
  }

  fn mut new_line {
    @size = INDENT.size * @indent
    @buffer.push('\n')
    @indent.times(fn (_) { @buffer.push(INDENT) })
  }
}

impl IntoString for Generator {
  fn pub move into_string -> String {
    @buffer.into_string
  }
}
```

### The Builder type

The `Builder` type is used to visit the AST and turn each AST node into its
corresponding `Node` value. This is typically where most of the complexity
resides, as it's where you'll deal with constructing your formatting rules, edge
cases, and more. For the sake of keeping things easy to understand, our
`Builder` type only supports simple function calls, string literals and regular
text literals (e.g. simple integers).

We'll start with the basic definition of this type, which is as follows:

```inko
class Builder {
  let @id: Int

  fn static new -> Builder {
    Builder { @id = 0 }
  }

  fn mut new_id -> Int {
    @id := @id + 1
  }
}
```

The `id` field is used to keep track of the next ID to use for `Group` nodes.
The `new_id` method is used to request a new ID and automatically update the
`id` field.

#### Strings

For strings, we'll define a `string` method as follows:

```inko
class Builder {
  ...
  fn mut string(value: String) -> Node {
    Node.Group(new_id, [Node.Text('"'), Node.unicode(value), Node.Text('"')])
  }
}
```

This method constructs a `Group` node that represents a double quoted string.
While the argument it takes is a regular `String` in this example, in a real
formatter this would be something along the lines of a `StringLiteral` AST node
of sorts, containing the actual string value along with extra data (e.g. the
source location).

#### Function calls

For function calls we'll define a `call` method with two argument names: the
name as a `String`, and the argument nodes as an array of `Node` values:

```inko
class Builder {
  ...
  fn mut call(name: String, arguments: Array[Node]) -> Node {
    let id = new_id

    if arguments.empty? {
      return Node.Group(id, [Node.Text(name), Node.Text('()')])
    }

    let max = arguments.size - 1
    let vals = arguments
      .into_iter
      .with_index
      .map(fn (index_and_node) {
        match index_and_node {
          case (index, node) if index < max -> {
            Node.Nodes([node, Node.Text(','), Node.SpaceOrLine])
          }
          case (_, node) -> {
            Node.Nodes([node, Node.IfWrap(id, Node.Text(','), Node.Text(''))])
          }
        }
      })
      .to_array

    Node.Group(
      id,
      [
        Node.Text(name),
        Node.Group(
          new_id,
          [
            Node.Text('('),
            Node.Line,
            Node.Indent(vals),
            Node.Line,
            Node.Text(')'),
          ],
        ),
      ],
    )
  }
}
```

We start of by requesting a new group ID, then we check if we have any arguments
to process. If not, we return a simple `Group` node that renders to `NAME()`
where `NAME` is the function name.

If we do have arguments, we turn the list of `Node` values into a comma
separated list, with a trailing comma after the last value that only shows up if
wrapping is necessary:

```inko
let max = arguments.size - 1
let vals = arguments
  .into_iter
  .with_index
  .map(fn (index_and_node) {
    match index_and_node {
      case (index, node) if index < max -> {
        Node.Nodes([node, Node.Text(','), Node.SpaceOrLine])
      }
      case (_, node) -> {
        Node.Nodes([node, Node.IfWrap(id, Node.Text(','), Node.Text(''))])
      }
    }
  })
  .to_array
```

Here we turn `arguments` _into_ an iterator over `Node` values, then we create a
new iterator using `with_index` that yields values in the form of `(index,
value)`. We do this so we know when we're processing the last value, such that
we can insert a trailing comma that only shows up when wrapping is necessary.
Inko doesn't support pattern matching in closure arguments or `let` bindings at
this stage, so we need to explicitly match the `index_and_node` tuple into its
components.

The rest is straightforward: for all but the last argument we produce a `Nodes`
that contains the value, followed by a comma and a `SpaceOrLine` node. For the
last argument we instead produce a `Node` that contains the last argument
followed by an `IfWrap`, which renders to a comma only when wrapping is
necessary.

As `map` creates a new iterator (and everything is done lazily), we need to
convert the result to an array using the `to_array` method, such that we can
store the resulting array in a `Node`.

The `Node` returned is as follows:

```inko
Node.Group(
  id,
  [
    Node.Text(name),
    Node.Group(
      new_id,
      [
        Node.Text('('),
        Node.Line,
        Node.Indent(vals),
        Node.Line,
        Node.Text(')'),
      ],
    ),
  ],
)
```

This tree ensures that the opening parenthesis always comes after the name, no
matter the formatting needs, and the closing parenthesis is placed on its own
line when wrapping is necessary. If wrapping is necessary, we place each
argument on its own line (as they are in a `Group` node), and each line is
indented. The result is that if wrapping is necessary, expressions such as this:

```inko
foo(10000000000000000, 200000000000000000, 'this is a string')
```

Will be formatted like so:

```inko
foo(
  10000000000000000,
  200000000000000000,
  'this is a string',
)
```

### Using the Generator and Builder types

With both types set up, we can use them like so:

```inko
# This creates a Generator that enforces a line length of 80 characters.
let gen = Generator.new(80)
let build = Builder.new
let node = build.call(
  'foo',
  [
    Node.Text('1000000000000000000000000000000'),
    build.call(
      'bar',
      [
        Node.Text('2000000000000000000000000000000'),
        build.string('this is a string'),
        build.call('without_arguments', []),
      ],
    ),
  ],
)

gen.generate(node)
gen.into_string
```

This produces the following output:

```inko
foo(
  1000000000000000000000000000000,
  bar(2000000000000000000000000000000, "this is a string", without_arguments()),
)
```

If we instead change the line limit to 120, the output is as follows instead:

```inko
foo(1000000000000000000000000000000, bar(2000000000000000000000000000000, "this is a string", without_arguments()))
```

And if we use a limit of 40, we get this instead:

```inko
foo(
  1000000000000000000000000000000,
  bar(
    2000000000000000000000000000000,
    "this is a string",
    without_arguments(),
  ),
)
```

## Applying this to a real formatter

While what we've discussed so far is a simplified version of a real
formatter, it's not too different from a real production code formatter. For
example, Inko's own formatter uses the same setup discussed here, it just has
some extra nodes to handle specific formatting needs, and has to handle things
such as rendering string escape sequences in their literal form (i.e. `\n` is
rendered as a literal `\n` and not an actual newline), and whatever formatting
edge cases present themselves based on the formatting rules.

To put it differently, the setup discussed here gets you about 80% of the way,
while the remaining 20% is spent handling edge cases based on your formatting
needs. In case of Inko, I probably spent a week or two writing the initial
formatter, followed by another two to three weeks of dealing with unexpected
edge cases and careful tweaking of the output.

The final version of the code shown in this article, along with plenty of
comments to help understand the code better, is found in
[this Git repository](https://github.com/yorickpeterse/code-formatting-in-inko),
which you can easily run by either
[installing Inko](https://docs.inko-lang.org/manual/main/setup/installation/)
or by using Docker/Podman. If you want a more advanced example, consider taking
a look at [the code used by Inko's own formatter][inko-fmt].

::: info
The code examples and the linked repository require the use of Inko's `main`
branch, as the code depends on some changes that have yet to be released. Refer
to the repository's README for more details.
:::

If you'd like to learn more about the various aspects of building programming
languages, or you're interested in learning more about Inko, please consider
[sponsoring my work through GitHub
Sponsors](https://github.com/sponsors/yorickpeterse), join [Inko's Discord
server](https://discord.gg/seeURxHxCb) or [Matrix
channel](https://matrix.to/#/#inko-lang:matrix.org) (bridged to the Discord
server), or subscribe to the [/r/inko subreddit](https://www.reddit.com/r/inko/).

[^1]: In typical Ruby fashion, the community is seemingly unable to agree on a
    consistent code formatter to use, so it's not entirely clear how many
    actually use these formatters. [RuboCop](https://github.com/rubocop/rubocop)
    _is_ widely used, but it's a _linter_ and not just a style formatter.
[^2]: Yes, I'm advertising my own work. Bite me.
[inko]: https://inko-lang.org/
[prettier]: https://prettier.io/
[inko-fmt]: https://github.com/inko-lang/inko/blob/a78397961c5f1f08c17309b93859ec9b65af82b4/compiler/src/format.rs
