---
title: Compiling XPath to Ruby
created_at: 2015-09-06 22:45 CEST
kind: article
keywords:
  - oga
  - xpath
  - ruby
  - compile

description: "Compiling XPath to Ruby in Oga 1.3.0"
---

The process of evaluating a programming or query language is typically broken up
in 3 steps:

1. The lexing phase, which turns raw text into a sequence of "tokens". Tokens
   are usually a pair (e.g. an array or tuple) of a type and a value.
2. The parsing phase, which turns a sequence of tokens into an
   [Abstract Syntax Tree (AST)][ast].
3. An evaluation phase, producing a set of instructions a machine should execute
   based on an AST.

For the third step there are two ways of doing things:

1. Instructions are executed on the fly.
2. Instructions are generated and executed separately.

Both options have their benefits and drawbacks. A system that executes
instructions on the fly is typically easier to implement. However, these systems
tend to be slower as there's very little to no room for optimizations as
execution depends directly on the input AST. Directly evaluating ASTs also makes
it very hard (if not downright impossible) to perform
[Just In Time (JIT) compilation][jit-compilation].

A system that first generates instructions and _then_ executes them can be
harder to implement, at the benefit of allowing for better optimizations.

An example of the first method would be Ruby 1.8, while an example of the second
method is your average C compiler (e.g. gcc).

## XPath Evaluation in Oga

Up until version 1.3.0, Oga used to evaluate XPath queries on the fly. While the
code was fairly easy to work with, performance left a lot to be desired. The
setup of this evaluator was as following:

Every type of AST node would have a corresponding handler method called `on_X`
where `X` would be the type of the AST node. For example, an `int` AST node
would be handled by `on_int`. Each of these handlers would take their input,
operate on it, and return the result. The usual return value would be an
instance of `Oga::XML::NodeSet`, an Array-like object used for storing XML
nodes.

The performance impact of this setup depends on two things: the size of the
input document, and the size and complexity of the given XPath query. For small
documents the performance wasn't too bad, but for larger documents (e.g. the
[10 MB test file][test-file] used for benchmarks) this could result in even
simple queries taking seconds to complete.

In short, if I wanted to improve performance I would need to come up with a
radically different way of evaluating XPath queries.

## Compiling XPath

The alternative I started looking into was compiling XPath to some kind of
format that could be executed in a more efficient way. One option would be to
compile to some custom [bytecode][bytecode] format and evaluate that. However,
ideally the target format would be something that could take advantage of
optimizations already provided by Ruby implementations. That way I wouldn't have
to write my own optimization passes or maybe even some sort of JIT compiler.

