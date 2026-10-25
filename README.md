# Termux build collection

This repository ties together the rebroad Termux application repositories as
Git submodules. It contains shared installation documentation and scripts;
each submodule retains its own upstream history, build system, and releases.

## Download the APK

The customized Android 7+ APK will appear under **Assets** on the
[ReBroad Termux Releases page](https://github.com/rebroad/termux/releases)
as `termux-app-0.118.0.apk` after its release workflow succeeds.

The app has upstream Termux `versionName=0.118.0` and `versionCode=118`.
The CI APK is intended to use the repository's **public, untrusted test
signing key**; it is not signed with a private production key. Existing
Termux apps and companion apps must have matching signing certificates.
Back up your installation before switching signing sources.

See [INSTALL.md](INSTALL.md) for USB installation with or without ADB
debugging.

Build the signed customized app with:

```sh
./scripts/build-termux.sh
```

After installation, configure the displayed identity from inside Termux:

```sh
termux-identity USERNAME HOSTNAME
```
