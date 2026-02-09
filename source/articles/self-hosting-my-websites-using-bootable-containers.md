---
{
  "title": "Self-hosting my websites using bootable containers",
  "date": "2026-02-09T00:00:00Z"
}
---

I've been running this website since 2008. Over the years I've changed hosting
providers and what software to use a bunch of times. Some time in 2015 I
switched to hosting it as a static website on [Amazon
CloudFront](https://en.wikipedia.org/wiki/Amazon_CloudFront). A few years ago I
moved from Amazon to Cloudflare, primarily because [Cloudflare
Pages](https://pages.cloudflare.com/) and [Cloudflare
R2](https://pages.cloudflare.com/) have a generous free tier, and an interface
that isn't a confusing mess.

Cloudflare isn't without its issues though. For example, the manual and
standard library documentation for [Inko](https://inko-lang.org/) is versioned
using sub-directories so you end up with URLs like so:

- <https://docs.inko-lang.org/manual/main/>
- <https://docs.inko-lang.org/manual/latest/>
- <https://docs.inko-lang.org/manual/v0.19.1/>

While you _can_ technically do this with Cloudflare Pages, the deployment model
is such that you'd have to keep these generated files around and include them as
part of each deployment. As far as I know you also can't download the source
files of a deployment, thus requiring you to track all generated files in Git
just so future deployments keep the data around.

Then there are the release artifacts of Inko's release process, such as source
archives and pre-compiled runtime libraries for cross-compilation. Here we run
into a similar issue: we generate the files once then never touch them again.
Unlike the documentation they're also binary blobs which Git doesn't handle
well, unless you use [Git LFS](https://git-lfs.com/).

To work around these issues I was using two different setups:

- <https://yorickpeterse.com/> and <https://inko-lang.org/> used Cloudflare
  Pages as these sites are always built from source using
  [inko-wobsite](https://github.com/yorickpeterse/inko-wobsite)
- The documentation and release artifacts used two separate Cloudflare R2
  buckets with public website hosting enabled, using a custom domain name to
  make this transparent to clients

While this worked, I was never a fan of it, especially as I've found R2's
pricing structure somewhat confusing. I also never liked how they took a similar
approach to AWS by dangling a carrot in your face, only to say "if you want this
carrot and 200 other things you didn't ask for, you need to pay $200/month". In
case of Cloudflare that carrot could be something as simple as "website metrics
that aren't useless".

In 2025 two things happened that made me decide it was time to move away from
Cloudflare and US provided services (where possible):

- Several high-profile outages that lead to many Cloudflare services being
  unavailable for _hours_, including my websites
- The United States decided the best course of action was to screw over all its
  allies, kidnap a president, consider invading Greenland, and do a whole bunch
  of other dumb things

With that in mind I spent the last few months looking into alternative hosting
providers and technology stacks. "Just get to the point Yorick!" OK OK, I hear
you, let's get started.

## [Table of contents]{toc-ignore}

::: toc
:::

## Immutable infrastructure

I've been a fan of immutable infrastructure ever since first introduced to it
back in 2012. Back then I was working for a small company that did a lot of
scraping and analysis of travel reviews. The company used AWS and made heavy use
of EC2 spot instances. To allow for fast deployments, the VM images contained
everything they needed to run our applications. Upon first boot each VM would
download the necessary service(s) to run from S3 and start them.

To apply server updates we'd build a new VM. I think this part was still
somewhat manual. I don't think [Packer](https://developer.hashicorp.com/packer)
was around yet, and we certainly didn't use [Chef](https://www.chef.io/) or
[Ansible](https://www.redhat.com/en/ansible-collaborative). I guess it was a
combination of shell scripts and manual work. To deploy the update we'd
gradually roll it out by deploying new servers, replacing the old ones in the
process.

The resulting setup was a semi immutable setup: downloading of applications
would mutate the server (but only upon boot), but everything else was provided
by the VM image.

The benefit of such a setup is being able to quickly deploy new servers, without
the need for centralized configuration management systems, and a more
deterministic environment as deploying the same image 10 times should produce
the same results 10 times.

While these ideas have been around forever, the process of building immutable
server images has historically been rather clunky and often tied to specific
cloud hosting providers. In recent years there's been a push in the Linux
ecosystem towards more immutable distributions and infrastructure, with some
examples being [Fedora
Silverblue](https://fedoraproject.org/atomic-desktops/silverblue/), [Fedora
CoreOS](https://fedoraproject.org/coreos/), [Bazzite](https://bazzite.gg/), and
[whatever systemd is doing](https://0pointer.net/blog/fitting-everything-together.html).

## Tools for immutable infrastructure

Wanting to use something similar to what I worked with back in 2012, I spent a
few weeks evaluating different tools for building immutable infrastructure:

- [Poudriere](https://github.com/freebsd/poudriere) and FreeBSD, as it has
  support for building both [initial images and ZFS boot environments for
  updating an existing
  system](https://klarasystems.com/articles/building-customized-freebsd-images/)
- [mkosi](https://mkosi.systemd.io/), a tool from the systemd project used for
  building custom Linux distribution images
- [Fedora bootable containers /
  bootc](https://docs.fedoraproject.org/en-US/bootc/getting-started/), a way of
  building OS images and updates using OCI containers

For each tool I tried to build an image to provision a new OS, and an image of
sorts to update it. The resulting source code is found [in this Git
repository](https://github.com/yorickpeterse/os-image-builders).

### FreeBSD and Poudriere

The first tool I tried was Poudriere. While Poudriere is primarily used for
building FreeBSD package repositories it's also able to produce OS images and
ZFS based update images. There's also
[NanoBSD](https://docs.freebsd.org/en/articles/nanobsd/) that's been around
since 2006. I chose not to look into NanoBSD because it seems focused on
building images for e.g. USB sticks using UFS, and because from what I could
find it builds everything from source rather than reusing FreeBSD's package
manager to install existing packages where possible.

The experience of using Poudriere was mixed. For example, the command you need
to run to build an image is pretty simple:

```bash
poudriere image \
    -j custom-image \         # The name of the jail to use
    -p latest \               # The ports tree to use
    -n custom \               # The name of the image to build
    -h freebsd-custom \       # The hostname for the image (not required)
    -s 10g \                  # The size of the disk image
    -w 1g \                   # The size of the swap partition
    -f ./packages.txt \       # A list of packages to install
    -t zfs+gpt \              # Produce a ZFS disk image with a GPT layout
    -A hooks/post-build.sh \  # A post-build script to run
    -c overlay \              # A directory of files to copy into the image
    -o build                  # The directory to store output files in
```

In contrast, I spent quite some time fighting the configuration file Poudriere
requires to work in the first place. I ended up with the following:

```
# Settings that I changed:

# The default name of the root pool. Change this if you use something else.
ZPOOL=zroot

# Where to download data from.
FREEBSD_HOST=https://download.FreeBSD.org

# I changed this from the default (/usr/ports) because otherwise Poudriere
# starts screaming about a "distfiles" directory not existing. So much for
# sensible defaults.
DISTFILES_CACHE=/usr/local/poudriere/ports

# Without this Poudriere tries to build using `nobody:nobody` which will then
# fail. For some reason this setting is ignored by regular poudriere but honored
# by poudriere-devel. OK then?
BUILD_AS_NON_ROOT=no

# The "pkg" branch to fetch from, in this case the latest branch instead of
# quarterly so we actually get updates in a reasonable timeframe.
PACKAGE_FETCH_BRANCH=latest

# The base URL to fetch from. DO NOT use "pkg+https..." or something like that
# because Poudriere will silently accept it and then just fail to fetch
# packages, but not provide you with a reasonable error message of some sort.
# See https://forums.freebsd.org/threads/problem-with-poudriere-and-packages-fetch.99072/
# for more details.
PACKAGE_FETCH_URL=https://pkg.freebsd.org/\${ABI}

# Settings that I didn't change and were uncommented by default:

RESOLV_CONF=/etc/resolv.conf
BASEFS=/usr/local/poudriere
USE_PORTLINT=no
USE_TMPFS=yes
```

I'm not the only one [that ran into issues while configuring
Poudriere](https://forums.freebsd.org/threads/problem-with-poudriere-and-packages-fetch.99072/).
A big source of frustration here is that if Poudriere is given the wrong
configuration it will accept the value and produce an error message that amounts
to "Something went wrong". This is further complicated by Poudriere's lacking
documentation, especially when it comes to its various imaging related features.

There are also issues with Poudriere insisting to build packages from source
even when you tell it to use existing binary packages. [This pull
request](https://github.com/freebsd/poudriere/pull/1148) from 2024 is supposed
to fix that (at least based on what I could find on the FreeBSD forums and
such), but it never got reviewed or merged. I ran into this issue myself when
Poudriere decided to build FreeBSD's own package manager from source in spite of
the above configuration that should cause it to use pre-built packages instead.
To resolve that I had to explicitly add `pkg` to the list of packages to
install (using the `packages.txt` file used by the `poudriere image` command).

In the end my conclusion is that while the combination of FreeBSD and Poudriere
seems interesting, it's sorely lacking in the polishing and documentation
department, and that's ignoring the many challenges you'll face by using FreeBSD
instead of Linux, something I wrote about
[here](/articles/a-brief-look-at-freebsd/) and
[here](/articles/installing-freebsd-15-on-my-desktop/). You can find some
additional notes about my experience with Poudriere
[here](https://github.com/yorickpeterse/os-image-builders/tree/main/poudriere#caveatsrandom-notes).

### FreeBSD and bsdinstall

Besides experimenting with Poudriere I also experimented with using `bsdinstall`
(provided by FreeBSD itself) and raw jails, hoping this would allow me to work
around the issues of Poudriere.

This process was frustrating because while all the pieces necessary seem to be
there, `bsdinstall` doesn't appear to be built with unattended installations in
mind, or at least doesn't consider it a primary use case. For example,
`bsdinstall` itself always shows a TUI interface during the installation process
which is something you _don't_ want when running your build in an unattended
manner (e.g. as part of a CI job).

To avoid this issue you have to use the underlying commands directly
(`bsdinstall scriptedpart`, `bsdinstall mount`, `bsdinstall bootconfig`, etc).
Even when doing this the `bsdinstall scriptedpart` command still pops up a TUI,
even if the process is fully automated.

While I was able to produce a disk image I wasn't able to get it to boot. Since
this was _just_ the initial image and I'd still have to figure out how to
produce ZFS boot environment images, I decided I had enough of FreeBSD and move
on. If you're curious, you can find the failed experiment
[here](https://github.com/yorickpeterse/os-image-builders/tree/main/bsdinstall).

### mkosi

mkosi is a tool by the same people that brought us systemd. Two types of outputs
can be produced using mkosi: disk images (raw images, qcow images, etc), and
images for specific partitions that may be consumed by
[systemd-sysupdate](https://www.freedesktop.org/software/systemd/man/latest/systemd-sysupdate.html)
to update an existing system.

Getting started with mkosi wasn't too bad: create a configuration file, run
`mkosi build`, ignore all the noise it writes to STDOUT and there you have it: a
bootable disk image that you can then try in a VM using the `mkosi vm` command.
Neat!

Going beyond the basics turned out to be a challenge though. For example, the
manual pages cover the various options in great detail but are sorely lacking
when it comes to simple end-to-end examples. There also aren't many articles
about using mkosi and the few that I did find either used Nix such that they
didn't make any sense to me, or they were years old and no longer compatible
with the latest version of mkosi.

One practical problem I ran into is that the order of sections in the
configuration file matters: if you customize the initrd/initramfs image the
`Output` section _must_ come before the `Content` section so settings in the
`Content` section can refer to values from the `Output` section. Trying to
figure out why things weren't working before I realized this was certainly
"fun".

I'm also not a fan of how systemd-sysupdate applies updates: you have to ship
what is essentially an image of an entire partition to hosts that need to be
updated. If that partition contains 10 GiB of data then _every update_ will be
10 GiB, even if you only changed a tiny configuration file. Compression may help
here but will likely be of limited help. Perhaps there's some magical option to
work around this but I wasn't able to find any. To make things worse, I never
actually got the updating part to work and just gave up. You can find some
additional notes on this
[here](https://github.com/yorickpeterse/os-image-builders/tree/main/mkosi#random-notes).

There's also the larger issue of systemd lock-in. Don't get me wrong, I like
systemd as an init system and process supervisor, something it does a _much_
better job at than anything that came before. What I don't like is how there's
an ever increasing suite of systemd-something tools with questionable reasons
for their existence (for example why is
[systemd-homed](https://systemd.io/HOME_DIRECTORY/) a thing?). Perhaps I'm wrong
here, but either way I'd rather not depend too much on the systemd suite outside
of using it as an init and process supervisor.

This means that mkosi wouldn't cut it either, so on to the next tool!

### bootc

Bootable containers and specifically [bootc](https://bootc-dev.github.io/bootc/)
is an interesting new way of building disk images and updates for image based
systems. Using the same approach used for building OCI containers (which you
either love or hate) you can now build an initial disk image _and_ an update
image. The update images use the same technology as OCI containers (because they
are OCI containers) and thus you're able to benefit from incremental updates by
only downloading new or changed layers.

Using the 10 GiB partition example from earlier, an update to such a system
wouldn't produce a 10 GiB update but rather an update the sum size of all
affected layers. If you're smart enough to order your layers such that more
frequently changed layers come last, you can drastically reduce the size of
updates. Clever use of layers also speeds up the build process as you only need
to rebuild what changed.

Getting started took a bit of effort though, as with many Fedora related
projects the documentation around bootc is messy. And just as with Fedora's
package tooling there isn't just one tool that you have to familiarize yourself
with, instead there's a range of projects that are either deprecated,
experimental and/or not well documented.

I actually gave up on bootc initially but later came back to it and managed to
power my way through the remaining challenges. Who said stubbornness is a bad
thing?

In fact, this website is running in a container hosted on a bootc powered
server. Thanks to bootc I can rebuild the server from scratch (or just update
it) in a matter of minutes. I can also test my changes locally in a VM without
the need for a different build process or tool.

Let's take a closer look at how this works, and how you can get started with
bootc yourself without going through the trouble I had to go through to make it
work.

## Getting started with bootc

As mentioned before, bootc turns containers into bootable disk images. Updates
are applied by downloading a new image and staging it such that the next reboot
applies it. Rollbacks are performed by staging an older image followed by a
reboot. At the moment the ecosystem is limited to Fedora and CentOS but a bunch
of people [managed to get it to work for other distributions as
well](https://github.com/bootc-dev/bootc/issues/865), it's just not officially
supported.

To get started we'll need the following:

- [Podman](https://podman.io/): the container engine used to build and run the
  containers locally
- [bootc-image-builder](https://github.com/osbuild/bootc-image-builder): used to
  build initial disk images and installers
- [QEMU](https://www.qemu.org/): to test the disk images in a local VM

To start, let's create a simple Fedora image that contains
[fastfetch](https://github.com/fastfetch-cli/fastfetch):

```
FROM quay.io/fedora/fedora-bootc:43

RUN --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/dnf,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    dnf install --assumeyes --quiet fastfetch

RUN bootc container lint --fatal-warnings
```

The `FROM` command specifies the base image to use for building our container.
The first `RUN` command installs the `fastfetch` package and ensures that
temporary data (e.g. the package manager's cache) isn't persisted in the
container itself. This ensures we don't end up with a container that contains a
bunch of build output we don't need. The last `RUN` command runs a linter during
the build process, and I highly recommend you always include that line as the
last command in your `Containerfile`.

To build the container, save this somewhere in a `Containerfile` and run the
following:

```bash
podman build -t bootc-test .
```

The output will be something along the lines of the following:

```
STEP 1/3: FROM quay.io/fedora/fedora-bootc:43
STEP 2/3: RUN --mount=type=cache,target=/var/cache,sharing=locked     --mount=type=cache,target=/var/lib/dnf,sharing=locked     --mount=type=tmpfs,target=/var/
log     dnf install --assumeyes --quiet fastfetch
Package    Arch   Version       Repository      Size
Installing:
 fastfetch x86_64 2.57.1-1.fc43 updates      1.6 MiB
Installing dependencies:
 yyjson    x86_64 0.12.0-1.fc43 fedora     264.2 KiB

Transaction Summary:
 Installing:         2 packages

Importing OpenPGP key 0x31645531:
 UserID     : "Fedora (43) <fedora-43-primary@fedoraproject.org>"
 Fingerprint: C6E7F081CF80E13146676E88829B606631645531
 From       : file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-43-x86_64
The key was successfully imported.
[1/4] Verify package files              100% |   2.0 KiB/s |   2.0   B |  00m00s
[2/4] Prepare transaction               100% |  44.0   B/s |   2.0   B |  00m00s
[3/4] Installing yyjson-0:0.12.0-1.fc43 100% |  86.5 MiB/s | 265.6 KiB |  00m00s
[4/4] Installing fastfetch-0:2.57.1-1.f 100% |  22.3 MiB/s |   1.6 MiB |  00m00s
--> 674e550d0e18
STEP 3/3: RUN bootc container lint --fatal-warnings
Checks passed: 12
Checks skipped: 1
COMMIT bootc-test
--> 72b0d8f11141
Successfully tagged localhost/bootc-test:latest
72b0d8f11141d11ac4086dd151c4c78e970587d61043e6a08fe538974a098f5b
```

Let's quickly test our container by running the following:

```bash
podman run --rm bootc-test:latest fastfetch
```

On my system this produces the following:

```
             .',;::::;,'.                 root@c486b84564bd
         .';:cccccccccccc:;,.             -----------------
      .;cccccccccccccccccccccc;.          OS: Fedora Linux 43 (Forty Three) x86_64
    .:cccccccccccccccccccccccccc:.        Kernel: Linux 6.18.8-200.fc43.x86_64
  .;ccccccccccccc;.:dddl:.;ccccccc;.      Uptime: 6 hours, 28 mins
 .:ccccccccccccc;OWMKOOXMWd;ccccccc:.     Packages: 530 (rpm)
.:ccccccccccccc;KMMc;cc;xMMc;ccccccc:.    Shell: bash 5.3.0
,cccccccccccccc;MMM.;cc;;WW:;cccccccc,    Display (CS2740): 3840x2160 in 27", 60 Hz [External]
:cccccccccccccc;MMM.;cccccccccccccccc:    CPU: AMD Ryzen 5 5600X (12) @ 4.65 GHz
:ccccccc;oxOOOo;MMM000k.;cccccccccccc:    GPU: Intel Arc A380 @ 2.45 GHz [Discrete]
cccccc;0MMKxdd:;MMMkddc.;cccccccccccc;    Memory: 3.24 GiB / 15.51 GiB (21%)
ccccc;XMO';cccc;MMM.;cccccccccccccccc'    Swap: 132.00 KiB / 8.00 GiB (0%)
ccccc;MMo;ccccc;MMW.;ccccccccccccccc;     Disk (/): 62.49 GiB / 463.16 GiB (13%) - overlay
ccccc;0MNc.ccc.xMMd;ccccccccccccccc;      Local IP (enp7s0): 192.168.1.123/24
cccccc;dNMWXXXWM0:;cccccccccccccc:,       Locale: C
cccccccc;.:odl:.;cccccccccccccc:,.
ccccccccccccccccccccccccccccc:'.
:ccccccccccccccccccccccc:;,..
 ':cccccccccccccccc::;,.
```

Now that we have a working container, let's build a disk image using
bootc-image-builder:

```bash
mkdir -p build
sudo podman build -t bootc-test .
sudo podman run \
    --rm \
    --interactive \
    --tty \
    --privileged \
    --security-opt label=type:unconfined_t \
    --volume ./build:/output \
    --volume /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type raw \
    --use-librepo=True \
    --rootfs ext4 \
    --chown $(id -u):$(id -g) \
    localhost/bootc-test:latest
```

"Woah! What's all this business?" you may wonder. Well, first we need to run
the commands as root because bootc-image-builder does certain things that
require a privileged container and privileged containers require the user to
have root access. [bcvk](https://github.com/bootc-dev/bcvk) is supposed to
remove the need for root and make this process easier, but I found it to be a
buggy mess. Perhaps this has something to do with large portions of it being
written by Claude Code. Either way, we're going to stick to bootc-image-builder
since it's the least immature option available.

The options such as `--security-opt` and `--volume` are all necessary to give
bootc-image-builder the permissions it needs to operate. The more interesting
options are the following:

- `--type raw`: we're building a raw disk image
- `--use-librepo=True`: speed up the build process
- `--rootfs ext4`: use ext4 as the root file system, necessary when building a
  Fedora based container
- `--chown ...`: set the permissions to the current user (before the `sudo`
  invocation) so the image isn't owned by `root`

::: note
The use of `--use-librepo=True` instead of `--use-librepo True` is deliberate as
without the `=` you'll get an incorrect argument error. Why this is the case I
don't know.
:::

The last argument is the qualified name of our container to turn into an image.
If you're building a local container you _must_ include the repository name (=
`localhost`), otherwise bootc-image-builder won't be able to find the image for
some reason.

Building a disk image using the above commands should take a few minutes or so
on commodity hardware. Once done your newly built image is found in the `build`
directory:

```bash
$ tree build
build
├── image
│   └── disk.raw
└── manifest-raw.json

2 directories, 2 files
```

To test our image in a VM, run the following:

```bash
qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 4 \
    -m 4096 \
    -bios /usr/share/OVMF/OVMF_CODE.fd \
    -net user,hostfwd=tcp::2200-:22 \
    -net nic \
    -snapshot build/image/disk.raw
```

::: note
This command assumes the BIOS/UEFI firmware file `/usr/share/OVMF/OVMF_CODE.fd`
exists. Depending on your system that file may be located elsewhere. You can
also just remove the `-bios` option as it's not strictly required.
:::

This starts a new QEMU VM with 4 CPU cores and 4 GiB of memory. SSH connections
to port 2200 on the host are forwarded to port 22 on the VM. The use of
`-snapshot` means the VM won't update the disk image.

At this point you may ask yourself "Wait, who do I log in as?". That's the
wonderful thing, you don't! Jokes aside, by default there's a `root` user but it
doesn't allow you to log in through the console. Let's see how we can fix that.

## User management

User management in bootc is a little different, and arguably not as fleshed out
as it should be. The issue is that adding users modifies state such as
`/etc/shadow` but those files are _also_ considered as locally mutable on the
host you'll deploy your image to. What this means is that if the host modifies
such a file and a future update also modifies it, the host retains its version
and ignores the changes introduced by the update. In other words, you basically
_don't_ want to ever change files in `/etc` that you may also update through
your image.

The [bootc documentation briefly mentions a few
approaches](https://bootc-dev.github.io/bootc/building/users-and-groups.html),
but I didn't find it to be that helpful. What I recommend is to _not_ add any
users in the container (be it using `adduser`, `systemd-sysusers` or some other
mechanism). For servers you use the `root` account over SSH and disable password
based authentication. For desktops you'd create users as part of the
installation process using the
[Anaconda](https://anaconda-installer.readthedocs.io/en/latest/) installer (more
on that later).

Let's update our `Containerfile` so we can log in using SSH. First we'll create
a directory for the files to copy into the container:

```bash
mkdir -p overlay/etc/ssh/keys/
mkdir -p overlay/etc/ssh/sshd_config.d/
```

Next we'll create `overlay/etc/ssh/sshd_config.d/10-custom.conf` with the
following contents:

```
AuthorizedKeysFile .ssh/authorized_keys /etc/ssh/keys/%u
PasswordAuthentication no
PermitRootLogin yes
```

This disables password authentication over SSH, allows logging in as the root
user and configures `/etc/ssh/keys/USER` as an extra source for
`authorized_keys` files. This allows us to change the list of keys over time as
part of the image and potentially add keys for different users, all in a single
easy to find place.

Next, create `overlay/etc/ssh/keys/root` and add the appropriate public keys to
this file. For example, this is what I use:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAtIdG1mSd5MRlfWiy0n7XF3K3s+yaq26qeur7LVgJFT desktop
ssh-ed25519 AAAC3NzaC1lZDI1NTE5AAAAIIZQJ5WP5Z3epZU4gN+sXczNSm3DB3NsYRGU0WMgSNTj laptop
```

With the files in place, let's edit the `Containerfile` to copy these files into
the container:

```
FROM quay.io/fedora/fedora-bootc:43

RUN --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/dnf,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    dnf install --assumeyes --quiet fastfetch

COPY overlay/ /

RUN bootc container lint --fatal-warnings
```

The newly added `COPY` command copies everything (recursively) from the
`overlay` directory into the root of the container, such that `overlay/etc/foo`
becomes `/etc/foo` in the container.

Now let's build the container to make sure the new `COPY` command works:

```bash
podman build -t bootc-test .
```

This produces the following:

```
STEP 1/4: FROM quay.io/fedora/fedora-bootc:43
STEP 2/4: RUN --mount=type=cache,target=/var/cache,sharing=locked     --mount=type=cache,target=/var/lib/dnf,sharing=locked     --mount=type=tmpfs,target=/var/
log     dnf install --assumeyes --quiet fastfetch
--> Using cache 674e550d0e189697b51ad6fc431d57435b887fd623de93f7f2cf55f3f836f4d6
--> 674e550d0e18
STEP 3/4: COPY overlay/ /
--> 0bf3001b91e7
STEP 4/4: RUN bootc container lint --fatal-warnings
Checks passed: 12
Checks skipped: 1
COMMIT bootc-test
--> 6d6f9607e100
Successfully tagged localhost/bootc-test:latest
6d6f9607e10029b48a952d5def7d2adc41db2c64b6d428bd8d5ec07acda1ccb7
```

We can now rebuild our disk image and test it in a VM using the
bootc-image-builder and qemu-system commands from earlier. Once the VM is
running you can SSH into it using the following command:

```bash
ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile=/dev/null" -p 2200 root@localhost
```

The `-o` options are used so we don't save the VM host in `~/.ssh/known_hosts`
and to disable host verification. This way we don't end up with scary warnings
when we SSH into the VM each time we rebuild its image, and we don't need to
explicitly approve the connection.

If all went well you should now be able to log in to your VM without the need
for a password.

Besides including SSH keys you'll likely want to include other files in the
container, such as firewall configuration, secrets, [Podman Quadlets][quadlets]
and more. The approach of using a dedicated directory to copy into the container
(the `overlay` directory above) is by far the easiest approach of doing so, and
probably good enough for most cases.

## Deploying the initial image

OK, so we have our image and confirmed it works by running it in a VM. How do we
get this on a server? Well, this depends on the hosting provider. For example,
[Hetzner](https://www.hetzner.com/) servers come with a Debian based rescue
system that you can SSH into. Using this rescue system you can then stream the
image directly to the target disk as follows:

```bash
cat build/image/disk.raw | \
    zstd -3 | \
    ssh \
        -o "UserKnownHostsFile=/dev/null" \
        -o "StrictHostKeyChecking no" \
        root@SERVER 'zstd --decompress | dd of=/dev/sda bs=1M status=progress'
```

Using this command we send a compressed image over SSH to the server running our
rescue system, then decompress it on the fly and write the output directly to
the target disk. We also disable strict host checking and updating of
`~/.ssh/known_hosts` since rescue systems typically have their own SSH host keys
while running on the same IP/host, and SSH won't like that.

The use of compression is deliberate: bootc-image-builder is configured to
always produce disk images that are at least 10 GiB in size. While tools such as
`du -hs` will report a smaller size (e.g. 2 GiB), the moment you send that image
over the network you end up transferring 10 GiB of data. By compressing the data
we're able to greatly reduce the amount of data transferred. For example, the
image built thus far is about 2.1 GiB according to `du -hs`. By compressing it I
only need to transfer 1.1 GiB instead of 10 GiB.

For hosting providers without a rescue system the process may be a bit more
tricky. One option is to instead first install Fedora CoreOS (assuming the
hosting provider supports this out of the box) then rebase it to your container
image (see [this
article](https://ryandaniels.ca/blog/bootstrapping-bootc-using-fedora-coreos/)
for an example). This does require that the image is hosted in a container
registry somewhere, which we'll get to in a moment.

## Updating existing servers

So we've deployed the image to a server, we've made some changes to the image
and we want to deploy those changes. To do so there are two options:

1. Build the container image locally and export it using `podman image save`,
   upload it to the server and rebase to the new image
1. Upload the container image to a container registry such as
   [quay.io](https://quay.io/) (if you like Red Hat charging you a premium),
   GitHub (if you like Microsoft charging you a slightly smaller premium), or
   your own (if you like being woken up at 04:00 on a Saturday because the
   registry is down)

### Updates using OCI archives

Let's start with the first option. First we'll start our VM but use the `-drive`
option instead of `-snapshot` to simulate it using an actual disk:

```bash
qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 4 \
    -m 4096 \
    -bios /usr/share/OVMF/OVMF_CODE.fd \
    -net user,hostfwd=tcp::2200-:22 \
    -net nic \
    -drive format=raw,index=0,media=disk,file=build/image/disk.raw
```

Now let's change the `Containerfile` to also install htop:

```
FROM quay.io/fedora/fedora-bootc:43

RUN --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/dnf,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    dnf install --assumeyes --quiet fastfetch htop

COPY overlay/ /

RUN bootc container lint --fatal-warnings
```

For our updates we _don't_ need to use bootc-image-builder, instead we build
them using Podman:

```bash
podman build -t bootc-test .
```

::: note
Building as root isn't necessary for updates, only when using
bootc-image-builder.
:::

Once the image is built we export it as an OCI archive and upload it to the VM
using `scp`:

```bash
podman image save bootc-test:latest \
    --format oci-archive \
    --output "bootc-test-$(date +%s).oci"

scp \
    -o "StrictHostKeyChecking no" \
    -o "UserKnownHostsFile=/dev/null" \
    -P 2200 \
    bootc-test-*.oci root@localhost:~/
```

::: note
Make sure to use `root@localhost:~/` instead of just `root@localhost` otherwise
`scp` will copy the archive to a local _file_ called `root@localhost`, instead
of copying it to the VM.
:::

Then log in to the VM and switch to the new image and reboot the VM:

```bash
ssh \
    -o "StrictHostKeyChecking no" ]
    -o "UserKnownHostsFile=/dev/null" \
    -p 2200 \
    root@localhost 'bootc switch --transport oci-archive --apply bootc-test-*.oci'
```

Once the VM is rebooted you should be able to run `htop`. Don't forget to remove
the `.oci` file!

While this approach technically works, it suffers from a few flaws:

1. Exporting images exports all their layers, so the image we end up deploying
   is larger than necessary (i.e. no incremental updates)
1. `bootc switch` with a local file uses the file name to determine if the image
   is already applied, meaning you have to give each file a unique name (as done
   using the `date` command in the above examples)
1. It's annoying if you need to update multiple servers

### Updates using container registries

The second and better approach is to upload an image to a container registry and
use `bootc update` to download and apply the changed layers. This approach
requires less data to be transferred and makes it easier to update multiple
servers.

For this to work there are two things we'll need. First, when building the image
using bootc-image-builder, the image name must be a qualified name that matches
the one used for our container registry. The reason for this is that `bootc
update` uses that name to pull new updates. If that name happens to be
`localhost/whatever` it won't be able to pull any updates because they
don't exist on the server itself. The second requirement is that if the
container image is hosted in a private registry we'll need to add the necessary
credentials to the image.

Let's for a moment assume you have a private GitHub repository at
`github.com/kitten/mittens` that contains the code used to build your image, and
you're using GitHub's container registry such that the image is available at
`ghcr.io/kitten/kittens:latest`. This means you'd use bootc-image-builder to
build the initial image as follows:

```bash
sudo podman build -t ghcr.io/kitten/mittens:latest .
sudo podman run \
    --rm \
    --interactive \
    --tty \
    --privileged \
    --security-opt label=type:unconfined_t \
    --volume ./build:/output \
    --volume /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type raw \
    --use-librepo=True \
    --rootfs ext4 \
    --chown $(id -u):$(id -g) \
    ghcr.io/kitten/mittens:latest
```

To allow the server to pull the image you'll need to generate a personal access
token with the `read:packages` scope. Let's assume the token value is `hunter2`.
Create the file `overlay/etc/ostree/auth.json` with the following contents:

```json
{
  "auths": {
    "ghcr.io": {
      "auth": "BASE64"
    }
  }
}
```

Replace `BASE64` with the output of the following command:

```bash
echo -n 'your-github-username:hunter2' | base64 --wrap=0
```

This would result in something like this:

```json
{
  "auths": {
    "ghcr.io": {
      "auth": "eW91ci1naXRodWItdXNlcm5hbWU6aHVudGVyMg=="
    }
  }
}
```

If you're wondering why base64 is necessary: I believe this is because it's
Podman that requires it (this configuration file is a Podman configuration file
that bootc just happens to use), but why it uses base64 instead of anything else
I don't know.

With the configuration file in place you can rebuild your image and deploy it
using the methods discussed thus far. From this point on you can update using
`bootc update` instead (using `--apply` to automatically reboot if desired).

By default updates are periodically applied in the background using two systemd
units:

- `bootc-fetch-apply-updates.service`
- `bootc-fetch-apply-updates.timer`

The problem with this approach is that no synchronization across a cluster of
any kind is performed, meaning that if you have 20 bootc servers they'll
possibly reboot all at once (if you're unlucky enough). I don't like systems
that automatically reboot at certain intervals, so I disabled these units:

```bash
systemctl disable \
    bootc-fetch-apply-updates.service \
    bootc-fetch-apply-updates.timer
```

Unless you're OK with your server rebooting some random amount of time after
pushing your container updates, I suggest you do the same. My current approach
(since I only have a single server) is to just run
`ssh root@host 'bootc update --apply'` whenever I want to apply updates.

## Applying temporary changes

Image based deployments are great but sometimes we need to quickly roll out a
temporary change, such as a security update or a firewall configuration change.
Or maybe you need to change something but can't afford to reboot right now.

For this we can use the `bootc usr-overlay` command. Running this command
results in a mutable `/usr` overlay that we can then mutate as if we were using
a regular Linux distribution. This overlay is lost upon a reboot.

Imagine for a moment that our server is performing important work we can't
interrupt right now, but we also need to apply a critical security update. Using
the overlay command we can do something along the lines of the following:

```bash
bootc usr-overlay          # Enable the overlay
dnf update package-name    # Update the relevant package(s)
```

Not only is this useful for quickly applying updates, it's also useful for
desktop environments as it allows you to play around with certain packages
without being forced to work in a [Toolbox](https://containertoolbx.org/) or
[Distrobox](https://distrobox.it/) container.

Of course it's important to keep in mind that the overlay is _temporary_ and
lost upon a reboot, so if you make any changes you need to persist you'll need
to also include them in your image and deploy that image at some point.

## Mutating local state

While the `/usr` tree is immutable, `/etc` and `/var/lib` (and a few other
directories such as `/var/log`) are considered "local mutable state". This means
that changes made on the host remain present between updates. This does come
with a caveat: if both the host and a future image update change the same file
(e.g. `/etc/foo`), the changes on the host are used instead of those introduced
by the image.

This approach can be both useful and annoying. It's useful because you can make
certain changes and have them persisted, such as host specific firewall rules
that live in `/etc/firewalld`. It's annoying because if a file changes when
this isn't expected (e.g. some program decides to reformat its configuration
file when it starts), future updates to that file introduced by the image are
ignored.

The `ostree admin config-diff` command is used to generate a diff of the files
added and modified in `/etc`. Its output will be something along the lines of
the following:

```
M    ld.so.cache
M    machine-id
M    selinux/targeted/active/commit_num
A    alternatives/ld
A    alternatives-admindir/ld
A    issue.d/22_clhm_ens3.issue
A    selinux/targeted/semanage.read.LOCK
A    selinux/targeted/semanage.trans.LOCK
A    ssh/ssh_host_ecdsa_key
A    ssh/ssh_host_ecdsa_key.pub
A    ssh/ssh_host_ed25519_key
A    ssh/ssh_host_rsa_key
A    ssh/ssh_host_rsa_key.pub
A    ssh/ssh_host_ed25519_key.pub
A    systemd/system/multi-user.target.wants/-.mount
A    systemd/system/multi-user.target.wants/boot-efi.mount
A    systemd/system/multi-user.target.wants/boot.mount
A    systemd/system/-.mount
A    systemd/system/boot-efi.mount
A    systemd/system/boot.mount
A    .updated
A    fstab
A    .pwd.lock
A    locale.conf
A    vconsole.conf
A    .rpm-ostree-shadow-mode-fixed2.stamp
A    npmrc
A    mailcap
A    mime.types
```

If you're only interested in modified files, run the following instead:

```bash
ostree admin config-diff | grep '^M'
```

While bootc is supposed to support making `/etc` immutable, doing so [breaks a
bunch of services](https://github.com/bootc-dev/bootc/discussions/1435), and I
remember there being a bunch of other issues with it as well. I personally keep
`/etc` mutable as it makes it easier to test and deploy firewall changes (before
including them in an image update) as the configuration for this resides in
`/etc/firewalld`.

## Building an installer

Building raw disk images works well enough when you can somehow connect to the
target host, such as by using a rescue system. If this isn't possible but you
_can_ mount an ISO somehow, building an Anaconda installer is another option.
Installers are also useful for more advanced host specific configuration such as
disk layouts, adding additional users, etc.

To build an installer we need to do the following things:

1. We need to create a `config.toml` that contains a basic
   [kickstart](https://pykickstart.readthedocs.io/en/latest/kickstart-docs.html)
   configuration to set up the host
1. We need to build a container containing all the dependencies necessary to
   build the installer itself (not the container we want to deploy)
1. We need to build an installer ISO by combining this installer container and
   the container we want to deploy

### Configuring Anaconda

Let's start with a basic installer that sets up a ext4 root disk _without_
encryption:

```toml
[customizations.installer.kickstart]
contents = """
text
zerombr
clearpart --all --initlabel --disklabel=gpt
autopart --noswap --type=plain --fstype=ext4
rootpw --lock

%post --erroronfail
grep \"boot \" /etc/fstab > /etc/fstab-new
mv /etc/fstab-new /etc/fstab
%end
"""
```

The `%post` block is necessary to work around [this
issue](https://github.com/bootc-dev/bootc/issues/971) where Anaconda generates a
broken `/etc/fstab`.

#### Full disk encryption

To enable full disk encryption, use the following instead:

```toml
[customizations.installer.kickstart]
contents = """
text
zerombr
clearpart --all --initlabel --disklabel=gpt
autopart --noswap --type=plain --fstype=ext4 --encrypted
rootpw --lock

%post --erroronfail
grep \"boot \" /etc/fstab > /etc/fstab-new
mv /etc/fstab-new /etc/fstab
%end
"""
```

This will result in the installer asking for a passphrase during the
installation process.

#### Automatic unlocking using a TPM2 device

To automatically unlock the root disk using a TPM2 device, create
`overlay/etc/dracut.conf.d/tpm2.conf` with the following contents:

```
add_dracutmodules+=" tpm2-tss "
```

Then create `overlay/usr/lib/bootc/kargs.d/10-tpm2.conf` with the following
contents:

```
kargs = ["luks.options=tpm2-device=auto,headless=true,tpm2-pcrs=1+3+5+7+12"]
```

The `overlay` directory should now look something like this:

```
$ tree overlay
overlay
├── etc
│   ├── dracut.conf.d
│   │   └── tpm2.conf
│   └── ssh
│       ├── keys
│       │   └── root
│       └── sshd_config.d
│           └── 10-custom.conf
└── usr
    └── lib
        └── bootc
            └── kargs.d
                └── 10-tpm2.conf

10 directories, 4 files
```

Then change the contents of `config.toml` to the following:

```toml
[customizations.installer.kickstart]
contents = """
text
zerombr
clearpart --all --initlabel --disklabel=gpt
autopart --noswap --type=plain --fstype=ext4 --encrypted --passphrase 1234567890
rootpw --lock

%post --erroronfail
grep \"boot \" /etc/fstab > /etc/fstab-new
mv /etc/fstab-new /etc/fstab

echo -n 1234567890 > /tmp/pass.txt
systemd-cryptenroll --wipe-slot tpm2 --tpm2-device auto \
    --tpm2-pcrs 1+3+5+7+12 \
    --unlock-key-file /tmp/pass.txt \
    $(blkid --match-token TYPE=crypto_LUKS --output device)

systemd-cryptenroll --wipe-slot 0 \
    $(blkid --match-token TYPE=crypto_LUKS --output device)

rm /tmp/pass.txt
%end
"""
```

This sets up TPM2 unlocking using systemd-cryptenroll. The passphrase is
temporary and removed by the second call to `systemd-cryptenroll`.

After completing the installation process and booting into the host you'll want
to either add a custom passphrase or generate a recovery key, as the PCR
registers may change. For example, to generate a recovery key:

```bash
systemd-cryptenroll --recovery-key \
  $(blkid --match-token TYPE=crypto_LUKS --output device)
```

If you change the PCR registers in `config.toml` you'll also need to update the
`10-tpm2.conf` configuration file accordingly.

### Building the installer container

There's no pre-built container containing the Anaconda dependencies, so we have
to build our own container. While bootc-image-builder has a dedicated
`anaconda-iso` output option that _doesn't_ require a dedicated container, it's
deprecated (though you wouldn't know unless you [look at the source
code](https://github.com/osbuild/bootc-image-builder/blob/410e3c7412b0858cc47646cda7bfeff6d0f65cb6/bib/internal/imagetypes/imagetypes.go#L29)).

Create an `installer` directory containing a `Containerfile` with the following
contents (based on [this
example](https://osbuild.org/docs/developer-guide/projects/image-builder/usage/#bootc)):

```
FROM quay.io/fedora/fedora-bootc:43
RUN dnf install -y \
     anaconda \
     anaconda-install-env-deps \
     anaconda-dracut \
     dracut-config-generic \
     dracut-network \
     net-tools \
     squashfs-tools \
     grub2-efi-x64-cdboot \
     python3-mako \
     lorax-templates-* \
     biosdevname \
     prefixdevname \
     && dnf clean all

RUN mkdir -p /boot/efi && cp -ra /usr/lib/efi/*/*/EFI /boot/efi
RUN mkdir /var/mnt
```

Then build the container:

```bash
sudo podman build -t bootc-installer installer
```

This step only needs to be done once and not for every update. Changes to
`config.toml` don't require a rebuild of this container either.

### Building the installer

Now we can build the Anaconda installer that deploys our container as follows:

```bash
mkdir -p build
sudo podman build -t bootc-test .
sudo podman run \
    --rm \
    --interactive \
    --tty \
    --privileged \
    --security-opt label=type:unconfined_t \
    --volume ./config.toml:/config.toml:ro \
    --volume ./build:/output \
    --volume /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type bootc-installer \
    --installer-payload-ref localhost/bootc-test:latest \
    --use-librepo=True \
    --rootfs ext4 \
    --chown $(id -u):$(id -g) \
    localhost/bootc-installer:latest
```

Here the `--installer-payload-ref` specifies the qualified name of the container
we wish to deploy, while `localhost/bootc-installer:latest` refers to the
qualified name of the _installer_ container (i.e. the one from the `installer/`
directory). The additional `--volume ./config.toml:/config.toml:ro` option
ensures the configuration file is available to the bootc-image-builder
container.

Building an installer this way can take a while, and if you're using a laptop it
may attempt to fly away. For example, on my Framework 13 with a Ryzen 5 7640U it
takes around 2.5 minutes during which the CPU temperature reaches a crisp 99C.

Once built we can test the ISO using a VM as follows:

```bash
truncate -s 10G iso-disk.raw
qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 4 \
    -m 4096 \
    -bios /usr/share/OVMF/OVMF_CODE.fd \
    -net user,hostfwd=tcp::2200-:22 \
    -net nic \
    -cdrom build/bootiso/install.iso \
    -drive format=raw,index=0,media=disk,file=iso-disk.raw
```

When booting choose "Install Fedora Linux" and the installation process begins.
Once complete, press Enter to reboot into the new installation.

## Managing packages and services

So we now know how to build a basic image and installer and we can SSH into it.
What about enabling additional services such as firewalld?

The approach is pretty simple: in your `Containerfile` you use
`systemctl enable` and `systemctl disable` to enable and disable the appropriate
services respectively. For example:

```
FROM quay.io/fedora/fedora-bootc:43

RUN --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/dnf,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    dnf install --assumeyes --quiet fastfetch firewalld

COPY overlay/ /
RUN systemctl enable firewalld
RUN bootc container lint --fatal-warnings
```

This would install and enable firewalld, which isn't installed by default when
using the fedora-bootc base image.

Using the above approach can get a little tedious to work with as the list of
packages and/or services increases. I prefer storing such lists in text files
and mounting those into the container:

```
FROM quay.io/fedora/fedora-bootc:43

RUN --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/dnf,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=bind,source=dnf,target=/dnf,z \
    dnf install --assumeyes --quiet $(< /dnf/install.txt) >/dev/null

COPY overlay/ /

RUN --mount=type=bind,source=systemd,target=/systemd,z \
    systemctl disable $(< /systemd/disable.txt) && \
    systemctl enable $(< /systemd/enable.txt)

RUN bootc container lint --fatal-warnings
```

Using this setup you can add the packages to install to `dnf/install.txt` and
those to remove to `dnf/remove.txt`. Services listed in `systemd/disable.txt`
are disabled and those listed in `systemd/enable.txt` are enabled. For example,
here's the contents of `dnf/install.txt` that I use for building my web server:

```
firewalld
htop
rsync
zram-generator-defaults
```

Do note that the above approach will fail if one of the files is empty. For
example, if you don't need to remove any packages you should remove the `dnf`
line that uses `dnf/remove.txt` or it will produce an error.

Those familiar with systemd and specifically [systemd
presets](https://systemd.io/PRESET/) may wonder if they can't use that instead
of the text file approach. The short answer is that this isn't reliable enough
as presets are _only_ applied upon _first boot_. This means that if you
introduce new presets in a future update, they'll be ignored. The text file
approach doesn't suffer from the same problem, so I recommend using this
approach instead.

## Running applications and containers

There are two ways to run an application in a bootc environment: install them
when building the container and run them the usual way (e.g. as a dedicated
user), or run them inside a Podman container. I _highly_ recommend taking the
second approach for two reasons:

1. You don't have to fiddle with creating users in the container (e.g. using
   [systemd-sysusers](https://www.freedesktop.org/software/systemd/man/latest/systemd-sysusers.html))
1. You can take advantage of the isolation features provided by Podman to
   isolate the application from the rest of the system

Fortunately, running containers in a bootc environment is pretty easy thanks to
[Podman Quadlets][quadlets]. To add a container, create a `NAME.container` in
`overlay/etc/containers/systemd/` using the following template:

```
[Container]
ContainerName=CONTAINER-NAME
Image=QUALIFIED-IMAGE-NAME
Pull=missing
UserNS=keep-id

[Unit]
After=network-online.target

[Service]
Restart=on-failure
RestartSec=60

[Install]
WantedBy=default.target
```

`Pull=missing` means that if the container image isn't present it's pulled from
the source specified in the `Image` setting. Depending on your needs you may
want to change this to `Pull=newer` to also update it when a newer version is
available. I recommend only doing so with container images you control.

The `UserNS=keep-id` setting is important. Using the setup introduced thus far,
the containers are started by the `root` user, which is what you typically want
in a server environment. The `UserNS` setting ensures that the container is
given its own namespace (instead of reusing the `root` namespace) while the IDs
are still mapped to the `root` user ID on the host. This is important because it
allows such containers to share files using Podman volumes, without file
ownership getting messed up. In other words: you get isolation but without the
headaches.

The `Unit` section ensures the container starts after the network is available,
which may or may not be necessary for your use case. The `Service` section
ensures the container is restarted upon a failure, using a 60 second interval
between restarts. The default is 100 msec, which may cause the host to go nuts
if there's an error (e.g. you gave it a non-existing image name) as it will
_constantly_ try to restart the container.

The `Install` section ensures the container is enabled upon boot. This ensures
we don't have to explicitly start the container using `systemctl`.

To see the available quadlets and their status, run `podman quadlet list` on the
host. For example, this is the output for my web server:

```
$ podman quadlet list
NAME                     UNIT NAME              PATH ON DISK                                     STATUS          APPLICATION
certbot.container        certbot.service        /etc/containers/systemd/certbot.container        inactive/dead
shost.container          shost.service          /etc/containers/systemd/shost.container          active/running
ssh-container.container  ssh-container.service  /etc/containers/systemd/ssh-container.container  active/running
```

To get the status of a specific quadlet, use `systemctl status NAME`. For
example:

```
$ systemctl status shost.service
● ssh-container.service
     Loaded: loaded (/etc/containers/systemd/ssh-container.container; generated)
    Drop-In: /usr/lib/systemd/system/service.d
             └─10-timeout-abort.conf
     Active: active (running) since Tue 2026-02-10 03:14:36 UTC; 11h ago
 Invocation: f6b0b884b62340bc872cee29a8037c06
   Main PID: 1117 (conmon)
      Tasks: 3 (limit: 4423)
     Memory: 55.9M (peak: 64.9M)
        CPU: 12.601s
     CGroup: /system.slice/ssh-container.service
             ├─libpod-payload-2550d67a0cd564fcfa3075875169e8cb648f9254b92ba4f069548c87ab1c3b88
             │ ├─1122 bash /usr/local/bin/sshd
             │ └─1173 "sshd: /usr/sbin/sshd -D [listener] 0 of 10-100 startups"
             └─runtime
               └─1117 /usr/bin/conmon --api-version 1 -c [...]

Feb 10 03:14:32 fedora systemd[1]: Starting ssh-container.service...
Feb 10 03:14:34 fedora podman[1047]: 2026-02-10 03:14:34.166096899 +0000 UTC m=+1.165587651 container create [...]
Feb 10 03:14:34 fedora podman[1047]: 2026-02-10 03:14:34.126733649 +0000 UTC m=+1.126224421 image pull [...]
Feb 10 03:14:36 fedora podman[1047]: 2026-02-10 03:14:36.326839872 +0000 UTC m=+3.326330634 container init [...]
Feb 10 03:14:36 fedora podman[1047]: 2026-02-10 03:14:36.330256351 +0000 UTC m=+3.329747113 container start [...]
Feb 10 03:14:36 fedora systemd[1]: Started ssh-container.service.
Feb 10 03:14:36 fedora ssh-container[1047]: 2550d67a0cd564fcfa3075875169e8cb648f9254b92ba4f069548c87ab1c3b88
```

## My new hosting setup

TODO

[quadlets]: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
