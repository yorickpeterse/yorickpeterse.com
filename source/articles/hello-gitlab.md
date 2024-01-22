---
{
  "title": "Hello, GitLab!",
  "date": "2015-08-31T20:49:00Z"
}
---
<!-- vale off -->

I'm excited to announce that I will be joining [GitLab][gitlab] starting October
1st. I greatly enjoyed my time at [Olery][olery], but after almost 3 years I
felt it was time for a new adventure. If you're based in Amsterdam and love
working with Ruby you should definitely send your details over to
<jobs@olery.com>.

At GitLab my time will be broken up in to two chunks. 80% of my time (4 days)
will be spent on improving performance and stability of the platform. This will
include things such as improving the response time of web pages, cutting down
memory usage, decreasing the time it takes to process Git repository data, etc.

The other 20% of my time (1 day) will be spent on improving Rubinius. Initially
I'll start with wrapping up some existing work such as
[updating rubysl-socket][rubysl-socket], [pull request #3356][pr-3356],
[pull request #3372][pr-3372] and finishing
[the work needed to support Ruby 2.2][ruby-22].

Once this has been taken care of I plan to work on two things:

1. Improving performance of Rubinius itself.
1. Building tools to help improve Rubinius and applications using Rubinius.

One idea I'm already toying with is adding the ability of tracing object
allocations using Ruby itself. Tracing allocations should have a very low
overhead and should not require disabling the garbage collector for accurate
statistics. This in turn would allow one to run a tracer in their production
application (e.g. using something like New Relic's Ruby agent) _without_ having
to worry about slowing the application down to a crawl.

Another idea is to add a way of tracing constant/method cache invalidations. In
particular constant cache invalidations can be tricky to debug, even when using
Rubinius' `-Xic.debug` and `-Xserial.debug` options. For more information about
this idea you can refer to [issue #3490][issue-3490].

Adding support for LLVM 3.6/MCJIT ([pull request #3367][pr-3367]) is something I
will sadly not be working on any time soon. In order to do so I would first have
to learn about all the nitty-gritty details of LLVM, which in itself can easily
take months. As such I'm leaving this up to Brian Shirai, who already started
working on the various parts needed to support LLVM 3.6.

Finally, I'd like to thank GitLab for this opportunity. While 1 day a week might
not seem like much, it's _a lot_ better than the 1 or 2 hours a week (if I'm
lucky) I can currently dedicate to Rubinius. Hopefully in the future I can
dedicate even more time to Rubinius, but only time will tell (no pun intended).

[gitlab]: https://about.gitlab.com/
[olery]: http://www.olery.com
[rubysl-socket]: https://github.com/rubysl/rubysl-socket/pull/9
[pr-3356]: https://github.com/rubinius/rubinius/pull/3356
[pr-3372]: https://github.com/rubinius/rubinius/pull/3372
[ruby-22]: https://github.com/rubinius/rubinius/issues/3264
[issue-3490]: https://github.com/rubinius/rubinius/issues/3490
[pr-3367]: https://github.com/rubinius/rubinius/pull/3367
