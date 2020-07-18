---
title: Inko escape analysis for closures
date: 2020-07-17 00:18:46 UTC
---

Inko will need escape analysis for two reasons:

1. So we can (one day) stack-allocate objects that don't escape.
1. So we can determine if a non-local closure escapes its environment.

A non-local closure is a closure that contains a `return` or a `throw`. These
closures can't outlive their scope, as calling them would result in
undefined/funny behaviour. For example:

```inko
# We have to use `Any` here, otherwise the compiler will complain about either:
#
# 1. Returning a closure when the return type is inferred as `Nil`
# 2. The `return` expression not being compatible with the method's return type.
def foo -> Any {
  { return }
}
```

Closures that throw are compatible with those that don't, otherwise we would not
be able to write code like this:

```inko
some_condition.if_true { throw 10 }
```

But this creates a problem when we return a closure that throws, but don't
include this information in a type signature:

```inko
def foo -> do {
  { throw 10 }
}

foo.call # this is unsound as the error is not handled.
```

Admittedly this case is rare. A more common pattern is to store a closure in a
collection that does not handle errors:

```inko
let list: Array!(do) = Array.new

list.push({ throw 10 })
list.pop.call # this is unsound, again as the error is not handled.
```

Making a `do !! T` incompatible with a `do` means a lot of closures have to be
annotated. Worse, authors of methods may not be able to decide if their closure
arguments can throw or not. Leaving this up to the user of the methods means
they have to be generic, like so:

```inko
def some_method!(E)(block: do !! E) !! E -> Something {
  ...
}
```

Code such as this gets verbose fast, and is something Inko should avoid.

Escape analysis allows us to work around this. A `do !! T` is still compatible
with a `do`, removing the need for annotations all over the place. Non-local
closures in turn would not be allowed to escape, preventing the issues discussed
above. This means the following methods would all fail to compile:

```inko
def foo -> Any {
  { return }
}

def bar !! Integer -> do !! Integer {
  { throw 10 }
}

def baz !! Integer {
  SOME_ARRAY_SOMEWHERE.push({ throw 10 })
}
```

In case a closure throws and is pushed into a collection that _does_ expect an
error, it should be fine. That is, this is OK:

```inko
let blocks: Array!(do !! Integer) = Array.new

blocks.push({ throw 10 })
```

But this is not:

```inko
let blocks: Array!(do) = Array.new

blocks.push({ throw 10 })
```

This means the rules/order of checking is more or less:

1. Check if a closure/lambda escapes its surrounding scope.
1. If so, check if the argument/value/whatever we pass the closure to expects a
   closure that throws.
1. If the expected type does not specify a throw type, produce a compiler error.

## When does a value escape

A value escapes when:

1. It's returned
1. It's thrown
1. It's stored in an instance attribute of an escaping type
1. It's stored in an escaping type using a primitive operation, such as SetArray

This requires that every type stores a "escapes" boolean, defaulting to false.
This boolean is then modified according to the above steps.

```inko
def foo(values: Array!(Float)) {
  values.push(10.5) # `10.5` escapes
}

let FOO = Array.new

object A {
  def foo {
    FOO.push(self) # `self` escapes
  }
}

def foo {
  let a = A.new

  a.foo # `a` escapes
}
```

The second example may prove difficult to handle. For this to work we need to
record per method if it causes its receiver to escape.

Primitives must somehow be handled through compiler knowledge:

```inko
impl SetIndex!(Integer, T) for Array {
  def []=(index: Integer, value: T) -> T {
    _INKOC.array_set(self, index, value)
  }
}
```

Here the compiler would know that the third argument of `_INKOC.array_set`
(`value`) is stored in the first argument (`self`). A simple way is to say
"value is stored in self, so value escapes". Thus any value passed as the
`value:` argument also escapes. But this may not always be the case. For
example:

```inko
def foo {
  let numbers = Array.new

  numbers[0] = 10.5
}
```

Here `10.5` doesn't escape `foo`, because the container its stored in
(`numbers`) also doesn't escape `foo`. If we want to accurately handle this,
somehow the compiler must know that the `value` argument only escapes if `self`
also escapes.

Probably an easier way is to just assume `value` escapes, even if it doesn't.
After all, it's better to allocate onto the heap when this may not be necessary,
compared to allocating on the stack when this may break. For most cases this is
probably good enough.

Relying on escape analysis may not always produce reliable or expected results.
Take this for example:

```inko
def foo -> do !! Integer {
  { throw 10 }
}

let x = foo
```

Here it's fine for the closure to escape the scope of `foo`, as the type of `x`
is inferred to `do !! Integer`. Thus calling this closure would require
something like this:

```inko
try x.call else ...
```

Similarly, this is totally fine:

```inko
def foo -> do !! Integer {
  { throw 10 }
}

let blocks: Array!(do !! Integer) = Array.new(foo)

try blocks.pop.call else ...
```

Then there is the issue of `throw` acting a bit like a local and non-local
operation. Take this for example:

```inko
some_condition.if_true { throw 10 }
```

Here `throw` throws/unwinds from the closure, which in turn results in unwinding
from `if_true`. Sticking with the rules that throwing requires a matching `try`,
this would thus require:

```inko
try some_condition.if_true { throw 10 }
```

But this can result in verbose code, as throwing from closures will be common.
For this reason we don't require this at the moment, and only allow this code in
a method (a top-level `throw` is not valid). This makes it difficult to
implement a consistent set of rules.
