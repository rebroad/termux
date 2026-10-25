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

The current ReBroad version is `0.119.0-beta.3-rebroad.2` with Android
`versionCode=1026`, based on upstream F-Droid beta `v0.119.0-beta.3` with ReBroad
customizations. This higher version code **does not** make the APK upgrade
compatible with F-Droid: the public, untrusted Termux test certificate is
different from F-Droid's. Back up existing data before switching signing
sources; companion apps must be signed with a matching key.

## Preferred signed ReBroad packages

The aarch64 APK now embeds a dedicated, **signed** APT source hosted at
`https://raw.githubusercontent.com/rebroad/termux-packages/apt-repo`.
Its `Origin: ReBroad` packages receive APT priority **1001**; packages not
provided by ReBroad still resolve from your standard Termux mirrors.
The public archive key is fingerprint
`D707B230D33E2AA09C0B979FAC3209C81372E53A`.
This is **separate from** the Android APK test-signing certificate.

In existing Termux installations, run
`bash <(curl -fsSL https://raw.githubusercontent.com/rebroad/termux-packages/master/scripts/rebroad-enable-repo.sh)`
to opt in without reinstalling. The new `sccache` native package is
experimental and will appear in `apt-cache policy sccache` only once it
has built and been published under the archive's signing key. See
[APT setup notes](https://github.com/rebroad/termux-packages/blob/master/docs/rebroad-apt-repository.md).

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
