---
title: Switching to Fedora Silverblue
date: "2023-03-02 23:43:38 UTC"
---

For the last 10 years or so, [Arch Linux](https://archlinux.org/) has been my
Linux distribution of choice. The early years were a bit rough, and the process
of moving to systemd wasn't without its challenges either, though the experience
has improved dramatically since then. In spite of these improvements, certain
issues persisted, such as having to manually perform update related steps every
now and then, fixing broken packages after an update, updating packages in a
particular order (e.g. `archlinux-keyring` requiring an update before you can
update other packages), and more.

Arch being a rolling release distribution also means that you're not supposed to
install a new package without first updating your existing packages (at least
for libraries). That is, `sudo pacman -S some-package` _may_ lead to problems,
so it's recommended to use `sudo pacman -Syu some-package` instead (see [this
section](https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported)
for more details). It's not a deal breaker, but it's yet another thing to keep
in mind.

Perhaps the most annoying part is that package updates aren't tested all that
well, if at all; or at least it feels that way. Linux kernel updates in
particular had a tendency to cause issues on my laptop. I remember one
particular instance where a bug in the Intel drivers (or something in the kernel
itself, I can't quite remember) resulted in weird screen flickering/artifacts,
requiring a rollback to a previous kernel version. Pinning packages using
`IgnorePkg` was the usual workaround, but it's not a suitable long-term solution
as updated packages may not work with older versions of the packages you're
ignoring/pinning.

Long story short, over the years I realised I care more for a reliable and easy
(or easier) to use distribution, instead of a distribution that gives you
maximum control.

This is where [Fedora](https://getfedora.org/) comes in, and specifically
[Fedora Silverblue](https://silverblue.fedoraproject.org/). Fedora has been
around for years, and I've been keeping my eyes on it for a while. A while back
I built a tiny computer to run some home automation software, and I decided to
use [Fedora Server](https://getfedora.org/en/server/) for it. This gave me the
chance to try Fedora without it getting in the way.

I ended up enjoying this enough that I decided to move my Linux installations to
Fedora. As I mainly work on my desktop (still running Arch Linux at the time of
writing), I decided to migrate my laptop first. I decided to go with Silverblue
as I like the idea of an immutable desktop and the ability to roll back updates
_without_ leaving behind a dirty state.

The first step was to do some research into potential issues I might encounter.
Through this I found a few potential issues/challenges to deal with:

- Fedora ships a mirror of Flathub instead of using Flathub directly. You can
  and probably should disable this. I found and used [this Reddit
  post](https://www.reddit.com/r/Fedora/comments/z2kk88/fedora_silverblue_replace_the_fedora_flatpak_repo/)
  as a reference to do so.
- Fedora ships with
  [systemd-oomd](https://man.archlinux.org/man/systemd-oomd.8), and apparently
  this has a tendency to cause more problems than it solves
  (see [here](https://www.reddit.com/r/Fedora/comments/tcsen3/is_there_a_way_to_permanently_disable_systemdoomd/)
  and [here](https://www.reddit.com/r/Fedora/comments/10s06fd/why_is_systemdoomd_still_a_thing/)).
  I ended up disabling it using
  `sudo systemctl stop systemd-oomd && sudo systemctl disable systemd-oomd && sudo systemctl mask systemd-oomd`.
- [Apparently TRIM support isn't handled properly when using full disk
  encryption](https://www.reddit.com/r/Fedora/comments/l944bb/is_it_possible_to_install_silverblue_on_an/gnmktzx/)
  on Silverblue. The solution is to add `rd.luks.options=discard` to your kernel
  arguments.
- A few packages I needed aren't available in the official repositories or
  [copr](https://copr.fedorainfracloud.org/coprs/), more on that later.
- I read something about Flatpak (and thus the Firefox Flatpak) not supporting
  [U2F](https://en.wikipedia.org/wiki/Universal_2nd_Factor), meaning I wouldn't
  be able to use my YubiKey with Firefox. This turned out to work just fine.

Having determined these issues hard workarounds that I could live with, I
proceeded with the installation process. The installation process itself was
easy and ran without any issues, discussed below in no particular order.

After the installation finished I applied the necessary workarounds/fixes for
the above issues, such as disabling `systemd-oomd`. Unfortunately, this is where
I ran into some new and unexpected problems, though not all are exclusive to
Silverblue.

## Getting my keyboard layout to work

For my desktop I use a split keyboard that uses the [Colemak
Mod-DH](https://colemakmods.github.io/mod-dh/) ortholinear layout. On my laptop
I use the same layout, through combination of a custom
[xkb](https://gitlab.freedesktop.org/xkeyboard-config/xkeyboard-config) keyboard
layout and remapping the keycaps on my keyboard:

<img src="/images/switching-to-fedora-silverblue/keyboard.jpg" alt="Laptop keyboard" loading="lazy" width="500" />

While the xkb project includes support for the Colemak Mod-DH layout, it only
supports the variant where the bottom-left keys are XCDVZ, whereas the
ortholinear version uses ZXCDV. I don't quite remember why the ZXCDV version
isn't included, but I recall the reason being along the lines of "the XCDVZ
layout is better for staggered keyboards". I guess I'm the only person wanting
to use the same layout everywhere? Either way, my solution was to create a
custom layout and be done with it.

For the Arch installation I just created the necessary files (based on [this
article](http://who-t.blogspot.com/2020/09/user-specific-xkb-configuration-putting.html))
in the right place. I then performed the necessary magical incantations (which I
of course couldn't remember) to get this working everywhere.

For Silverblue I started off with the same setup, placing the files in
`~/.config/xkb` instead of placing them in `/usr/share/X11/xkb`. While GNOME
picked up the files just fine, I couldn't get this to work for the LUKS unlock
screen or when using a console/TTY started using `Alt` and a function key. I
also wasn't able to get GDM to use the layout. Placing the files in `/usr/share`
wasn't an option either, as it's read-only on Silverblue.

Getting this to work took an entire evening, and required a few distinct steps.
First, I build an [RPM
package](https://copr.fedorainfracloud.org/coprs/yorickpeterse/colemak-dh-ortho/)
to move these files into the right place in `/usr/share`. I then used
`rpm-ostree` to [layer the
package](https://docs.fedoraproject.org/en-US/iot/add-layered/) onto the base
image.

To get the console working I set `KEYMAP` in `/etc/vconsole.conf` to
`colemak_dh_ortho`. The default initramfs of Silverblue ignores changes to this
file, so to get this working I had to run `rpm-ostree initramfs --enable`. This
enables regenerating of the initramfs every time you create a new rpm-ostree
deployment, ensuring the necessary files are part of the initramfs. The downside
is that commands such as `rpm-ostree install` and `rpm-ostree update` take quite
a bit longer to finish. I also added `vconsole.keymap=colemak_dh_ortho` to my
kernel arguments for good measure, but I'm not sure this is necessary.

The final piece of the puzzle was to get GDM working, which for some reason just
_refused_ to use this layout. I'm still not sure what exactly solved it, but I
think it was running `gsettings set org.gnome.libgnomekbd.keyboard layouts '["colemak_dh_ortho","us"]'`
followed by another reboot.

And all that took was well over six hours.

## Getting rid of GNOME Software

GNOME software is the primary way of installing software through a GUI on
Fedora. I ran into two issues with it, though both are not that big of a deal.

First, it's quite clunky to use when it comes to uninstalling software: when you
remove a program, the list of installed programs is refreshed a few seconds
after the removal finishes, showing a spinner while doing so. This made
removing multiple programs a pain, as the spinner would typically show up just
as I was about to click on the "remove" button of the next program I wanted to
remove.

The second problem is that GNOME Software leaks memory like a sieve, and after
several hours of using my laptop (I wasn't even using GNOME Software during that
time) I found it had eaten up close to 1 GiB of memory.

[grug](https://grugbrain.dev/) tired of software leak memory. grug want reach
for club, but grug remember easier just remove GNOME software and use terminal,
so grug run `rpm-ostree remove gnome-software gnome-software-rpm-ostree`. Memory
leak not worth grug's time and energy.

## rpm-ostree and dnf are slow

DNF being slow is well known in the Fedora community. While DNF5 is supposed to
improve this, I'll believe it when I see it. For me the process of installing
and removing packages is fast enough, but refreshing mirror/package metadata is
frustratingly slow.

What I didn't expect is for rpm-ostree to also be as slow as a snail. While you
can stage updates in the background and will do most of your package related
work in a container, you still have to interact with rpm-ostree every now and
then. Coming from Arch Linux where `pacman` is super fast, the experience leaves
a lot to be desired. To illustrate, for this article I ran `rpm-ostree update`
and it took just over two minutes to upgrade a mere two packages. Of course I'm
aware rpm-ostree does more than just upgrading two packages, but I'm not
convinced this can't be done any faster.

## Building packages for Fedora is frustrating

A few packages I needed were missing: [Lua language
server](https://github.com/LuaLS/lua-language-server),
[Stylua](https://github.com/JohnnyMorganz/StyLua), the Source Code Pro fonts
with support for Nerd Fonts, [neovim-gtk](https://github.com/Lyude/neovim-gtk/),
and an up-to-date [ruby-install](https://github.com/postmodern/ruby-install/).

Wanting to do the right thing I decided to read up on creating RPM packages and
setting up a copr repository; something I had to do for my keyboard layout
anyway. The experience was deeply frustrating: documentation on RPM packages is
scattered across different websites, some new and some ancient. These websites
also manage to somehow present you a _ton_ of text, but not actually explain
anything useful at all.

<div class="note">
The following is a brief rant on RPM packaging. If you're not interested
in reading it, the summary is this:

The process of building an RPM is confusing and frustrating, especially compared
to how easy it's to build a package for Arch Linux. This only affects those
actually interested in building packages.
</div>

To illustrate how frustrating this process is: through reading some tutorials I
came across the RPM `%package` macro, but finding out what it did was near
impossible. If you search for "RPM package macro" on Google, the first result
[points to this
page](https://docs.fedoraproject.org/en-US/packaging-guidelines/RPMMacros/) that
doesn't mention the macro at all. The [second
result](https://rpm-software-management.github.io/rpm/manual/macros.html)
doesn't mention it either. In fact, none of the results seem to mention this
macro, and searching for "RPM %package macro" doesn't work either as the `%` is
ignored. At some point I found [this
page](https://rpm-software-management.github.io/rpm/manual/spec.html) which
briefly mentions what it does, but to do that I had to:

1. Go to <https://rpm.org/index.html>
1. Click on "Documentation" and end up at <https://rpm.org/documentation.html>
1. Click on "RPM Reference Manual" and end up at
   <https://rpm-software-management.github.io/rpm/manual/>
1. Click on "Spec Syntax" and end up at
   <https://rpm-software-management.github.io/rpm/manual/spec.html>
1. Search for `%package` on the page

While this may seem like a weirdly specific issue to mention, I ran into issues
like this _constantly_ while trying to figure out what the idiomatic/modern way
is of building an RPM.

Of course it gets worse. What would make sense is having just one tool to build
a package, and _maybe_ a separate tool to upload it to copr and start a build.
Of course there isn't just one tool:  this is Linux where people disagree on
just about everything.

Building RPM packages involves two low-level programs: `spectool` and
`rpmbuild`. `spectool` is used for just listing and downloading sources from an
RPM `.spec` file, which describes how to build a package. Of course in typical
Linux fashion it only downloads external sources, so if you list a local file as
a source (e.g. an icon to install), you'll need to move them into the right
place yourself. `rpmbuild` only concerns itself with building a package, and
straight up ignores any sources listed in your spec file.

Of course people using these tools realised this isn't nice and decided to fix
it by unifying the two into one program that everybody uses. Right? No, of
course not, that would make too much sense.

First we have [rpkg-util](https://pagure.io/rpkg-util) which builds
upon the two mentioned tools and adds some templating capabilities. It's the
default build strategy for copr when building from a VCS repository, so you'd
think it's _the_ way to build a package. But of course it's no longer maintained
per their README, and looking at existing packages on copr it seems it's not
used a lot. Oh and it also spits out the most useless error messages I've ever
seen, such as this:

```bash
$ rpkg local --spec ~/path/to/spec/outside/of/the/current/dir
git_dir_version failed with value 1
```

Then there's [tito](https://github.com/rpm-software-management/tito), which
tries to do a whole bunch of things related to packaging and releasing, but
somehow doesn't actually make the process easier. It's default output is
incredibly verbose and makes debugging build errors near impossible, it [doesn't
handle patch files](https://github.com/rpm-software-management/tito/issues/446),
and its documentation is sorely lacking. Similar to rpkg-util I also wasn't able
to find any big projects that use it, even though tito has been around for over
a decade.

For the record, I understand how one ends up with a situation like this, and I
have nothing against the people working on these tools, but having gone through
this process I think I now understand why RPM packages are less commonly
available compared to those for other distributions.

As for my own packages, I resorted to using `spectool` and `rpmbuild` directly
through a `Makefile`. For example, for lua-language-server I use the following
`Makefile`:

```make
SPEC := lua-language-server.spec
TOP := ${PWD}/build

prepare:
	rm -rf build
	spectool --define "_topdir ${TOP}" -gR ${SPEC}
	cp -p sources/* build/SOURCES/

srpm: prepare
	rpmbuild --define "_topdir ${TOP}" -bs ${SPEC}

rpm: prepare
	rpmbuild --define "_topdir ${TOP}" -bb ${SPEC}

clean:
	rm -rf build

.PHONY: srpm prepare rpm
```

The `--define` flags are there so the RPM files and directories end up in
`./build` instead of in your home directory. This way you can build multiple
packages without their source files potentially conflicting.

To publish a new package I then update the `.spec` file by hand (e.g. adjusting
the version), run `make srpm`, followed by
`copr build lua-language-server path/to/the/built/srpm`. It's not too bad, but
it's still worse than just running `makepkg -s` on Arch Linux. If you're looking
into building a package for Fedora, I'd suggest doing something similar to the
above and just avoid rpkg-util and tito entirely _unless_ you are certain you
need these tools.

## SELinux can be frustrating

Before installing Silverblue I made a backup of my
[TLP](https://linrunner.de/tlp/index.html) configuration. While Fedora ships
with
[power-profiles-daemon](https://gitlab.freedesktop.org/hadess/power-profiles-daemon),
I've read a little too much about it not doing much more than just throttling
your CPU, so I decided to stick with TLP. After all, TLP works fine so why
bother replacing it. I installed TLP, replaced the default
`/etc/tlp.conf` configuration file with my own, and reset its ownership to
`root:root`. When I tried to start TLP using `sudo systemctl start tlp`, it
failed. Of course when I ran it manually it worked just fine.

After a while I found out this was a SELinux problem, probably due to certain
SELinux settings/permissions getting lost when I replaced the default file. To
fix this I ran `sudo fixfiles restore /etc/tlp.conf`, after which TLP started up
without issue.

While SELinux does log when there are errors (assuming you even remember that it
does and where they're stored), the logs themselves aren't helpful. For example:

```
type=AVC msg=audit(1677382357.686:651): avc:  denied  { read } for
pid=16822 comm="tlp-readconfs" name="tlp.conf" dev="dm-0" ino=533021
scontext=system_u:system_r:tlp_t:s0
tcontext=system_u:object_r:dosfs_t:s0 tclass=file permissive=0
```

While this log line includes a ton of information, it does nothing to help me
understand what I need to do to fix the actual problem.

## Fonts issues with Firefox

While using the Firefox Flatpak, I noticed the text was a little fuzzy and hard
to read. Upon closer inspection I noticed it was applying [subpixel
rendering](https://en.wikipedia.org/wiki/Subpixel_rendering), even though this
is turned off system-wide (as it should be). I found out this is due to Flatpak
not allowing access to `$XDG_CONFIG_HOME/fontconfig`, which seems to result in
Firefox (incorrectly) guessing what to do.

The solution is to use [Flatseal](https://github.com/tchx84/Flatseal) to give
Firefox access to the `xdg-config/fontconfig:ro` filesystem subset, then
restart Firefox.

## Locale errors when using Distrobox

I'm using [Distrobox](https://github.com/89luca89/distrobox/) instead of
[Toolbox](https://github.com/containers/toolbox), though this issue may also
apply to Toolbox: when running certain commands in the container, I was getting
a "Failed to set locale, defaulting to C.UTF-8" error. Per [this
issue](https://github.com/89luca89/distrobox/issues/258) the fix is to run `sudo
dnf install glibc-langpack-en` in your container, changing the package name
according to the language you are using.

## What went well, and some tips

There may have been more issues I ran into, but these are the ones I can
remember. Most of these are specific to my setup though. For example, if you use
a QWERTY keyboard then getting started is easier. The cost of figuring out how
to build an RPM package is a one-time cost, and wouldn't apply to most users of
Silverblue. In fact, I suspect most users would only run into the Firefox font
problem, the Distrobox locale errors (assuming they're using Distrobox in the
first place), and the slowness of rpm-ostree and DNF.

Apart from these issues, I'm enjoying Silverblue so far. I also like how the
immutable nature of Silverblue forces you to rethink certain workflows or
decisions, such as building a proper (reusable) package instead of just dumping
some files in `/usr` or `/etc`, or using containers more actively. Not having to
worry about updates breaking your system (or at least not as easily as on Arch
Linux) is of course also great.

As far as tips and tricks go, there are a few that I can recommend.

### Put the container name in your prompt

Because you'll be using containers when using Silverblue (at least when using
the terminal), I recommend putting the name of the current container in your
shell prompt. I use [Fish](https://fishshell.com/) and have my prompt configured
as follows:

```fish
function fish_prompt
    if [ $PWD = $HOME ]
        set directory '~'
    else
        set directory (basename $PWD)
    end

    if test -n "$CONTAINER_ID"
        echo -n "[$CONTAINER_ID] "
    end

    set_color $fish_color_cwd
    echo -n $directory
    set_color normal
    echo -n " \$ "
end
```

Outside a container this results in a prompt like this:

```bash
Downloads $ input-here
```

And inside a container:

```bash
[fedora] Downloads $ input-here
```

### Use GNOME terminal profiles for your containers

Distrobox can create `.desktop` files for your containers, making it easier to
start/enter them. If you open a new tab in that terminal it will open the tab in
the default shell, not in the container; at least when using GNOME terminal. To
work around this I adjusted the generated `.desktop` file to instead start GNOME
terminal with a dedicated profile like so:

```
[Desktop Entry]
Name=Fedora
GenericName=Terminal entering Fedora
Comment=Terminal entering Fedora
Category=Distrobox;System;Utility"
Exec=gnome-terminal --profile Fedora -- /usr/bin/distrobox enter --no-workdir fedora
Icon=/var/home/yorickpeterse/.local/share/icons/distrobox/fedora.svg
Keywords=distrobox;
NoDisplay=false
Terminal=false
TryExec=/usr/bin/distrobox
Type=Application
```

Here `--profile Fedora` specifies the GNOME terminal profile to use.
The `--no-workdir` option ensures the new terminal process always starts in the
container's home directory.

The GNOME terminal profile in turn is configured as follows:

- Command → "Custom command" is set to `distrobox enter --name fedora -- fish`
- Command → "Preserve working directory" is set to "Always"

This way opening new tabs results in them entering the container, while
preserving the working directory of the previous tab.

### Give your containers a custom home directory

This isn't necessary if you only intend to use a single container, but if you
use multiple containers it's a must: when creating a container using Distrobox,
the `--home` flag is used to specify a custom home directory. This way the
container won't pollute your actual home directory, and two different containers
using the same files in your home directory won't conflict. For example:

```bash
mkdir $HOME/homes
distrobox create --name fedora --image fedora:latest --home $HOME/homes/fedora
```

This creates a new container called "fedora" with its home directory set to
`~/homes/fedora`.

Inside the container you still have access to the real home directory. As all my
projects are in `~/Projects` (in my real home directory), I created a symbolic
link to this folder from the container's home directory (running this inside the
container):

```bash
ln -s /var/home/yorickpeterse/Projects $HOME/Projects
```

This way inside the container's home directory I can just run `cd Projects`,
instead of `cd ../../Projects`.

### Automatically stage rpm-ostree updates

I'm not sure how well this works if you still have GNOME Software installed (or
if it's even necessary), but I have rpm-ostree set up to automatically stage
updates. This is done in two steps:

1. Add `AutomaticUpdatePolicy=stage` to `/etc/rpm-ostreed.conf` under the
   `[Daemon]` section.
2. Run `sudo systemctl reload rpm-ostreed` followed by `sudo systemctl enable
   --now rpm-ostreed-automatic.timer`.

You can then verify if it's enabled by running `rpm-ostree status`. If enabled
you should see a message at the top along the lines of:

```
AutomaticUpdates: stage; rpm-ostreed-automatic.timer: last run 24h ago
```

### Layer adw-gtk3

GTK3 applications look different from GTK4 applications, which is annoying. We
can fix this by using the [adw-gtk3](https://github.com/lassekongo83/adw-gtk3)
project as follows:

1. Run `sudo wget -P /etc/yum.repos.d/ https://copr.fedorainfracloud.org/coprs/nickavem/adw-gtk3/repo/fedora-37/nickavem-adw-gtk3-fedora-37.repo`.
1. Run `rpm-ostree install gnome-tweaks adw-gtk3 --apply-live`.
1. Open Tweaks and go to "Appearance", then under "Legacy Applications" choose
   "Adw-gtk3". If the theme isn't listed there try rebooting first.

## Conclusion

To conclude, I like Silverblue, in spite of the issues I ran into. In the coming
weeks I'll also move my desktop over to Silverblue, and at some point in the
future I'll also move my Windows gaming desktop to Silverblue. Most of my issues
are specific to my setup and probably won't apply to most users, though I
wouldn't recommend Silverblue to those not familiar with a terminal just yet; at
least not until GNOME Software is less clunky and stops hogging memory.
