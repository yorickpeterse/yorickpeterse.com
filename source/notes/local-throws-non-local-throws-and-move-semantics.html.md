---
title: Local throws, non-local throws, and move semantics
date: 2020-07-18 14:20:24 UTC
---

In [Inko escape analysis for closures](/notes/inko-escape-analysis-for-closures)
I wrote some notes about using some for of escape analysis for closures.

One way of dealing with `throw` in methods and closures is to break it up into
two keywords: `throw` acts like `return`, and throws from the surrounding
method. Closures that use `throw` can't survive their surrounding scope,
enforced using some for of escape analysis. The same rules apply to using
`return`. When using `throw`, the throw type of the surrounding closure is not
inferred according to the thrown value. For example:

```inko
{ throw 10 }
```

Here the surrounding closure won't have its throw type inferred, because we
throw from the surrounding scope; not the closure.

To perform a local throw (= from the closure), a new keyword would be
introduced. For the lack of a better name, let's call this `local throw` for
now:

```inko
{ local throw 10 }
```

Here the throw type of the closure is inferred as `Integer`, because we throw
from the closure; not the surrounding scope.

Using this setup, we can use `throw` in closures all we want; as long as this
happens somewhere in a method. If we still want to store a closure that throws
somewhere, we use `local throw` instead. Since the majority of throws will be
from surrounding methods, we don't need to annotate a lot of closures or
lambdas. This can also be extended to returns, adding a `local return` to allow
explicit returns from a closure.

This doesn't solve the issue of non-local closures escaping their environment.
We could mark non-local closures as such, and make them incompatible with
closures that are local. But this will prevent passing non-local closures to
arguments that expect local ones, effectively making it impossible to use
`throw` in closures. So again, we'd need some form of escape analysis to
determine if a closure escapes its environment.

A system of lifetimes like in Rust may help. With such a system, we could infer
the lifetime of a throwing closure to be equal to that of its surrounding
environment. Imagine we use the syntax `A ~ B` meaning that the lifetime of `A`
is `B`, we would end up with something like this:

```inko
def foo ~ a {
  { throw 10 } # Here the type would be `do ~ a -> Never`
}
```

Here we specify that `a` is the lifetime of `foo`. That is, any `a` lives until
we return from `foo`. When storing closures, we'd then have to somehow specify
the lifetime of the closure must be at least that of the container it's stored
in. If that lifetime outlives the surrounding scope, the compiler would catch
this and produce an error.

But introducing lifetimes is a big undertaking, and doesn't work well without
also introducing reference types and possibly even move semantics. We would also
have to make `self` explicit in the arguments list, so we can specify that the
lifetime of one value is tied to the lifetime of `self`:

```inko
impl Array!(T) {
  def push(self ~ a, value: T ~ a) -> T ~ a {
    ...
  }
}
```

Here we say that `a` lives at least as long as `self`, and `T` at least as long
as `a`. In other words, the value `T` must live at least as long as the Array
it's stored in.

Specifying lifetimes manually becomes a chore, so ideally we infer as much as
possible. But this will complicate type-inference. It will also introduce the
limitations seen in Rust, such as recursive data-structures being difficult to
implement.

Lifetimes may not be needed. Instead, we introduce references and move
semantics. In this setup, methods such as `if_true` specify that they expect a
closure _reference_:

```inko
def if_true!(R)(block: ref do -> R) -> ?R {
  _INKOC.if(self, block.call, Nil)
}
```

Here `ref` is used to specify that `block` is a reference to a `do -> R`. Since
Inko is still garbage collected, "references" are more about ownership and less
about passing pointers opposed to passing values directly. If we leave out the
`ref`, the value is moved. A closure that uses `throw` or `return` is tied to
its surrounding scope, and thus can't be moved out of it. Thus, this is not
valid:

```inko
def foo -> do {
  { throw 10 }
}
```

Here the return type is `do`, meaning we move the closure to whatever the return
value is assigned to. But the closure uses `throw`, thus depends on its
surrounding scope, thus can't be moved out of it.

Encoding ownership into the type-system in some way also makes it more safe to
deal with resources that can be closed. Consider this example:

```inko
import std::fs::file

let handle = try! file.write_only('/tmp/test.txt')

try! handle.write_string('hello')

handle.close

try! handle.write_string('world')
```

Closing files is implemented by dropping the underlying Rust File structure, as
that's the only way you can close a File in Rust. This results in the second
`write_string` panicking, as it's operating on something that is no longer a
file. Using ownership, we may define `close` like so:

