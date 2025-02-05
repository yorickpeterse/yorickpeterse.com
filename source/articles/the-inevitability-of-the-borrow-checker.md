---
{
  "title": "The inevitability of the borrow checker",
  "date": "2025-02-05T00:00:00Z"
}
---

When defining a type in [Inko](https://inko-lang.org/), it's allocated on the
heap by default. For example (using the syntax for the upcoming 0.18.0 release):

```inko
type User {
  let @id: Int
  let @username: String
  let @email: String
}

User(id: 42, username: 'Alice', email: 'alice@example.com')
```

Here `User` is a heap allocated type, and the expression `User(...)` allocates
an instance of this type using the system allocator (i.e. `malloc()`).
Defaulting allocations to the heap gives you a lot of flexibility, such as being
able to move a value around while it's borrowed:

```inko
let a = User(id: 42, username: 'Alice', email: 'alice@example.com')
let b = ref a # This creates an immutable borrow
let c = a     # This just moves the pointer, so the `b` borrow is still valid

b.username # => 'Alice'
```

Borrowing in turn uses a form of reference counting: each heap type stores a
"borrow count" which defaults to zero. When creating a borrow the counter is
incremented, and when disposing of a borrow it's decremented. When an owned
value is about to be dropped, we check if the borrow count is zero. If not, a
runtime error (which you can't catch) is produced, known as a panic.

The trade-off is that heap allocating type incurs a cost. Not just for the
allocation itself, but also due to the pointer chasing heap allocated types may
introduce, and the potential inability to optimize code as well as stack
allocated types. Heap types also need to store the borrow counter and a pointer
to their method table (to support dynamic dispatch), resulting in each heap type
requiring at least 16 bytes of memory.

The last few weeks I've been working on adding support for defining stack
allocated/inline types. Defining such a type is done by using the `inline`
modifier:

```inko
type inline User {
  let @id: Int
  let @username: String
  let @email: String
}

# The instance is now allocated on the stack.
User(id: 42, username: 'Alice', email: 'alice@example.com')
```

These types can contain both heap allocated types and other inline types. Like
heap types, inline types are subject to move semantics and single ownership:

```inko
type inline User {
  let @id: Int
  let @username: String
  let @email: String
}

let a = User(id: 42, username: 'Alice', email: 'alice@example.com')
let b = a

a.username # This produces a compile-time error because `a` is moved into `b`
```

What happens if we borrow an inline type and move it while the borrow still
exists? Let's find out:

```inko
let a = User(id: 42, username: 'Alice', email: 'alice@example.com')
let b = ref a
let c = a

b.username # => 'Alice'
c.username # => 'Alice'
```

Instead of producing a compile-time or runtime error, the program compiles and
runs without issue. What if we assign `a` a new value instead of moving it into
a new variable?

```inko
let mut a = User(id: 42, username: 'Alice', email: 'alice@example.com')
let b = ref a

a = User(id: 10, username: 'Bob', email: 'bob@example.com')

a.username # => 'Bob'
b.username # => 'Alice'
```

"What is this black magic?" you might wonder. The answer is simple: when
borrowing an inline type, the value is _copied_. If the inline type contains any
heap values (e.g. an `Array` of sorts) those values are then borrowed
individually. This ensures that the borrow remains valid at all times, and
prevents us from prematurely dropping any heap types stored in an inline type.
The idea is inspired by how Swift supports structs (which go on the stack) in
addition to classes (which go on the heap and use reference counting).

Inline types come with their own limitations that mean they aren't always the
right choice. First, if an inline type defines 10 fields that contain heap types
then borrowing the inline type requires 10 borrow count increments (one for each
field). This means it's best to keep the number of fields containing heap types
to a minimum. Second, fields of inline types can't be assigned new values,
though they can still contain mutable values (e.g. a mutable borrow to an
array).

That second limitation is enforced to prevent surprising and difficult to debug
behavior: due to borrows _copying_ the data, assigning fields new values only
affects whatever reference is used as the receiver of the assignment. Consider
this example:

```inko
type inline User {
  let @id: Int
  let @email: String
}
```

Now imagine that somewhere in our code we have a `User` stored in some variable
`user` and we want to update its Email address, so we do just that:

```inko
user.email = 'foo'
```

Somewhere else we have another borrow (or we use the owned reference) to the
same `User`, and we expect the Email address to be "foo". If we allow fields to
be assigned new values, this won't necessarily be the case. For example, when
performing the assignment using a borrow, only that borrow will use the new
value. Or to be more precise: any aliases created _before_ the assignment will
observe the old value, only aliases created _after_ the assignment will observe
the new value.

This behaviour is terribly confusing, especially considering it can be
introduced in non-obvious ways (e.g. through generic code). For this reason
the compiler doesn't allow fields of inline types to be assigned new values in
the first place.

Unfortunately, this means that inline types aren't suitable for cases where you
_do_ want to assign fields new values but _don't_ want to pay the cost that
comes with heap types. Iterators are a good example of such a case: they often
need to assign fields new values (e.g. to advance the index into an array), and
by stack allocating them we might be able to optimize them such that (in the
best case) they add no extra overhead compared to a regular `for` loop of sorts.

So what can we do about this? Well, there are a few options I looked into. Let's
take a look!

## Allow field assignments anyway

The first potential approach is to just allow fields to be assigned new values,
combined with _trying_ to borrow by pointer instead of by copy where possible.
Swift does something similar when using `mutating` methods. Unfortunately, this
approach poses several problems:

1. Depending on the code in question, we might still need to copy data to uphold
   Inko's memory safety guarantees. This means there are still cases where an
   assignment won't be observed by other aliases.
1. Given borrows such as `mut SomeInlineType` the type can now mean one of two
   things: an inline _value_, or a pointer to such a value, based on the context
   it's used in (e.g. borrows of inline types used as arguments would be
   pointers). This is needed so we can transparently handle both.
1. To support all this we'd need to introduce a rather complicated "copy on
   move" scheme: borrowing inline data would produce a pointer, but when
   capturing such a pointer (e.g. as part of an assignment or return) we'd
   dereference the pointer and create a copy of the underlying data.

That first problem is worth highlighting a bit more. Consider this example:

```inko
type Heap {
  let @inline: Inline
}

type inline Inline {
  let @number: Int

  fn mut update(heap: mut Heap, number: Int) {
    @number = number
    heap.inline = Inline(100)
  }
}

let heap = Heap(Inline(10))

heap.inline.update(mut heap, 200)
```

If we want `heap.inline.update` to be able to mutate `heap.inline` in-place such
that any field assignments apply to all aliases, then we must pass `heap.inline`
by pointer to `update`. This can then result in memory safety issues, such as by
assigning the `inline` field a new value before returning from the `update`
method as shown above. While in this particular contrived example it won't
result in a crash, the resulting behaviour is effectively undefined: it could
crash, continue running, or eat your laundry.

Swift's approach appears to be a combination of compile-time and [runtime
checks](https://www.swift.org/blog/swift-5-exclusivity/). While this might work,
I'm not a fan of using runtime checks for cases like this due to the potential
overhead, and that debugging such issues will likely be a frustrating
experience.

So would this be possible to support? Sure, if the combination of compile-time
and runtime checks and significant compiler complexity isn't a problem. I'm
_not_ a fan of that, so let's see what other options we have.

## Introduce unique types

The second option is to _not_ allow inline types to be assigned new values and
keep them as-is. Next, we'd introduce _unique_ types. A unique type is a type
for which only a single reference exists. In the context of Inko and its use of
single ownership, that reference would be an owned reference. Because there's
only a single reference, field assignments are always observed as expected.

I experimented with this on the
[experimental/unique-types](https://github.com/inko-lang/inko/tree/experiment/unique-types)
branch, but similar to the previous option I don't think it's a suitable
solution. The core problem with unique types is also what makes them, well,
unique: the fact that you can only have a single reference.

First, composition becomes more difficult when you introduce unique types into
the mix. Consider the following contrived example of a buffered writer type:

```inko
type BufferedWriter[T: Write] {
  let @inner: T
  ...
}
```

The exact implementation of the type doesn't matter. What matters is that the
`inner` field can be of any type that implements the `Write` trait, and that
type can either be owned or a borrow as type parameters in Inko are generic over
both type and ownership. Now imagine that we try to use it like so:

```inko
let file = File.new(...) # imagine that File is a unique type
let writer = BufferedWriter.new(file)

...
```

This would _move_ `file` into the `BufferedWriter`. So far so good, because that
doesn't create any additional aliases to the unique `File`. But what if we're
done with the `BufferedWriter` and want our owned `File` back? We'd have to move
it _out_ of the `BufferedWriter`, which we can do using pattern matching:

```inko
let file = match writer {
  case { @inner = file } -> file
}

# Now we can use `file` again
```

Except there's a problem: we can only move fields out of types that _don't_
define a custom destructor, otherwise running the destructor would be unsound.
This means that whether this pattern works or not varies per type. For example,
Inko's standard library provides such a `BufferedWriter` type and it defines a
destructor, meaning we can't apply the above pattern. Damn it!

Another approach would be _not_ to move `file` into the `BufferedWriter` but
instead borrow it, but we can't do that if `File` is a unique type because it
would introduce an alias, and unique types don't allow aliasing.

We _could_ allow borrowing of unique types but in such a way that the borrows
can never outlive the data they borrow. The most basic form of this is to
disallow such borrows to be assigned to variables, to be stored (e.g. in a
field), to be captured by closures, or to be returned. Inko already implements
this to some degree to allow [borrowing of unique _values_](https://docs.inko-lang.org/manual/latest/getting-started/concurrency/#borrowing-unique-values).
Unfortunately, for examples such as the above this isn't enough because we'd
need the ability to store borrows in the `BufferedWriter` type.

Now imagine that I have a magic wand that I can wave to make these problems go
away, we still have another problem: closures. More specifically, closures in
default trait methods. Consider this example:

```inko
trait Example {
  fn update_in_place

  fn return_closure -> fn {
    fn { update_in_place }
  }
}
```

Here we have a trait `Example` that defines the required method
`update_in_place` and the default method `return_closure` that returns a
closure. The closure calls `update_in_place` on `self` (`self` is implicit in
Inko) and thus needs to capture `self`. If we implement this trait for a unique
type then calling `return_closure` on instances of that type results in an
alias, violating the no aliasing rule.

To make this sound, we'd have to disallow closures in default trait methods and
methods defined for unique types to capture `self`. This greatly diminishes the
value of default trait methods given that Inko makes heavy use of closures, and
can make defining unique types a frustrating experience.

Oh, and we still have the problem of being able to invalidate borrows through
field assignments as shown in the `update` example earlier.

I could list more problems that unique types may introduce, but the problem can
be summed up as follows: unique types don't compose well and have a profound
(and not necessarily positive) impact on the type system, such that even if you
don't care about unique types your code is still affected by them in some way.

## Use escape analysis to replace heap allocations

Instead of extending the type system, we could keep things as-is and introduce
some form of escape analysis and use that to stack allocate heap types where
possible. On the surface this seems like the best of both worlds: you get
maximum flexibility, and through the power of science the compiler will
magically make everything fast. Right? Well, maybe not.

Having spent the last few weeks [looking into
this](https://github.com/inko-lang/inko/issues/776) as a possible solution, I
don't think it will be enough. The problem is that escape analysis is a
conservative form of analysis, meaning it won't be able to stack allocate types
in certain cases even if this should be fine. For example, when passing
arguments to a method called through dynamic dispatch, the compiler might not be
able to determine if those arguments outlive the call and thus has to assume
that they escape, otherwise the compiler might generate incorrect code.

Based on various papers from the last 30 years or so, it appears that in most
cases stack allocation is only able to stack allocate a small percentage of heap
allocations, with the occasional outlier. Since most papers focus on specific
benchmarks, I suspect the actual percentage to be lower for real applications,
though this likely varies greatly based on what the application does.

Inko's use of single ownership and move semantics might make it easier to detect
whether values escape or not, though thus far I've had a difficult time trying
to figure out how to actually implement escape analysis.

Even then, I suspect that for most applications the percentage of heap
allocations that can be turned into stack allocations will be less than 30% or
so. While that would certainly be a nice improvement, it's difficult to say if
it will be enough. The effectiveness of escape analysis also depends on
how much code is inlined, meaning that small code changes can have a significant
impact on how many heap allocations can be replaced with stack allocations.

## Compile-time borrow checking

If we don't want runtime checks and we want something that is both sound and
sufficiently powerful, I think the only approach is to rely on compile-time
borrow checking. This could be an approach as found in
[Rust](https://www.rust-lang.org/), or something as found in
[Austral](https://austral-lang.org/). I experimented with an approach similar to
Austral where borrows are explicitly scoped. For example, the `BufferedWriter`
example would look something like this:

```inko
let file = File.new(...) # imagine that File is a unique type

borrow mut file {
  let writer = BufferedWriter.new(file)
}
```

Here `borrow mut` is an expression that would mutably borrow `file`, shadowing
it inside the scope as a borrow. The compiler would then ensure that borrows
can't escape the `borrow` scope, either as a return value or by writing them to
values defined outside the `borrow` scope. This would (more or less) be
implemented by assigning a borrow scope ID to each scope and then storing this
as part of the type. So instead of `ref SomeUser` the type would be something
along the lines of `ref(N) SomeUser` where `N` is such a generated scope ID.
To prevent borrows from escaping, when checking type A against type B the
compiler would reject the comparison if the borrow scope ID of A is greater than
(= nested more deeply) that of B. The end result is that it would be possible to
pass borrows _down_ the call stack, but never up beyond a `borrow` scope.

Unfortunately, this approach poses problems such as it being unclear how a
method would be able to return a borrow. After all, if we need to create a
borrow scope and can't return borrows from it, how would we return a borrow to a
caller?

As far as I know, implementing any sort of borrow checker that is sound would
require some form of explicit lifetime/region annotations to aid the compiler.
This in turn means you'll end up running into similar issues as Rust, such as
lifetimes on types leaking all over the code making it more difficult to
refactor such types. Even if you manage to solve that problem, the resulting
implementation is likely to be complex and a source of bugs.

So what does this mean for Inko? Well, at the time of writing I'm not sure. I
think the presence of a borrow checker at some point is inevitable, unless I can
somehow increase the size of my brain dramatically overnight and come up with a
better alternative. At the same time I would like to avoid introducing a borrow
checker, because either it will be simple and not powerful enough or it will be
complex and a nightmare to maintain.

Until then, I think we'll stick with not allowing field assignments for inline
types and perhaps reinvestigate some old ideas such as [using a custom bump
allocator](https://github.com/inko-lang/inko/issues/776#issuecomment-2457805725).
