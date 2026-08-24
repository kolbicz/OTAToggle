# OTA Toggle

OTA Toggle is a small jailbreak utility for iOS and iPadOS 15 or newer. It
shows the state of four Apple OTA-related launchd services and can enable or
disable them together by updating:

`/var/db/com.apple.xpc.launchd/disabled.plist`

The app automatically reads and displays the current status when it opens. It
never changes anything without confirmation. Use the displayed action to enable
or disable all four services. A reboot is required, and the app can reboot the
device after applying a change.

## Services

- `com.apple.mobile.softwareupdated`
- `com.apple.OTATaskingAgent`
- `com.apple.softwareupdateservicesd`
- `com.apple.mobile.NRDUpdated`

The app uses an embedded setuid helper installed as `root:wheel`. Plist writes
are atomic and preserve the expected ownership and permissions.

## Compatibility

- iOS and iPadOS 15+
- Rootless jailbreaks (`iphoneos-arm64` package)
- Roothide jailbreaks (`iphoneos-arm64e` package)

The roothide build uses the official `rootfs()` path conversion API to access
the original iOS filesystem from the randomized jailbreak bootstrap.

This is a jailbreak package, not a normal sideloadable App Store application.

## Building

Rootless, using standard Theos:

```sh
gmake clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

Roothide, using the roothide Theos fork:

```sh
gmake clean package FINALPACKAGE=1 \
  THEOS="$HOME/roothide-theos" \
  TARGET=iphone:clang:16.5:15.0 \
  THEOS_PACKAGE_SCHEME=roothide
```

## License

MIT
