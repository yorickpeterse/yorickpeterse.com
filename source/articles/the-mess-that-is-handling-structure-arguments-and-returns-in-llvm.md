---
{
  "title": "The mess that is handling structure arguments and returns in LLVM",
  "date": "2025-01-16T00:00:00Z"
}
---

A feature scheduled to be released in [Inko](https://inko-lang.org/) 0.18.0 is
the ability to define types to allocate on the stack instead of on the heap:

```inko
# Instances of this type are heap allocated.
type User {
  let @name: String
}

# This goes on the stack instead due to the use of the `inline` keyword.
type inline User {
  let @name: String
}
```

This also meant adding support for passing such values as arguments, capturing
them in closures, and returning them. This turned out to be a lot more
complicated than anticipated, as the way LLVM handles structure arguments and
returns in regards to the system
[ABI](https://en.wikipedia.org/wiki/Application_binary_interface) is surprising
at best, and downright terrible at worst. Let's take a look at why that is.

## [Table of contents]{toc-ignore}

::: toc
:::

## What is an ABI?

Within the context of this article, "ABI" refers to the system ABI (Application
Binary Interface). In essence, the ABI is a specification that states how values
should be passed around (i.e. what registers to place the data in), how
to call functions, who (the caller or callee) is supposed to clean up certain
registers when returning from a function, and so on.

Two examples of an ABI are the [SystemV AMD64
ABI](https://gitlab.com/x86-psABIs/x86-64-ABI) and the [ARM
ABI](https://github.com/ARM-software/abi-aa/tree/main) (well technically there
are many ARM ABIs, but you get the point).

One important aspect is that in spite of CPUs not having a notion of
structures or arrays (typically referred to as "aggregate" types in ABI
specifications), ABIs still specify how one should pass them around to ensure
consistency across platforms and compilers.

At least, that's what _should_ be happening, but as you can probably guess from
the title of this article that's not quite the case.

## What did LLVM (not) do this time?

LLVM supports aggregate types such as structures, arrays, and vectors (the SIMD
kind of vector), on top of its various scalar types such as integers and
floats. The syntax LLVM's textual IR uses for structures is the following:

```
{ type1, type2, ... }
```

For example, take this Rust structure:

```rust
struct Example {
  a: i64,
  b: i32,
  c: f64,
}
```

This would be expressed in LLVM as follows (LLVM uses `double` for 64-bits
floats instead of `f64`):

```
{ i64, i32, double }
```

With that in mind, one might think that returning a structure in a function is
as simple as something along the lines of the following:

```
define { i64, i32, double } @example() {
  %1 = alloca { i64, i32, double }, align 8
  ...
  ret { i64, i32, double } %1
}
```

Similarly, it would make sense that if you want to accept a structure as an
argument you'd do that as follows:

```
define @example({ i64, i32, double } %0) {
  ...
}
```

Surely it's that easy right. RIGHT?

![A four panel internet meme about Anakin and Padme](/images/the-mess-that-is-handling-structure-arguments-and-returns-in-llvm/llvm_abi.jpg)

Unfortunately, it's not the case because that would just make too much sense.
The problem comes down to the following: while LLVM supports aggregate types, it
doesn't make any attempt to lower them down to machine code that's compliant
with the target ABI. This means that it _might_ work for simple structures and
depending on the ABI of whatever target you're compiling for, or it might fail
in a mysterious and difficult to debug manner.

Instead of LLVM handling this, it's up to each frontend to generate the correct
IR for the target ABI. This is difficult to get right as the ABI specifications
aren't always clear, and thus it shouldn't come as a surprise that one gets this
wrong. Here are just a few examples I found when implementing stack allocated
types for Inko:

- [OpenSmalltalk not generating the correct code for AMD64](https://github.com/OpenSmalltalk/opensmalltalk-vm/issues/443)
- [Dotnet not generating the correct ARM64 code](https://github.com/dotnet/runtime/issues/5853)
- [Zig not generating the correct code for structure returns on MIPS](https://github.com/ziglang/zig/issues/21322)
- [Crystal running into a similar issue but for AMD64 and ARM64](https://github.com/crystal-lang/crystal/issues/14322) (and [another one](https://github.com/crystal-lang/crystal/issues/9533))
- [Odin apparently doesn't support the ARM32 ABI](https://github.com/odin-lang/Odin/issues/3626), and had its [fair share of similar issues](https://github.com/odin-lang/Odin/issues?q=is%3Aissue+struct+abi+is%3Aclosed+label%3Abug)
- [This Inko bug](https://github.com/inko-lang/inko/issues/792) where I found
  that the code generated for structure arguments and returns was incorrect, but
  only when enabling optimizations.

In fact, go to the issue tracker of your favourite compiled programming language
and search for "struct abi" and you'll likely find at least a dozen or so issues
related to generated code incorrectly handling structure arguments and returns.

![This is fine](/images/the-mess-that-is-handling-structure-arguments-and-returns-in-llvm/fine.jpg)

The point here is that getting this right is difficult, and LLVM's lack of,
well, _anything_ to make this easier isn't helping. This isn't recent issue
either: users of LLVM
[have](https://discourse.llvm.org/t/passing-and-returning-aggregates-who-is-responsible-for-the-abi/9360)
[been](https://discourse.llvm.org/t/returning-structs-on-linux-x86/12795)
[asking](https://discourse.llvm.org/t/structure-returns/13268) [for](https://discourse.llvm.org/t/returning-a-structure/14907)
[_years_](https://discourse.llvm.org/t/c-returning-struct-by-value/40518)
how to handle structure arguments and returns, and [why LLVM does things the way
it does](https://discourse.llvm.org/t/passing-structs-to-c-functions/83938/2).
These aren't the only discussions either, as a search for terms such as "struct
returns" and "struct abi" yields dozens of results spanning almost two decades.

When presented with these questions, the answers from maintainers and other
contributors is typically the same: LLVM doesn't do this but clang does, so just
copy whatever clang does. I've also seen plenty of mailing list discussions
where people acknowledge the current state of affairs is less than ideal, but
nobody seems interested in actually doing something about it (at least that I
know of).

## How to generate the correct LLVM

OK, so we know LLVM doesn't handle structures and ABI compliance for us, so what
now? Fear not, for I have [gained a few new grey hairs]{del} gone through the
trouble of figuring this out for at least AMD64 and ARM64 so you don't have to.

This isn't an in-depth specification but rather a brief and easy to understand
overview on how to generate the correct LLVM IR to pass structures as arguments
and return them, based on what existing compilers such as clang and rustc do,
and based on what I ended up implementing for Inko. The following caveats apply:

- SIMD data types may affect these rules. As Inko doesn't support SIMD at this
  stage I've yet to look into this.
- The rules work for Linux, macOS and FreeBSD. I have no idea if Windows
  requires a different set of rules as Inko doesn't support Windows, and I know
  little about Windows development.
- These rules assume a 64 bits architecture (hence the "64" in AMD64/ARM64 in
  case that wasn't obvious).

## AMD64 (also known as x86-64)

### Arguments

[If the size of the structure is less than 8 bytes, pass the structure as an
integer of its size in bits](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/abi/amd64.rs#L13-L16).
Thus, if the structure is 5 bits you'd use `i5` as the type. LLVM takes care of
rounding this up to the correct size. I think it should be fine to do this
rounding yourself, but I stuck with what clang does for the sake of making it
easier to compare outputs between compilers.

[If the size is between 8 and 16 bytes, the logic is a little more
difficult.](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/abi/amd64.rs#L17-L20)
First, "flatten" the structure such that you end up with a list of all the
fields (taking into account nested structures). So
`{ { { { i64, i64 } } }, double }` is essentially treated the same as
`{ i64, i64, double }`. Using this list of fields, [classify each field as
either an integer or float along with their size in
bytes](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/abi/generic.rs#L28-L59).
So for `{ i64, double }` you'd end up with the following list of classes:

```
[Int(8), Float(8)]
```

The next step is to [combine/squash these classes
together](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/abi/generic.rs#L28-L59)
into two classes, turning this list of classes:

```
[Int(4), Int(4), Float(8)]
```
Into the following pair:

```
(Int(8), Float(8))
```

The first field/class is always 8 bytes, while the second field/class _might_ be
less based on the alignment of the structure. It's possible that a structure
consists of both floats and integers, such as `{ i32, float, i64 }`. To handle
such cases, the `combine` routine uses the following logic: if all the fields
combined into a single field are of the same class, use that class as-is (with
the summed size). If there instead is a mixture of classes, promote the class to
an integer:

```
{ float, float, i64 }  ->  { double, i64 }
{ i32, float, i64 }    ->  { i64, i64 }
{ double, i32, i32 }   ->  { double, i64 }
```

Once you have the pair of two classes, [turn them into their corresponding LLVM
types](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/abi/generic.rs#L13-L21)
and [use those types as the two fields for a newly generated
structure](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/context.rs#L268-L283).

For structures larger than 16 bytes, [keep the structure type
as-is](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/abi/amd64.rs#L22)
but set the [`byval` parameter
attribute](https://llvm.org/docs/LangRef.html#parameter-attributes) when
generating the function signature and when passing the argument to a call
instruction.

### Returns

The logic for returning structures up to 16 bytes is the same as for passing
them as arguments.

For structures larger than 16 bytes, [keep the structure type
as-is](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/abi/amd64.rs#L40).
For functions returning such a structure, the first argument must be a pointer
with the `sret` attribute (and optionally the `noalias` and `nocapture`
attributes). The `sret` attribute takes a type as its argument, which must be
the type of the structure that's "returned".

The presence of the `sret` argument means you'll need to shift any user-provided
arguments accordingly. When processing a `return` in such a function, transform
it into a pointer write to the `sret` pointer and return `void` instead. In
other words, a function like this:

```
define { i64, i64, i64 } @example(...other arguments...) {
  %1 = alloca { i64, i64, i64 }, align 8
  ...
  ret { i64, i64, i64 } %1
}
```

Is turned into this:

```
define void @example(ptr sret({ i64, i64, i64 }) noalias nocapture %0, ...other arguments...) {
  %1 = alloca { i64, i64, i64 }, align 8
  ...
  store { i64, i64, i64 } %1, %0, ...
}
```

## ARM64 (also known as AArch64)

### Arguments

First, [check if the structure consists of up to four floating point
fields](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/abi/arm64.rs#L12-L14)
of the same type (i.e. four `double` or three `float` fields), known as a
"homogeneous floating-point aggregate" (HFA). [This can/should reuse the same
`classify` routine used by the AMD64
logic](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/abi/arm64.rs#L55-L78).
If the structure is a HFA, return a flattened version of the structure such that
this:

```
{ { { float } }, float, float }
```

Is turned into this:

```
{ float, float, float }
```

If the structure is _not_ a HFA, the following rules apply (in order):

1. [If the structure size is up to 8
   bytes](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/abi/arm64.rs#L18-L20),
   return it as a 64 bits integer.
1. [If the structure size is between 8 and 16
   bytes](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/abi/arm64.rs#L23),
   return it as a pair of two `i64` values.
1. [If the structure is larger than 16
   bytes](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/abi/arm64.rs#L27),
   use a pointer _without_ the `byval` attribute.

### Returns

The rules for returning structures are the same as passing them and use the same
generated argument approach as AMD64 (e.g. a pointer with the `sret` parameter),
with one small change compared to the arguments rule: [for structures with a
size up to 8 bytes, the return type is an integer with the bits equal to
the structure size in
bits](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/abi/arm64.rs#L42-L46).
So if the structure is 5 bits, then the returned type is an `i5`.

## Structures must be copied at the IR level

Due to the above rules it's likely that the types of structure arguments don't
match the types of their corresponding
[`alloca`](https://github.com/inko-lang/inko/blob/84830aba215d1ec6993be8d89573b36d279da16e/compiler/src/llvm/abi/arm64.rs#L42-L46)
slots. For example, if the user-defined type of an argument is some structure
`A` then the type at the LLVM level might be different based on its size. To
handle such cases, we have to
[`memcpy`](https://llvm.org/docs/LangRef.html#llvm-memcpy-intrinsic) structure
arguments into these slots. Using _just_ `load` and `store` with the correct ABI
types isn't enough and seems to result in LLVM generating incorrect machine
code.

Based on the output of clang and my own testing, it appears the rules to apply
are as follows:

When passing a structure as an argument, the _caller_ must first `memcpy` it
into an `alloca` slot that has the correct ABI type based on the argument rules
mentioned above. The caller must then substitute the original argument with the
result of a [`load`](https://llvm.org/docs/LangRef.html#load-instruction) (using
the ABI type as part of the load) from that `alloca` slot. This isn't necessary
if the original an ABI types are identical. This means you'll end up with
something like this:

```
call void @llvm.memcpy.p0.p0.i64(ptr ABI_ALLOCA, ptr ORIGINAL_ALLOCA, i64 SIZE, i1 false)
%tmp = load ABI_TYPE, ptr ABI_ALLOCA
call void @the_function(ABI_TYPE %tmp)
```

Here `ABI_ALLOCA` is the `alloca` slot for the structure using its ABI type,
while `ORIGINAL_ALLOCA` is the `alloca` slot storing the structure using its
true/user-defined type. `SIZE` is the size of the structure in bytes, while
`ABI_TYPE` is the type of the structure according to the ABI arguments rules
outlined above.

Functions that receive structure arguments must also `memcpy` them into a local
`alloca` slot and then use that slot instead of the original argument.

Similarly, when returning a structure using the `sret` attribute the data must
be copied into the `sret` pointer using `memcpy`.

To ensure these `memcpy` calls don't stick around, the `memcpyopt` optimization
pass is used to remove these calls where possible. This pass is included
automatically when using the `default<O1>`, `default<O2>` or `default<O3>`
optimization pipelines.

Note that I'm still not sure that we _always_ need to use `memcpy` when passing
structures around. An ABI might mandate that callees copy the structures and use
the copy, but I recall running into issues when _not_ using `memcpy` even though
it wasn't strictly required. My pessimistic guess is that this is what clang
does and that the LLVM optimization passes are written with clang in mind,
generating incorrect code when the IR is different from what clang produces. Or
perhaps the ABI _did_ require it but it just wasn't clear to me.

## What LLVM can do to improve this

The simplest thing LLVM could do to improve this while retaining backwards
compatibility is to introduce some sort of `system-abi` function attribute.
When this attribute is applied, one can pass/return structures to/from a
function just like any other scalar value and LLVM takes care of lowering it to
the correct ABI code:

```
; Function Attrs: system-abi
define { i64, i32, double } @example() {
  %1 = alloca { i64, i32, double }, align 8
  ...
  ret { i64, i32, double } %1
}
```

This would remove the need for every frontend to reimplement the same logic for
every target it wishes to support, and likely reduce the amount of compilers
running into the same ABI related bugs. While it _might_ theoretically inhibit
certain optimizations, I can't think of any that would justify every frontend
having to reimplement the same complexity.

Whether something like this will ever be added to LLVM remains to be seen. I
doubt it will happen any time soon though, as making LLVM easier to use or
improving its compile-time performance just doesn't appear to be much of a
priority for the LLVM maintainers and contributors.
