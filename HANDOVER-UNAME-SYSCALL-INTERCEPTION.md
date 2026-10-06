# Handover: Termux raw `uname` syscall interception

## Goal

Build and validate the Termux raw `uname` syscall interception changes on a
separate operating system, preferably a Linux workstation, and report any
changes needed to make that workflow reproducible. Do not replace the feature
with a Codex-side workaround.

## Repositories and published commits

All work is on the `uname-syscall-intercept` branch and has been pushed. The
collection repository pins both submodules at the commits below.

| Repository | Remote | Commit | Change |
| --- | --- | --- | --- |
| `rebroad/termux` | `https://github.com/rebroad/termux.git` | `26519a4` | Feature integration commit |
| `rebroad/termux-exec-package` | `https://github.com/rebroad/termux-exec-package.git` | `a537671` | Seccomp/ptrace raw `uname` interception, `#!/bin/sh` fixture, and missing-interpreter test compatibility |
| `rebroad/termux-app` | `https://github.com/rebroad/termux-app.git` | `c2868175` | Default-on debugging preference and process environment wiring |

The latest remote branch heads were checked and matched those commits. Clone
the collection repository and initialize its pinned submodules:

The collection branch also contains submodule pointer updates `541cc28` and
`1b09cdf`, plus the commits that add and clarify this handover. The
exec-package branch contains implementation commit `37f31e7` and its
fixture/test fixes.

```sh
git clone --branch uname-syscall-intercept --recurse-submodules \
  https://github.com/rebroad/termux.git
cd termux
git submodule status
```

## What the feature does

- Termux exposes the debugging preference **Intercept raw uname syscalls**.
- It defaults to enabled. The app exports `TERMUX_EXEC__UNAME_INTERCEPT=1`
  when enabled and supported, or `0` otherwise.
- The app only enables it for Android API 23+, 64-bit processes, and devices
  whose first supported ABI is `arm64-v8a`. The preference is hidden on
  unsupported devices.
- The `termux-exec` preload library reads the configured Termux hostname and
  sets up a tracer and seccomp filter for AArch64 `uname` syscalls. Raw syscall
  callers in the traced process tree receive the configured nodename. The
  existing libc `gethostname()` interception remains in place.
- Enabling the filter sets `no_new_privs` for affected processes. This can
  prevent `su` or other privilege escalation in those process trees. The
  preference summary warns users about this and the syscall overhead.

Relevant source locations:

- `termux-exec-package/lib/termux-exec_nos_c/tre/src/termux/api/termux_exec/service/ld_preload/TermuxExecLDPreload.c`
- `termux-app/termux-shared/src/main/java/com/termux/shared/termux/shell/command/environment/TermuxAppShellEnvironment.java`
- `termux-app/termux-shared/src/main/java/com/termux/shared/termux/settings/preferences/TermuxAppSharedPreferences.java`
- `termux-app/app/src/main/res/xml/termux_debugging_preferences.xml`

## Validation already completed

On an Android arm64 Termux device:

- `make TERMUX_CORE_PKG__LIBRARY_FILE=libtermux-core_nos_c_tre.so test-runtime`
  passed. The shared-library override was needed because the installed device
  has the Termux Core `.so`, while the package Makefile defaults to a static
  archive. Use the normal default when the build environment supplies that
  archive.
- The runtime binary test passed with `TERMUX_EXEC__UNAME_INTERCEPT=1` and
  `=0`, using a temporary hostname file. Enabled mode exercised the raw
  `SYS_uname` assertion and returned the configured hostname; disabled mode
  passed without installing interception.
- A 10,000-call raw-syscall timing sample measured about 1.59 microseconds per
  call with interception disabled and 127 microseconds enabled on that device.
  Treat these as device-specific measurements, not portable performance
  guarantees.
- `:app:assembleDebug` was attempted from a separate synchronized build tree
  and stopped during Gradle configuration because no Android SDK was installed
  or configured (`ANDROID_HOME` and `sdk.dir` were absent). The app build is
  therefore not yet verified.

## Work for the next OS/build investigation

1. Read `termux-app/AGENTS.md` and each repository's build instructions before
   building. The app repository requires a separate synchronized build tree;
   do not generate build outputs in its source checkout.
2. On the alternate host, install/configure the supported JDK (the app repo
   specifies Java 17), Android SDK, Android build tools, and any required NDK
   components. Inspect Gradle configuration and CI workflows to choose the
   required SDK/build-tools versions rather than guessing.
3. Build the app APK, initially without signing or installing it:

   ```sh
   ./gradlew :app:assembleDebug --no-daemon --console=plain
   ```

   Run that command from the synchronized app build tree, or pass its path
   with Gradle's `-p` option.
4. Determine the supported cross-build path for `termux-exec-package` on the
   alternate host. Its Makefile currently detects the compiler's architecture
   and expects Termux Core headers/library; a normal host compiler may produce
   a host binary rather than an Android arm64 library. Prefer the repository's
   Termux package build infrastructure and Android NDK toolchain instead of
   assuming the on-device `make test-runtime` command is a cross-build recipe.
5. Validate the built Android arm64 library on a device/emulator. Confirm the
   preference value reaches newly launched Termux process trees, compare
   enabled and disabled hostname results, and measure overhead there.

Do not install an APK or replace an existing Termux installation as part of
the build investigation unless separately requested. Preserve the published
feature defaults and document any platform limitations or unverified results.
