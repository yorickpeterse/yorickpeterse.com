---
{
  "title": "A brief look at FreeBSD",
  "date": "2025-11-12T00:00:00Z"
}
---

Recently I've been playing around with [FreeBSD](https://www.freebsd.org/) in a
virtual machine. The reason for this is that (if all goes well) some time in
December my new Framework laptop will arrive, replacing my current X1 Carbon
that is starting to show signs of old age (e.g. a keyboard where certain keys
don't always work). Framework in turn has a strong focus on Linux compatibility,
and [FreeBSD
compatibility](https://github.com/FrameworkComputer/freebsd-on-framework) to a
certain degree. The FreeBSD foundation in turn is sponsoring work on improving
the laptop experience of FreeBSD, with a focus on Framework laptops in
particular.

In other words, if I ever wanted to run FreeBSD on a laptop, a Framework laptop
would probably be the best option, and using a new laptop means I can just wipe
the installation and replace it with Fedora if FreeBSD turns out to not be worth
it. But before I do that, I needed to figure out if it's even worth the effort
and what I might have to keep in mind.

## Why FreeBSD?

Before I discuss my experience playing around with FreeBSD thus far, let's
discuss why I would even consider using FreeBSD. After all, I'm pretty happy
with my current [Fedora
Silverblue](https://fedoraproject.org/atomic-desktops/silverblue/), minus some
paper cuts here and there. But hey, Linux wouldn't be Linux without paper cuts.

The first reason for looking into FreeBSD is the more cohesive experience it
claims (or at least its users claim) to have. That is, it's not just a kernel
but a kernel plus userspace utilities and a bunch of other things. Whether this
_actually_ matters for end users is difficult to say, but as somebody who
_might_ want to contribute back it could be a benefit. For example, say you want
to contribute a function (e.g. a hypothetical
`get_dns_without_blocking_the_calling_thread` function) to the
C standard library and this function requires some kernel changes. For Linux
this means contributing a change to at least two to three different projects:
the kernel, and glibc, and maybe musl for increased portability. In contrast,
for FreeBSD you just contribute to, well, FreeBSD.

The second reason is the availability of software. While some programs are not
available on FreeBSD (e.g. lua-language-server is not available) or others lag
behind a bit at times (e.g. Electron updates apparently can take a while to
become available), it seems there's a surprising amount of software available.

The third reason is the (at least claimed) stability of FreeBSD as a whole.
Combined with the availability of packages this means that in _theory_ you can
get a system as stable as e.g. Fedora Silverblue, but with a lot more (and more
frequently updated) software available.

There are some additional nice-to-have's that aren't necessarily unique to
FreeBSD that are still potentially interesting. For example, ZFS seems
interesting but Btrfs is probably close enough for most people. FreeBSD also has
jails and had them for a long time, but Linux has LXC (basically FreeBSD jails),
Podman, and basically whatever else builds on top of the [Open Container
Initiative](https://opencontainers.org/).

Of these reason the first one is the most important one: a system that's more
cohesive, rather than something that feels more like a car engine with a bunch
of components bolted on top, each maintained by a different person.

## The setup

Until my new laptop arrives I have no spare computer available that I'm willing
to wipe _just_ to play with FreeBSD, so instead I used a virtual machine.
Specifically, I have an M1 Mac Mini that I use for testing
[Inko](https://inko-lang.org/) on macOS that is turned off most of the time, so
I used that as the VM host. This way I can play around with FreeBSD regardless
of whether I'm using my desktop computer or my laptop.

The VM was actually set up a while ago so I could more easily test Inko on
FreeBSD, using FreeBSD 14.0 which I've since upgraded to 14.3 (more on that
later). For the file system I'm using ZFS. Because this installation is used for
testing there's no desktop environment, instead it's a bare-bones server-like
setup. Note that because the VM runs on an M1 Mac Mini, the architecture is
aarch64 instead of x86-64. This in turn may affect the experience (i.e. certain
default settings may depend on this, though I don't know this for certain).

The use of a VM also means I've not yet been able how well FreeBSD supports the
Framework laptop hardware wise. I know there's been _a lot_ of progress on
improving laptop support in the last few months, but until I actually have a new
laptop I can't verify this. This means the rest of this article focuses just on
the software and user experience side of things.

What follows is a collection of the various steps I took to set things up and my
experience thus far.

## Configuring the network

Let's start with the first and probably most important step: setting up the
network. After all, what good is an operating system if you can't download
pictures of cats. I don't fully remember how I actually set up the network as
it's been a while, but it involved adding the following to `/etc/rc.conf`:

```
hostname="freebsd-mini"
ifconfig_vtnet0="DHCP"
ifconfig_vtnet0_ipv6="inet6 accept_rtadv"
```

DHCP is managed using the "dhclient" service, which I think starts automatically
by default. This also brings me to my first small annoyance with FreeBSD: the
sensible thing to do would be something like `sudo service dhclient CMD` to do
something with the service (e.g. restart it), but instead this will fail with
the following:

```
/etc/rc.d/dhclient: ERROR: /etc/rc.d/dhclient: no interface specified
```

When I first encountered this error I thought there was something wrong with the
mentioned file (`/etc/rc.d/dhclient`). After a bit of digging it turns out that
you also have to specify the interface when running the `service` command, i.e:

```
sudo service dhclient restart vtnet0
```

I suppose the idea here is that you can have multiple DHCP clients for different
interfaces and want to manage them separately. Personally I'd prefer it if
leaving out the interface results in the command applying to all configured
interfaces, but I'll write this off as me just not understanding FreeBSD well
enough yet.

## DNS caching

For DNS, FreeBSD by default just queries whatever nameservers `/etc/resolv.conf`
defines, in contrast to most Linux distributions that ship something like
[dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html) to handle this by default.

To enable DNS caching you have two (somewhat confusingly named) options (and
maybe more that I'm not aware of):
[unbound](https://nlnetlabs.nl/projects/unbound/about/) and
[local\_unbound](https://man.freebsd.org/cgi/man.cgi?local-unbound). The
difference between the two is that "unbound" is a full-blown DNS resolved, while
"local\_unbound" is meant solely for responding to and caching queries from the
local machine. Or in [grug speak](https://grugbrain.dev/): unbound for other
grugs in network, local\_unbound only for grug itself.

The [FreeBSD handbook covers how to set up
local\_unbound](https://docs.freebsd.org/en/books/handbook/network-servers/index.html#_dns_server_configuration).
The handbook mentions that the DNS servers used _prior_ to enabling
local\_unbound _must_ support DNSSEC, otherwise DNS queries will fail. My dumb
grug brain decided to ignore that part thinking it wouldn't be relevant. As a
result I got to spend the next hour trying to figure out why DNS queries didn't
work, only to realise it's because my Mikrotik router (the upstream DNS server
that I use as a network wide DNS cache) doesn't support DNSSEC.

To resolve this, I had to figure out how to disable DNSSEC while still being
able to cache DNS queries locally. Thanks to [this broken looking
website](https://www.codenicer.com/content/unbound-without-dnssec-freebsd-10) I
figured out you can do so by creating `/var/unbound/conf.d/disable-dnssec.conf`
with the following contents:

```
server:
    module-config: "iterator"
```

Then you restart the service using `sudo service local_unbound restart` and off
you go. It would be nice if the FreeBSD handbook discussed disabling DNSSEC as
it would've saved me quite some time.

## Changing a few default settings

OK so we got a working network connection and DNS caching, let's take a look at
the defaults that FreeBSD provides (or doesn't). Specifically, I read [this
article](https://vez.mrsk.me/freebsd-defaults) a while back and was wondering
how much of the article is still relevant.

### ASLR and W\^X protection

First up,
[ASLR](https://en.wikipedia.org/wiki/Address_space_layout_randomization) and
[W\^X](https://en.wikipedia.org/wiki/W%5EX). The mentioned article lists a bunch
of ASLR settings though it seems to leave out a few for 64-bits executables.
Based on [this manual
page](https://man.freebsd.org/cgi/man.cgi?query=mitigations&sektion=7&format=html)
and the article at least the following settings are of interest for a 64-bits
system:

```
kern.elf64.allow_wx
kern.elf64.aslr.enable
kern.elf64.aslr.honor_sbrk
kern.elf64.aslr.pie_enable
kern.elf64.aslr.stack
```

In my VM the defaults are as follows:

```
kern.elf64.allow_wx: 1
kern.elf64.aslr.enable: 1
kern.elf64.aslr.honor_sbrk: 0
kern.elf64.aslr.pie_enable: 1
kern.elf64.aslr.stack: 1
```

For 32-bits executables it seems ASLR is disabled, though I don't know enough
about ASLR to determine if that's good or bad. For 64-bits only systems this
doesn't matter anyway.

Based on this I think the only setting worth changing is setting
`kern.elf64.allow_wx` to `0`, given this protection is widely enabled by other
operating systems.

### PID randomization

PID randomization is disabled by default and is enabled using the following
`/etc/sysctl.conf` setting:

```
kern.randompid=1
```

Whether this is useful is difficult to say. OpenBSD does this by default, while
Linux doesn't appear to enable this. I tried figuring out what a good value for
this setting is, but I haven't been able to find a good answer.

Given that it's unclear what the actual benefit of PID randomization is and that
it feels like security through obscurity, I've left this option disabled.

### Disallow non-root from reading `dmesg` and the likes

By default non-root users can read the system message buffer through `dmesg`. In
contrast, Linux (or at least Fedora) disallows this by default. Because this
buffer may contain sensitive information, I think it's a good idea to disallow
this using the following setting:

```
security.bsd.unprivileged_read_msgbuf=0
```

### Hiding processes of other users

By default a user can see the processes of other users, similar to most (all?)
Linux distributions. You can turn this off using the following settings:

```
security.bsd.see_other_uids=0
security.bsd.see_other_gids=0
security.bsd.see_jail_proc=0
```

For a desktop environment I would actually leave this enabled though, as it
makes debugging a little easier. For a server there's no reason for user A to be
able to see processes of user B, so it's probably best to disable this for such
setups.

### Other defaults

There are many more defaults that may be worth looking into, but based on what I
could find most of those won't need to be changed in most cases. It certainly
doesn't seem to be as bad (anymore) as it might've once been.

## Enabling pkgbase

OK we now have a sensible system. At this point I was still running FreeBSD
14.0, so I figured it was time to upgrade to 14.3 before doing anything else.
This brings me to this thing called
["pkgbase"](https://wiki.freebsd.org/action/show/pkgbase?action=show&redirect=PkgBase).
Basically this is a new way of updating FreeBSD installation that's still under
development but scheduled for release in FreeBSD 15. Without going into it too
deeply, FreeBSD offers (at least for now) two ways of updating your system:

1. `pkg` is used for updating individual packages (e.g. your text editor)
1. `freebsd-update` is used for updating FreeBSD itself (e.g. from 14.0 to 14.3)

The pkgbase project/thing aims to unify this so you only need to use the `pkg`
command for both. Basically it's what every Linux distribution has been doing
for decades at this point.

Until FreeBSD 15 is released you'll need to manually enable this. The [FreeBSD
handbook discusses how to do
this](https://docs.freebsd.org/en/books/handbook/cutting-edge/#_converting_a_host_to_use_pkgbase)
so I won't cover this. I did run into a few issues/quirks when enabling it:

1. The `fetch` command from the handbook just froze and I ended up having to use
   `curl` to download it instead. I don't remember why though, maybe it might've
   been due to those self-inflicted DNS issues I mentioned earlier
1. You have to edit a config file to update to a new version. This seems a
   little clunky and difficult to automate (without overwriting the entire
   configuration file)
1. After the upgrade I ended up with a bazillion `.pkgsave` files, similar to
   what [this article discusses](https://phala.isatty.net/~amber/hacks/pkgbase).
   I ended up just removing these using the `find` command mentioned in said
   article. Why were these files created? No idea, but let's hope this doesn't
   keep happening
1. I figured you'd just run `pkg update` to update the system or maybe something
   like `pkg update --system`, but instead you have to run `sudo pkg update -r
   FreeBSD-base`. It's not a big issue, but it would be nice not having to
   remember the `FreeBSD-base` bit

After going through this process everything did work fine, so that's nice. One
thing I'd like to see is `pkg` creating ZFS snapshots before upgrading to a new
FreeBSD version, but perhaps that's something I have to explicitly enable
somewhere (I have yet to figure this out).

## Package management

The `pkg` tool itself is quite nice, and unlike `dnf` it's pretty darn fast when
it doesn't have to download anything. It also doesn't automatically update the
package database when you least expect it, instead requiring you to explicitly
run `pkg update`. I much prefer this over having to remember to use `dnf -C` to
avoid having to wait 30 seconds for it to refresh the database.

Which brings me to the downloading bit: `pkg` downloads packages sequentially,
instead of downloading them concurrently ([a feature requested since
2017](https://github.com/freebsd/pkg/issues/1628)). This is a bit annoying
because while I have a gigabit internet connection, the FreeBSD mirrors appear
to be limited to a speed of around 100 megabits/second. Depending on the number
of packages that need to be downloaded this means having to wait longer than
strictly necessary. Considering every Linux package manager that I know of
supports concurrent downloads, this is a bit annoying.

When it comes to packages, FreeBSD has a surprising large number of packages
available, and from what I can tell most of them are also up to date, though
there are some exceptions. For example, stylua isn't available in the Fedora
repository (though you can use [my copr
repository](https://copr.fedorainfracloud.org/coprs/yorickpeterse/stylua/)),
while FreeBSD does have it (though the version is almost one year out of date).
This will differ per package and its popularity, so your mileage may vary.

A weird quirk I ran into is that for certain packages `pkg info NAME` only works
for installed packages, which the output of `pkg help info` doesn't make clear.
It seems the closest equivalent is `pkg search -f NAME`, though that gives you
the information of _all_ packages that match `NAME`, not just the package with
that exact name.

To summarise, `pkg` feels similar to `dnf`: a bit clunky and not as fast as it
should be, but manageable.

## Firewalls

The world of firewalls on Linux is a bit of a mess, with different distributions
using different firewalls ([ufw](https://launchpad.net/ufw),
[firewalld](https://firewalld.org/), etc). Fedora uses firewalld which is...OK,
but I'm not a fan of the confusing CLI.

FreeBSD has not one, not two but _three_ competing firewalls: PF, IPFW, and IPF.
All seem to come with their own configuration syntax and semantics (e.g.
ordering of rules). It seems PF is generally recommended because it's based on
PF from OpenBSD, though FreeBSD uses a fork which has diverged a lot and (from
what I could find) wasn't (isn't?) kept in sync with OpenBSD's PF.

I haven't figured out yet which one should be used, but there being _three_
competing firewalls feels more like something you'd expect in Linux and not a
BSD.

## Resource usage

On a totally different note, it's refreshing to see how few processes a basic
FreeBSD installation runs: about 50 or so (fewer if you disable all the TTY
console processes), compared to the 100-150 or so you'll end up with when using
a stock Fedora Server installation. This isn't necessarily better (and depending
on what those processes do might be worse), but at least in theory it means
fewer moving parts to worry about.

## CLI quirks

This is something that does annoy me far more than it should: the differences
between GNU and BSD CLI programs. Specifically, GNU programs tend to support
both short and long form options (e.g. `-h` and `--help`) while the FreeBSD
toolchain seems to stubbornly reject this and generally only supports short
options. The output of `--help` is often also utterly useless on FreeBSD. Take
the `ln --help` command for example, on Fedora it outputs the following:

```
$ ln --help
Usage: ln [OPTION]... [-T] TARGET LINK_NAME
  or:  ln [OPTION]... TARGET
  or:  ln [OPTION]... TARGET... DIRECTORY
  or:  ln [OPTION]... -t DIRECTORY TARGET...
In the 1st form, create a link to TARGET with the name LINK_NAME.
In the 2nd form, create a link to TARGET in the current directory.
In the 3rd and 4th forms, create links to each TARGET in DIRECTORY.
Create hard links by default, symbolic links with --symbolic.
By default, each destination (name of new link) should not already exist.
When creating hard links, each TARGET must exist.  Symbolic links
can hold arbitrary text; if later resolved, a relative link is
interpreted in relation to its parent directory.

[options and a bunch or extra stuff here]
```

Meanwhile on FreeBSD:

```
$ ln --help
ln: illegal option -- -
usage: ln [-s [-F] | -L | -P] [-f | -i] [-hnv] source_file [target_file]
       ln [-s [-F] | -L | -P] [-f | -i] [-hnv] source_file ... target_dir
```

Oh OK, I guess doing the sensible thing is too much to ask for so let's just use
`-h`:

```
$ ln -h
usage: ln [-s [-F] | -L | -P] [-f | -i] [-hnv] source_file [target_file]
       ln [-s [-F] | -L | -P] [-f | -i] [-hnv] source_file ... target_dir
```

What about the manual page? Isn't FreeBSD better in that regard? Well, no: the
manual page for `ln` on both Fedora and FreeBSD is about the same, except the
GNU version of `ln` supports a whole bunch of extra long options that aren't
present on FreeBSD (e.g. `--no-target-directory`).

Another annoyance is that FreeBSD is more pedantic about the position of
options when combined with sub commands. For example, `bectl -h create` works
(though it's output is the same as `bectl -h`) but `bectl create -h` produces an
error, then proceeds to spit out the same output as `bectl -h`.

Of course you can install GNU coreutils ([or the Rust rewrite if you like not
having a working system](https://lwn.net/Articles/1043103/)), but then you might
as well stick with Linux in the first place.

To be honest, I feel the FreeBSD core utilities are a straight up downgrade
compared to GNU coreutils. Maybe I'll change my mind over time.

## ZFS

I haven't had the time yet to play around with ZFS beyond creating a new boot
environment using `bectl`, so I can't comment on ZFS just yet.

## Jails

Similar to ZFS I have yet to play with jails. I want to look into
[bastille](https://bastillebsd.org/) specifically since it seems to be the
closest to [Podman](https://podman.io/) (i.e. it has a concept similar to
`Dockerfile`/`Containerfile` files), but I haven't had a chance yet.

## Profiling

This is something I still need to figure out: what is the FreeBSD approved way
of profiling userspace applications? On Linux you'd use something like
[perf](https://perfwiki.github.io/main/) to collect your data and
[hotspot](https://github.com/KDAB/hotspot) to visualize it, but on FreeBSD it
seems there are only a bunch of different rocks you have to bang together
yourself.

For example, there's [dtrace](https://dtrace.org/) but I haven't been able to
figure out how you use it without having to write a bunch of D scripts yourself.
There are also some other FreeBSD specific tools such as
[pmcstat](https://man.freebsd.org/cgi/man.cgi?query=pmcstat&apropos=0&sektion=0&manpath=FreeBSD+14.3-RELEASE+and+Ports&arch=default&format=html),
but I have yet to figure out how to use them.

Basically what I want is something like `profile-the-damn-thing PROGRAM`
followed by `visualize-the-damn-thing DATA` and that's it. If you happen to know
of such a tool, please let me know!

## The community

While not related to the technical merits of FreeBSD, I do feel this is worth
mentioning. The FreeBSD community is...difficult. What I mean by this is that it
feels much like the average Linux community in the early 2000s: it looks
down on others (in this case Linux users), it appears rather unwelcoming and at
times downright toxic. Any time you mention anything vaguely related to
Linux you'll inevitably cause somebody to go on a massive rant about how FreeBSD
is better than Linux.

It also seems there's a general dislike for change, even if said change is for
the better. It feels like a form of "tech boomerism": change is bad because it's
not what we're used to, even if the end result is in fact better.

Of course not everybody is like this, but at least the two main community
platforms that I know of (the FreeBSD subreddit and the FreeBSD forums) seem to
suffer from this problem quite a bit.

Solving this results in a bit of a circular problem: for a community to become
more mature and less toxic it needs to grow and attract a more diverse pool of
members, but this only happens if those wanting to join aren't pushed away in
the first place by the behavior of existing members. I don't know how you'd
break such a cycle short of having good leadership and a lot of luck.

## Conclusions thus far

Thus far I'm not entirely sure if I'd see myself using FreeBSD, though I'd have
to play around with FreeBSD on physical hardware to get a better understanding.
For example, I'm curious how well KDE works when installed using the upcoming
FreeBSD 15 installer (I'd use GNOME but due to its systemd dependency it's
unlikely to keep working on FreeBSD in the future). I'm also curious about how
well the Framework laptop is supported.

Besides that there is a bigger question that I need to answer for myself: given
the quirks of FreeBSD, what actually would the benefit of using it be? Sure
there's ZFS, but Linux has Btrfs (and technically you can also use ZFS on Linux,
even if it's painful). Sure, the FreeBSD kernel and userspace are part of the
same project, but does that matter if the kernel doesn't necessarily perform
better or faster and the userspace is subpar compared to that of Linux? Sure,
FreeBSD may use fewer resources but does that matter if your WiFi card isn't
supported?

The only way to answer these questions is to give FreeBSD a try on my Framework
laptop when it arrives later this year, at which point I'll write a follow-up
article to share my thoughts.