Compiling to Ruby bytecode would be an option, if it weren't for every
implementation using its own bytecode format. Also, no implementation to date
actually considers the bytecode part of their public API (as far as I'm aware),
meaning it could change at any given point.

Ruby source code on the other hand works across implementations, is stable, and
can take advantage of all performance optimizations a Ruby implementation might
have to offer.

Starting with version 1.3.0, Oga compiles XPath expressions to Ruby source code.
The result is a Proc that takes an input document (or element) and returns the
result of the XPath expression it was compiled from. The compiled Procs are
cached on a per expression basis. This means that if you run the same query in a
loop, Oga only has to compile it once.

Code wise the setup is fairly similar to the old evaluator. There are still AST
node type specific handlers (`on_int`, `on_axis_following_sibling`, etc).
However, instead of returning `Oga::XML::NodeSet` instances they return AST
nodes used to produce Ruby source code.

## Performance Improvements

The new compiler setup yields significant performance improvements over the old
evaluator setup. In certain cases performance is even better than Nokogiri,
which uses C for its XPath evaluation.

Of course any performance claim is meaningless without a benchmark to back it
up. Oga has several benchmarks for the new compiler, these resides in the
[benchmark/xpath/compiler][benchmarks] directory of the repository.

Benchmarks were run on a Thinkpad T520 running Linux 4.1 with a bunch of
applications in the background, while listening to the
[Metal Gear Solid 5: The Phantom Pain soundtrack][mgs5-soundtrack] on YouTube.
In other words, treat these numbers with a grain of salt. For best results you
should run these benchmarks yourself. To do so, clone the Git repository of Oga,
run `rake generate fixtures` and then run one of the benchmark files like any
other Ruby script.

First, lets look at the benchmark `big_xml_average_bench.rb`. This benchmark
takes a [10 MB test file][test-file] and runs the query
`descendant-or-self::location` 10 times, measuring the execution time for every
iteration. Using Oga 1.2.3 we get the following output:

    #!text
    Iteration: 1: 3.493
    Iteration: 2: 2.868
    Iteration: 3: 2.934
    Iteration: 4: 2.965
    Iteration: 5: 2.926
    Iteration: 6: 2.928
    Iteration: 7: 3.008
    Iteration: 8: 2.977
    Iteration: 9: 2.938
    Iteration: 10: 2.993

    Iterations: 10
    Average:    3.003 sec

Using Oga 1.3.0 the output is as following instead:

    #!text
    Iteration: 1: 0.432
    Iteration: 2: 0.448
    Iteration: 3: 0.522
    Iteration: 4: 0.453
    Iteration: 5: 0.44
    Iteration: 6: 0.494
    Iteration: 7: 0.448
    Iteration: 8: 0.431
    Iteration: 9: 0.432
    Iteration: 10: 0.437

    Iterations: 10
    Average:    0.454 sec

Here Oga 1.3.0 is about 6.6 times faster.

Next, lets look at the benchmark `concurrent_time_bench.rb`. This benchmark uses
the XML file [kaf.xml][kaf] and runs the query `KAF/terms/term` 10 times in
parallel using 5 threads. The idea of this benchmark is to measure performance
as the number of threads increase. A higher number of threads can result in more
pressure on the garbage collector (GC), depending on the code being benchmarked.
More pressure on the GC can in turn result in poorer performance due to the GC
having to stop all threads more often.

Using Oga 1.2.3 the results of this benchmark are as following:

    #!text
    Preparing...
    Starting threads...
    Samples: 50
    Average: 0.2316 seconds

Using Oga 1.3.0:

    #!text
    Preparing...
    Starting threads...
    Samples: 50
    Average: 0.0342 seconds

Here Oga 1.3.0 is also around 6.6 times faster.

Finally, lets look at the benchmark `comparing_gems_bench.rb`. This benchmark
uses the XML document `<root><number>10</number></root>` and retrieves all text
nodes of all `<number>` nodes. This benchmark uses
[benchmark-ips][benchmark-ips].

The benchmark runs this query for the following libraries:

* Ox: 2.2.0
* Nokogiri: 1.6.6.2
* REXML: MRI 2.2.1 was used (as REXML is bundled in Ruby's standard library)
* Oga

Note that Ox doesn't actually support XPath, it instead offers its own querying
language. As a result it's not entirely fair to compare it with the other
libraries. However, for the sake of showing the performance difference of Ox'
query language versus the rest I've included it any way.

Using these Gems and Oga 1.2.3, the results are as following:

    #!text
    Calculating -------------------------------------
                      Ox    14.548k i/100ms
                Nokogiri     3.879k i/100ms
                     Oga     2.681k i/100ms
                   REXML     1.114k i/100ms
    -------------------------------------------------
                      Ox    197.284k (± 3.9%) i/s -    989.264k
                Nokogiri     46.701k (± 9.7%) i/s -    232.740k
                     Oga     28.293k (± 2.0%) i/s -    142.093k
                   REXML     11.901k (± 2.8%) i/s -     60.156k

    Comparison:
                      Ox:   197284.2 i/s
                Nokogiri:    46701.1 i/s - 4.22x slower
                     Oga:    28292.6 i/s - 6.97x slower
                   REXML:    11900.5 i/s - 16.58x slower

And using Oga 1.3.0:

    #!text
    Calculating -------------------------------------
                      Ox    15.227k i/100ms
                Nokogiri     3.966k i/100ms
                     Oga    13.874k i/100ms
                   REXML     1.168k i/100ms
    -------------------------------------------------
                      Ox    201.044k (± 1.5%) i/s -      1.005M
                Nokogiri     47.338k (± 8.6%) i/s -    237.960k
                     Oga    166.485k (± 9.8%) i/s -    832.440k
                   REXML     11.693k (± 5.3%) i/s -     58.400k

    Comparison:
                      Ox:   201044.3 i/s
                     Oga:   166485.5 i/s - 1.21x slower
                Nokogiri:    47338.3 i/s - 4.25x slower
                   REXML:    11692.7 i/s - 17.19x slower

Here Oga 1.3.0 is about 5.8 times faster compared to version 1.2.3. Using 1.3.0
Oga outperforms not only REXML but also Nokogiri.

Please keep in mind that performance will vary depending on the size of the
input document and the query being used. There will be cases where Oga
outperforms others, but there will (probably) also be cases where it performs
worse.

## Wrapping Up

The source code for the compiler can be found in
[lib/oga/xpath/compiler.rb][xpath/compiler.rb]. The source code used for the Ruby AST
and code generation can be found in [lib/oga/ruby][oga/ruby]. There are still
plenty of parts in the compiler that could be optimized further as the current
code is largely ported from the old evaluator.

Those who wish to take advantage of the new compiler can simply update to Oga
1.3.0. A full list of changes can be found in [the changelog][changelog].

[ast]: https://en.wikipedia.org/wiki/Abstract_syntax_tree
[jit-compilation]: https://en.wikipedia.org/wiki/Just-in-time_compilation
[test-file]: https://github.com/YorickPeterse/oga/blob/ac5cb3d24f407a6ed8d8b583e59fa89084e9acb5/benchmark/fixtures/big.xml.gz
[bytecode]: https://en.wikipedia.org/wiki/Bytecode
[benchmarks]: https://github.com/YorickPeterse/oga/tree/ac5cb3d24f407a6ed8d8b583e59fa89084e9acb5/benchmark/xpath/compiler
[kaf]:https://github.com/YorickPeterse/oga/blob/master/benchmark/fixtures/kaf.xml.gz
[benchmark-ips]: https://github.com/evanphx/benchmark-ips
[mgs5-soundtrack]: https://www.youtube.com/watch?v=83jWwQfK-f8
[xpath/compiler.rb]: https://github.com/YorickPeterse/oga/blob/b07c75e96495f06c0914d135d30b26e55bcbb483/lib/oga/xpath/compiler.rb
[oga/ruby]: https://github.com/YorickPeterse/oga/tree/b07c75e96495f06c0914d135d30b26e55bcbb483/lib/oga/ruby
[changelog]: https://github.com/YorickPeterse/oga/blob/b07c75e96495f06c0914d135d30b26e55bcbb483/CHANGELOG.md#130---2015-09-06
