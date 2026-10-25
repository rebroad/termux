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

## Companion APKs

**Termux:API** and **Termux:Boot** are separate Android applications. Download
their signed APKs from the **same GitHub release as the main Termux APK**:
`termux-api-0.53.0-rebroad.1.apk` and
`termux-boot-0.8.1-rebroad.1.apk`. The companion APKs are built from this
repository's pinned `rebroad/termux-api` and `rebroad/termux-boot` forks and
signed with the **same public untrusted Termux test certificate** as the
main app. `SHA256SUMS-companions.txt` contains companion checksums.

Install the main app first, then the individual companion APKs. They cannot
all be installed as one standard APK. If you previously installed companion
apps from F-Droid or another signer, Android requires uninstalling those
incompatible companions after backing up anything important.

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
