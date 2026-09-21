---
{
  "title": "Sandboxing with minimal effort",
  "date": "2026-09-21T00:00:00Z"
}
---

[The other
day](https://github.com/inko-lang/inko/commit/088b45b6d9b85b239c132d70fc660f46eb698d0b)
I merged a new feature for [Inko](https://inko-lang.org/) that I think is quite
interesting: the ability to sandbox an application with minimal effort.

While memory safety is a goal of Inko (ignoring the usual escape hatches such as
the FFI), memory safety only gets you so far. Most notably, the code is still
written by developers and developers are, by and large stupid, myself included.
And no, using an LLM to do the writing instead doesn't improve things; if
anything it makes it even worse given the average LLM has the intellect of a
talking parrot with a bad drinking habit.

One approach popularized by [Docker](https://www.docker.com/) is to run the
program in a container. Not just because it makes distribution easier, but also
because additional restrictions may be applied to the container, such as
limiting the files it has access to. For example, this website is served by
[shost](https://github.com/yorickpeterse/shost), a static file server written in
Inko. To run the server I use the following [Podman
quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html):

```
[Container]
Image=ghcr.io/yorickpeterse/shost:main
Pull=missing
ContainerName=shost
Exec=shost --sites /var/lib/shost/sites --tls /var/lib/shost/tls --log json --ip ::
PodmanArgs=--memory 1024m
ReloadSignal=HUP
Network=host

ReadOnly=true
UserNS=auto:uidmapping=0:500,gidmapping=0:500,size=1024
DropCapability=all
AddCapability=CAP_NET_BIND_SERVICE

Volume=/var/lib/shost:/var/lib/shost:z,ro

[Service]
Restart=on-failure
RestartSec=60
TimeoutStopSec=15

[Install]
WantedBy=default.target
```

If you're not familiar with quadlets, they're essentially systemd unit files for
running containers using Podman. It's a bit similar to Docker Compose, but a lot
nicer to work with.

Either way, the point here is that in the above quadlet I apply some
restrictions to the container: all capabilities except for the "bind" capability
are dropped, and the files that need to be served are mounted into the container
as a read-only volume. Oh and if you're wondering what that `UserNS` line is
for, that's to work around [this
issue](https://github.com/podman-container-tools/podman/discussions/29423).

Now this is great and all, but it would be even better if the application itself
included some mechanism to restrict its own capabilities, regardless of how it's
run.

Fortunately, most mainstream operating systems offer some way for an application
to sandbox itself. For example, on Linux one can use
[Landlock](https://docs.kernel.org/userspace-api/landlock.html) while on macOS
one can use Seatbelt through
[`sandbox_init`](https://www.manpagez.com/man/3/sandbox_init/). FreeBSD in turn
has [Capsicum](https://wiki.freebsd.org/Capsicum), and OpenBSD has
[pledge](https://man.openbsd.org/pledge.2) and
[unveil](https://man.openbsd.org/unveil.2).

The sandboxing API provided by Inko uses these primitives to provide a
cross-platform way of sandboxing your application, and tries to handle platform
specific behavior/differences as much as possible. For example, on macOS
allowing a file to be executed is easy but when using Landlock you also have to
set up the appropriate rules for the ELF program interpreter
(`/lib64/ld-linux-x86-64.so.2` in most cases). If shared libraries are in a
non-standard location you also need to make sure those can be read.

Of course this new API is not without its trade-offs. Most notably, on FreeBSD
the sandbox is a no-op. Not because I was too lazy to make use of Capsicum, but
rather because Capsicum requires you to fundamentally change the structure of
your program. On Linux and macOS you can apply sandbox restrictions without
having to change your program, other than whatever lines of code are necessary
to list the sandbox rules (i.e. the above `enable_sandbox` method). Capsicum on
the other hand works a little differently: once you call
[`cap_enter`](https://man.freebsd.org/cgi/man.cgi?query=cap_enter&sektion=2&manpath=FreeBSD+15.1-RELEASE+and+Ports.quarterly)
you can no longer open resources using the usual system calls such as `open`.
Instead, Capsicum requires that you either open all the appropriate resources
_before_ calling `cap_enter`, or that you open directories ahead of time and
then use [`openat`](https://man.freebsd.org/cgi/man.cgi?query=openat&sektion=2&manpath=FreeBSD+15.1-RELEASE+and+Ports.quarterly)
to open resources relative to that directory. In some cases you may also have to
use [libcasper](https://man.freebsd.org/cgi/man.cgi?query=libcasper&manpath=FreeBSD+15.1-RELEASE+and+Ports.quarterly).
Of course for simple programs this may not be much of an issue, but for larger
programs it may require you to extensively change how they are written.
[`openat` itself also has its issues](https://marc.info/?l=openbsd-tech&m=174844109910709&w=2).

That's not to say you can't make Capsicum work or that it's somehow "bad",
rather it means you (unfortunately) can't use Capsicum in many instances unless
you're willing to adjust your program to specifically cater towards FreeBSD and
Capsicum.

So how difficult is it to sandbox an Inko application using [this new
API](https://docs.inko-lang.org/std/main/module/std/sandbox/Sandbox/)? Well,
here's all that was necessary to [sandbox
shost](https://github.com/yorickpeterse/shost/commit/b6f5bcb7ecaa20b4ffb9d11b1b4992d0e6744c70):

```inko
import std.sandbox (Sandbox, bind, read)

# ...

fn enable_sandbox(config: ref Config) {
  let s = Sandbox.new

  match config.tls {
    case Some(v) -> s.path(v, read)
    case _ -> {}
  }

  s.path(config.sites.path, read)
  s.tcp(config.port, bind)
  s.enable
}
```

That is: we allow access to the directory containing TLS certificates (if TLS is
enabled), we allow access to the directory containing the files to serve, and we
allow binding to the TCP port the server listens on (e.g. 443 when TLS is
enabled). Everything else is denied.

While one could consider applying a sandbox to something like shost redundant,
given it already runs in a restricted container, it's also so easy to use this
new API there's no reason _not_ to use it.

And that brings me to the following that's worth repeating before we wrap things
up for the day: the value of a security feature lies not in what it can do, but
rather in it's ease of use. I think the API provided by Inko does a pretty good
job at achieving just that, though I may be biased on account of, well, having
written it.
