# Installing the Termux applications

This repository collects the Termux application repositories used for the
rebroad build. The application source remains in the individual submodules;
this document describes installing APKs to an Android device over USB.

## Download a prebuilt APK

For the customized main Termux APK, visit
[ReBroad Termux Releases](https://github.com/rebroad/termux/releases).
Download `termux-app-VERSION.apk` and optionally verify it against
`SHA256SUMS.txt`. The filename/version are derived from the pinned app's
Gradle metadata. The current release line is `0.119.0-beta.3-rebroad.1`
(Android versionCode `1025`).

These CI APKs use the **public, untrusted Termux test key**. They cannot
update F-Droid or private-key signed installations. Back up your files before
switching signing sources, and ensure companion apps use the same key.

## Prepare the repositories

```sh
git clone https://github.com/rebroad/termux.git ~/src/termux
cd ~/src/termux
git submodule update --init --recursive
```

Build the APKs in the relevant submodule according to its own instructions.
Do not commit generated APKs or private signing keys to this repository.

For the customized main app, the collection build script uses the configured
private signing key and places the APK in the external build tree:

```sh
./scripts/build-termux.sh
```

The installed app provides `termux-identity USERNAME HOSTNAME` to configure
the username and hostname without a first-run GUI.

## Install all three ReBroad APKs

After downloading the main, Termux:API and Termux:Boot APKs from the same
[ReBroad GitHub release](https://github.com/rebroad/termux/releases),
install them individually (main app first). From the download directory:

```sh
adb install -r termux-app-0.119.0-beta.3-rebroad.1.apk
adb install -r termux-api-0.53.0-rebroad.1.apk
adb install -r termux-boot-0.8.1-rebroad.1.apk
```

You can also tap each APK on the phone. These are three distinct Android
packages; an Android split-APK installer is **not** appropriate for installing
the separate applications as one package. If your old Termux:API or
Termux:Boot is F-Droid-signed, back up app data and uninstall that companion
before installing the public-test-key-signed ReBroad version.

Inside the main Termux terminal, `pkg install termux-api` installs the
command-line scripts that communicate with the Termux:API Android app. Open
Termux:Boot once after installing it and put startup scripts in
`~/.termux/boot/`; Android may require battery/autostart permissions.

## Install

Build the APKs in the relevant submodule first, connect the phone by USB (or
make its Wi-Fi debugging endpoint available), then simply run:

```sh
./scripts/install-termux.sh
```

The script finds the newest APK for each filename under this collection. It
uses any already-connected USB or Wi-Fi ADB transport. If several authorised
devices are connected, it asks which one to use. `--serial SERIAL` can select
one non-interactively.

## USB or Wi-Fi debugging enabled

On the phone, enable **Developer options → USB debugging**, connect the USB
cable, and approve the computer-authorisation prompt. Verify the device:

```sh
adb devices
```

The script uses `adb install -r`, preserving the application data. You can
also pass explicit APK paths instead of using automatic discovery:

```sh
./scripts/install-termux.sh --serial SERIAL path/to/termux-app.apk
```

## Isolated virtual-display testing

To test Termux without taking over the phone's primary display, use the
scrcpy virtual-display helper:

```sh
./scripts/termux-virtual-display.sh
```

It selects the only authorised ADB device automatically, or asks which device
to use when several are connected. The helper starts Termux on a separate
Android virtual display; close scrcpy to remove it. Use `--headless` when no
local video window is wanted. Use the customized scrcpy fork, which keeps the
keyboard on new virtual displays even in headless mode.
The helper looks for `scrcpy` in `PATH`, the
standard `~/src/scrcpy` build locations, and `/var/tmp/scrcpy-build`; set
`SCRCPY_BIN` and `SCRCPY_SERVER_PATH` when using a custom build.

## USB debugging disabled

ADB cannot install an APK when debugging is disabled. The script therefore
falls back to mounted phone storage, choosing a `Download` directory when one
is visible through MTP/GVFS. You can also specify it explicitly:

```sh
./scripts/install-termux.sh --copy-to /path/to/phone/Download
```

After copying, open the APK on the phone and confirm the Android package
installer prompt. The phone may require allowing the file manager to install
unknown apps. If the phone storage is not mounted, copy the APK by MTP or
another user-approved file-transfer method, then rerun the script.

## Package order

Install the main `termux-app` APK first. Install companion APKs such as
Termux:API, Termux:Boot, or Termux:Tasker afterward. They must use the same
signing key and compatible versions as the main Termux app.

## Signing

Release APKs must be signed with the key already used by the installed Termux
family. Keep the keystore and passwords outside Git. See the signing notes in
the `termux-app` submodule for the local build workflow.
