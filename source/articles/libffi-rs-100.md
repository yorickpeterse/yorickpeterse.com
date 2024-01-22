---
{
  "title": "libffi-rs 1.0.0 is released",
  "date": "2020-10-25T00:09:55Z"
}
---

<!-- vale off -->

[libffi-rs](https://crates.io/crates/libffi) ([GitHub
repository](https://github.com/tov/libffi-rs/)) is a Rust crate that provides
bindings to [libffi](https://sourceware.org/libffi/). I've been using the crate
for about two years now for [Inko](https://inko-lang.org/), and it works great.

Development of the crate slowed down in recent years, as the author [Jesse A.
Tov](https://github.com/tov/) has been busy. To help the author out, I joined as
a maintainer, and earlier today I released version 1.0.0 of the libffi crate.

## What's new

Version 1.0.0 does not introduce any API changes compared to previous versions.
What it does introduce is the removal of the dependency on the
[bindgen](https://crates.io/crates/bindgen) crate.

Previous versions of the crate use bindgen to generate libffi bindings at
build-time, which requires libclang to be installed. While installing libclang
is not a problem on Linux, on macOS and Windows it's a bit more tricky. The
bindgen crate also introduces quite the list of build-time Rust dependencies: 37
direct and indirect dependencies to be exact.

Starting with version 1.0.0, these dependencies are no longer necessary. The
removal of these dependencies means installing the crate is both easier and
faster, while providing the same functionality as before.

For more information about these changes, take a look at [this pull
request](https://github.com/tov/libffi-sys-rs/pull/37).

## Upgrading

Existing users should have no trouble updating to the latest version, as the
public API remains unchanged compared to the previous version (0.9.0). To
upgrade, change your dependency definition to the following:

```toml
[dependencies]
libffi = "1.0.0"
```

## Future plans

There is [an open pull request that improves ARMv7
support](https://github.com/tov/libffi-rs/pull/14), which I would like to
include in a future release. Apart from that there are no big plans at this
time, as the crate works well enough in its current state.