```inko
def close(self) {
  _INKOC.drop_value(self)
}
```

Here making `self` explicit would translate to moving `self` into `close`. This
would then make `handle` unavailable after the `handle.close` line. This does
introduce an inconsistency: when borrowing `self` it would be an implicit
argument, but when moving it would have to be explicit. This would require the
compiler to ignore `self` when defining arguments, since `self` is _not_ an
actual argument.

Here is the issue though: introducing move semantics without lifetimes may not
be possible. Lifetimes are complex, and they result in leaky abstractions; at
least in Rust. That is, if type A contains type B, which contains type C, then
adding a lifetime annotation to C also requires updating B and A. Using clever
lifetime inference you may reduce the amount of cases, but it's unlikely you can
infer everything.

We could decide that instance attributes must have their values moved, thus not
allowing references to be stored in types. That is, this would not be valid:

```inko
let thing1 = Thing.new
let thing2 = Thing.new
let things = Array.new(ref thing1, ref thing2)
```

Similarly, primitive operations such as `_INKOC.array_set` would require an
owning value. This does make recursive data structures impossible, as type A
could not refer to itself through another type. An example of such a type is a
doubly-linked list, which would be impossible to implement if we don't allow
references in types.

Since Inko does have a GC, _technically_ it's memory-safe to store a reference
in a struct, even when the value pointed to is moved. But if the type has a
destructor, we may not be able to use it in any meaningful way.

Move semantics would also make it possible to introduce deterministic
destructors. This in turn may remove the need for `defer`, if the compiler can
ensure they run when using `throw` or `return`.

With move semantics we'd also get escape analysis for free.

Handling move semantics with loops gets tricky:

```inko
def foo(thing: Thing) {}

let thing = Thing.new

{
  foo(thing)
}.loop
```

This code should not compile, as `thing` is moved after the first iteration.
This requires that the compiler knows `loop` calls its receiver indefinitely.
And what about code such as this:

```inko
def foo(thing: Thing) {}

let thing = Thing.new

Array.new(10, 20, 30).each do (number) {
  foo(thing)
}
```

How would the compiler know that `each` calls its block several times? And what
about other methods that take a closure? One option is to not allow captured
variables to be moved. But the heavy reliance on closures may result in such a
setup not being pleasant. Consider this example:

```inko
def foo(things: ref mut Array!(Thing)) {
  let thing = Thing.new

  some_condition.if_true { things.push(thing) }
}
```

If closures can't move values, then we would not be able to write this code. We
could bypass this using pattern-matching, but this is clunky:

```inko
def foo(things: ref mut Array!(Thing)) {
  let thing = Thing.new

  match {
    some_condition -> { things.push(thing) }
    else -> {}
  }
}
```

In short, move semantics and/or lifetimes complicate both the compiler and
language. But they also bring benefits, perhaps even the possibility of removing
the garbage collector in favour of compiler-driven memory management.

Backpointers could be handled using weak references. For example, a
doubly-linked list may look like this:

```inko
object Node!(T) {
  @next: ?Node!(T)
  @previous: weak ?Node!(T)
  @data: T
}
```

Here `weak` indicates that `@previous` does not store a `?Node!(T)` directly,
but a weak reference. If the data pointed to is released, the weak reference
would be invalidated somehow. This does bring a question: does it make sense to
have a weak reference to an optional type? This means there are three cases to
deal with:

1. The value is `Nil`
1. The value is present
1. The value is released/invalid

We could simplify this by turning a `weak T` into essentially a `?T`, where
releasing `T` sets the `?T` to `Nil`. Weak values are basically optional values
anyway.

For this to work, a value `T` needs to store a singleton weak reference
in itself. When we create a weak reference, we just read this singleton and
store it in a register. In other words, given a `T` there is only a single `weak
T` instance. This way when releasing `T`, we can also update the `weak T`. This
requires an extra 8 bytes per heap-allocated object.

Tail-call elimination complicates ownership and releasing of memory.

We could do the following:

1. Calling a closure consumes it
1. Calling a closure reference multiple times is fine
1. Methods such as `if_true` take a closure by reference
1. A closure containing a `throw` or `return` is a moving closure
1. Passing a moving closure to a closure reference is OK

