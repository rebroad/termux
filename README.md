# Termux build collection

This repository ties together the rebroad Termux application repositories as
Git submodules. It contains shared installation documentation and scripts;
each submodule retains its own upstream history, build system, and releases.

## Download the APK

Get the installable APK from the [ReBroad Termux Releases page](https://github.com/rebroad/termux/releases).
Open the newest ReBroad **prerelease** and expand **Assets**. The APK is named
`termux-app-VERSION.apk` where VERSION comes from the app's Gradle
`versionName`. The accompanying `SHA256SUMS.txt` lets you verify the file.
You can also download the same APK from [GitHub Actions](https://github.com/rebroad/termux/actions/workflows/rebroad-termux-unsigned-build.yml)
after a successful build.

The current ReBroad version is `0.118.0-rebroad.1` with Android
`versionCode=1023`, based on upstream Termux `master` with ReBroad
customizations. This higher version code **does not** make the APK upgrade
compatible with F-Droid: the public, untrusted Termux test certificate is
different from F-Droid's. Back up existing data before switching signing
sources; companion apps must be signed with a matching key.

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