This way you can pass a closure that uses `return` or `throw` to methods such as
`if_true`, `each`, etc. But this does not handle closures called multiple times,
while moving a variable. The only way this is safe is if methods such as `each`
don't allow moving closures. But this then doesn't allow `throw` and `return`.

Another option: a closure that uses `return` or `throw` does not move, instead
it's marked as "non-local". A non-local closure is compatible with closure
references, but not moving closures. You also can't return a non-local closure
as a reference. Since you can never return a non-local closure or store it,
there is no syntax for them. An example:

```inko
impl Conditional for Boolean {
  def if_true!(R)(block: ref do -> R) -> ?R {
    _INKOC.if(self, block.call, Nil)
  }
}

def this_is_valid -> Integer {
  condition.if_true { return 10 }
}

def this_is_not_valid -> do -> Integer {
  { return 10 }
}
```

Here the last method is not valid for two reasons:

1. `return` is validated against the method's return type, and `Integer` is not
   compatible with `do -> Integer`.
2. The closure is non-local, and non-local closures can't be moved.

This code also wouldn't be valid:

```inko
def this_is_not_valid -> ref do -> Integer {
  { return 10 }
}
```

Since the closure depends on the lifetime of its surrounding scope, it can't be
returned as a reference.

But what about this:

```inko
def repeat(block: ref do) {
  block.call
  block.call
}

def consume(thing: Thing) {}

let thing = Thing.new

repeat { consume(thing) }
```

If we can pass a moving closure to a closure reference, this code would be
unsound. We can disallow this, but then methods such as `if_true` must move
their argument. But a closure using `throw` can't be moved, so now what?

A closure that uses `throw` or `return` on its own has nothing to do with move
semantics, instead it's about lifetimes. Specifically, such a closure's lifetime
can not exceed that of the method it's defined in.

This comes down to the following: to make Inko's error handling sound, we need a
way of differentiating between a closure that sticks around until the
surrounding method returns, and a closure that sticks around for longer than
that. As a method author you often won't care about this, all you care about is
that the closure outlives the method call. We also need a way of indicating if a
closure is called more than once.

Shared ownership is not much of a problem in Inko. Because processes don't share
memory, shared ownership can't introduce data races. A `shared T` would be an
immutable reference counted `T`. Borrowing it produces a `ref shared T`. Thus
`shared` is more about how we keep track of the lifetime of `T`, and less about
the type of reference. A `ref mut shared T` would be a mutable reference to a
`shared T`. The use of `shared` will probably be limited to data-structures such
as doubly-linked lists, like so:

```inko
object Node!(T) {
  @next: Node!(T)
  @previous: shared Node!(T)
  @data: T
}
```

This does bring the question: when would the reference count be increased?
Moving doesn't require doing so, nor do references. We'd need some sort of
`clone()` method like Rust. But if a `shared T` uses the same memory
representation as a `T`, this won't work. We could introduce a `clone` keyword.
Or, `shared` could be a proper object called `Shared`, with a `clone` method.
This means we'd end up with something like this:

```inko
object Shared!(T) {
  @data: ...

  def clone -> Shared!(T) {
    _INKOC.increase_ref_count(@data)
    Shared.new(@data)
  }
}

object Node!(T) {
  @next: Node!(T)
  @previous: Shared!(Node!(T))
  @data: T
}
```

This does raise the question what the type of `@data` would be. We'd need
to introduce some sort of unsafe/raw reference for this. At this point I think
Inko becomes a bit too much like a systems language; or at least a language that
isn't sure what it wants to be.

Also where would we store the reference count? If we do it like Rust, we need
two types: something for the inner data, and something for the "references". But
that inner data would own the data, preventing other types from also owning it.

If we keep the garbage collector, `shared T` would be something that only exists
at the compiler-level. There's no need to perform any reference counting, and
since we use a tracing collector the `T` would not be dropped either. But
keeping a collector makes little sense when we have ownership, as the GC would
virtually never run. Also, the GC would need a way to call destructors, and I
don't want the VM to have knowledge of what methods it would need to call for
that.

Setting this all aside, perhaps introducing an ownership/moving system changes
Inko too much. For one, lot's of code has to be changed. We'd also need a way to
handle shared ownership, and handling (non-local) closures would still pose a
problem. Escape analysis would be simpler, if we stick with a naive scheme where
storing value A in B means it escapes, even if B doesn't. For closures this
should be fine, as storing non-local closures is rare; if it ever happens at
all. For other values we may at worst allocate them on the heap when this is not
necessary, but that's something that could be improve upon over time.
