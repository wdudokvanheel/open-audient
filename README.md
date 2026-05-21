# Open Audient

Open Audient is a small reverse-engineering note and seed implementation for controlling Audient iD-series mixer/monitor features without Audient's iD mixer app running.

The first working control is the Audient iD44 monitor **Cut** switch. Cut mutes the main monitor/speaker output while leaving the headphone output live.

## Current Status

Working on this machine:

```sh
~/bin/id44cut status
~/bin/id44cut on
~/bin/id44cut off
~/bin/id44cut toggle
```

There is also a script-friendly wrapper:

```sh
~/bin/id44-cut
~/bin/id44-cut toggle
~/bin/id44-cut on
~/bin/id44-cut off
~/bin/id44-cut status
```

`id44-cut` defaults to `toggle` when no argument is provided.

Audient iD.app should be quit before using the tool. The tool does not need iD.app to be installed or running.

## App (`OpenAudient`)

A native SwiftUI macOS app that controls the device, with a built-in headless
command-line mode in the same binary. Built on the `OpenAudient` Swift package
(an async, hot-plug-aware control library), verified against real hardware.

```sh
swift build
swift run oa                             # launch the GUI

# the same binary, headless:
swift run oa cut status|on|off|toggle    # the Cut switch (mirrors id44cut)
swift run oa dump                        # read the whole device
swift run oa list                        # connected iD models
swift run oa watch                       # live connect/disconnect events
swift run oa get <unit> <sel> <len>      # raw GET_CUR (hex) — for protocol mapping
swift run oa probe <unit>                # GET_CUR selector sweep

swift test                               # pure encoding + logic tests
OPEN_AUDIENT_DEVICE=1 swift test         # adds the hardware round-trip test
```

The GUI auto-connects when an iD is plugged in (hot-plug aware) and mirrors the
device's readable state. The Audient iD app must be quit — it holds exclusive
control of the device.

Mapped and verified against hardware:

- **Monitor** (unit `0x36`): Cut, Dim, Mono, Polarity, Talkback, Main/Cue
  volumes, Dim/Mono atten, source and output selection, trims.
- **Mixer** (unit `0x3c`): per-channel crosspoint levels (dB).
- **Routing** (unit `0x33`): per-output source selection.
- **Preamp** (feature unit `0x0b`): per-input gain, pad, phase (write-only;
  phase hardware-confirmed, gain/pad inferred on the same unit).

The iD44's two **headphone** outputs use physical level dials and are not
USB-controllable, so the app doesn't expose a software headphone slider.

Still to map: phantom power (48V) and HPF. See [PROTOCOL.md](PROTOCOL.md)
for the full selector tables, USB unit topology, and method. The mixer/routing/
headphone mappings were cross-checked against the
[MixiD](https://github.com/TheOnlyJoey/MixiD) Linux project, which also
independently confirms the monitor selectors.

It uses Apple's modern **IOUSBHost** framework directly from Swift — no C shim. The
kernel already exposes the iD44 as an `IOUSBHostDevice`, and control transfers go to
endpoint 0, which AppleUSBAudio does not claim exclusively, so CoreAudio keeps
streaming. (The Audient iD app must still be quit, as it holds the control endpoint.)

Layers, each isolated for testability and growth:

| Layer | Type | Role |
|-------|------|------|
| `USBControlTransport` | protocol | `getCurrent`/`setCurrent` raw UAC transfers; mockable, swappable |
| `IOUSBHostTransport` | class | concrete IOUSBHost backend |
| `DeviceDiscovery` | enum | IOKit matching → `io_service_t` |
| `UACControlRequest` | struct | packs `(unit, selector, channel, interface)` → `wValue`/`wIndex` |
| `Control` | protocol | declarative descriptor: address + value codec |
| `BoolControl`/`ByteControl`/`FixedQ88Control` | struct | reusable codecs (bool, uint8, signed Q8.8) |
| `Monitor` | enum | namespace of all monitor controls on unit `0x36` |
| `AudientDevice` | class | typed facade: `read`/`write`/`toggle` + raw `get`/`set` |

```swift
let device = try AudientDevice.openFirst()
try device.write(Monitor.cut, true)          // mute speakers
let volume = try device.read(Monitor.mainVolume)  // dB, Q8.8 decoded
try device.write(Monitor.dim, true)
```

**Adding a new control** means declaring one descriptor with its
`(unitID, selector, channel, length)` and a codec — no transport or facade
changes. Most are one line in `Monitor.swift` (or a new per-unit namespace):

```swift
static let dim = boolControl("Dim", 0x05)        // unit 0x36, selector 0x05
static let mainVolume = fixedControl("Main Volume", 0x12)  // Q8.8, 2 bytes
```

Mapping the remaining units (preamp, mixer faders/pans, routing) is reverse-
engineering each control's tuple — see [PROTOCOL.md](PROTOCOL.md).

## Basic Idea

Keep macOS's normal AppleUSBAudio/CoreAudio driver responsible for audio streaming. A separate open-source tool can control mixer and monitor state by sending USB Audio Class control requests to Audient extension units.

For the Cut control, the working transfer is:

```text
SET_CUR:
  bmRequestType = 0x21
  bRequest      = 0x01
  wValue        = 0x0400
  wIndex        = 0x3600
  wLength       = 1
  data          = 0x01 for Cut ON, 0x00 for Cut OFF

GET_CUR:
  bmRequestType = 0xA1
  bRequest      = 0x01
  wValue        = 0x0400
  wIndex        = 0x3600
  wLength       = 1
```

Interpreting the UAC fields:

```text
wValue = (controlSelector << 8) | channel
       = (0x04 << 8) | 0
       = 0x0400

wIndex = (unitId << 8) | interface
       = (0x36 << 8) | 0
       = 0x3600
```

For iD44 Cut:

```text
control selector = 0x04
extension unit   = 0x36
channel          = 0
interface        = 0
```

## What We Learned

- Opus's earlier `wValue=0x0000` / `wIndex=0x0000` finding was wrong for the real Cut control.
- Audient iD.app v4.4.2 contains `UacLib::UacXUAudientMonitorController::setCut`.
- That function passes selector `4`, channel `0`, request type `SET_CUR`, and length `1` into Audient's UAC request helper.
- Audient's UAC helper constructs `wValue` as `(selector << 8) | channel`.
- The monitor controller extension unit ID is `0x36`, so `wIndex` is `0x3600`.
- A standalone IOUSBLib `DeviceRequest` succeeds with this corrected tuple while iD.app is not running.
- `GET_CUR` returns `raw=0` for Cut off and `raw=1` for Cut on.
- A full open-source mixer clone is probably feasible by mapping more Audient extension units and selectors.

## Build

```sh
clang -o ~/bin/id44cut ~/bin/id44cut.c -framework IOKit -framework CoreFoundation
chmod +x ~/bin/id44cut ~/bin/id44-cut
```

## Current Source

```c
// id44cut - set/read the Audient iD44 monitor Cut (speaker mute) over USB.
//
// The Cut control is a UAC extension-unit request on the audio-control interface:
//   SET_CUR  bmRequestType=0x21 bRequest=0x01 wValue=0x0400 wIndex=0x3600 len=1
//     data 0x01 = Cut ON (speakers muted),  0x00 = Cut OFF (speakers live).
//   GET_CUR  bmRequestType=0xA1 bRequest=0x01 wValue=0x0400 wIndex=0x3600 len=1
//
// These constants come from Audient iD.app v4.4.2's own UacLib code:
//   control selector 4 = Cut, extension unit ID 0x36, channel/interface low byte 0.
// iD must be quit, but this tool does not depend on iD being installed or running.
//
// build: clang -o id44cut id44cut.c -framework IOKit -framework CoreFoundation
#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>

#define VID 0x2708
#define PID 0x0005
#define UAC_SET_CUR 0x01
#define UAC_CUT_SELECTOR 0x04
#define UAC_MONITOR_UNIT 0x36
#define UAC_CUT_WVALUE ((UInt16)(UAC_CUT_SELECTOR << 8))
#define UAC_CUT_WINDEX ((UInt16)(UAC_MONITOR_UNIT << 8))

static IOUSBDeviceInterface300 **openDevice(void) {
    CFMutableDictionaryRef m = IOServiceMatching(kIOUSBDeviceClassName);
    SInt32 vid = VID, pid = PID;
    CFNumberRef v = CFNumberCreate(NULL, kCFNumberSInt32Type, &vid);
    CFNumberRef p = CFNumberCreate(NULL, kCFNumberSInt32Type, &pid);
    CFDictionarySetValue(m, CFSTR(kUSBVendorID), v);
    CFDictionarySetValue(m, CFSTR(kUSBProductID), p);
    CFRelease(v); CFRelease(p);
    io_iterator_t it = 0;
    IOServiceGetMatchingServices(kIOMainPortDefault, m, &it);
    io_service_t dev; IOUSBDeviceInterface300 **d = NULL;
    while ((dev = IOIteratorNext(it))) {
        IOCFPlugInInterface **pl = NULL; SInt32 s = 0;
        if (IOCreatePlugInInterfaceForService(dev, kIOUSBDeviceUserClientTypeID,
                kIOCFPlugInInterfaceID, &pl, &s) == KERN_SUCCESS && pl) {
            (*pl)->QueryInterface(pl, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID300), (LPVOID*)&d);
            (*pl)->Release(pl);
        }
        IOObjectRelease(dev);
        if (d) break;
    }
    IOObjectRelease(it);
    return d;
}

int main(int argc, char **argv) {
    const char *cmd = argc > 1 ? argv[1] : "status";

    IOUSBDeviceInterface300 **dev = openDevice();
    if (!dev) { fprintf(stderr, "iD44 not found\n"); return 1; }
    IOReturn r = (*dev)->USBDeviceOpen(dev);
    if (r) r = (*dev)->USBDeviceOpenSeize(dev);
    if (r) { fprintf(stderr, "cannot open device 0x%08x (quit the iD app first)\n", r); return 2; }

    int rc = 0, state = -1;
    UInt8 b = 0;
    IOUSBDevRequest req;

    #define DOREQ(BMRT,DATA) do { \
        memset(&req,0,sizeof(req)); req.bmRequestType=(BMRT); req.bRequest=UAC_SET_CUR; \
        req.wValue=UAC_CUT_WVALUE; req.wIndex=UAC_CUT_WINDEX; req.wLength=1; b=(DATA); req.pData=&b; \
        rc=(*dev)->DeviceRequest(dev, &req); } while(0)

    if (!strcmp(cmd,"on") || !strcmp(cmd,"mute")) {
        DOREQ(0x21, 0x01);
        printf(rc ? "write failed 0x%08x\n" : "Cut ON (speakers muted)\n", rc);
    } else if (!strcmp(cmd,"off") || !strcmp(cmd,"unmute")) {
        DOREQ(0x21, 0x00);
        printf(rc ? "write failed 0x%08x\n" : "Cut OFF (speakers live)\n", rc);
    } else if (!strcmp(cmd,"toggle")) {
        DOREQ(0xA1, 0x00); state = b;
        if (rc) fprintf(stderr, "read failed 0x%08x\n", rc);
        else { DOREQ(0x21, state ? 0x00 : 0x01);
               printf(rc ? "write failed 0x%08x\n" : (state ? "Cut OFF (live)\n" : "Cut ON (muted)\n"), rc); }
    } else { // status
        DOREQ(0xA1, 0x00); state = b;
        if (rc) fprintf(stderr, "read failed 0x%08x (GET_CUR unsupported)\n", rc);
        else printf("Cut: %s (raw=%d)\n", state ? "ON (muted)" : "OFF (live)", state);
    }

    (*dev)->USBDeviceClose(dev);
    (*dev)->Release(dev);
    return rc ? 5 : 0;
}
```

## Next Protocol Targets

Useful next controls to map:

- Dim
- Mono
- Alt speaker
- Talkback
- monitor volume
- preamp phantom power, pad, polarity
- mixer faders and pans
- cue mix output routing
- state save/load

The likely workflow is to identify the corresponding iD.app UacLib methods, extract `(unitId, selector, channel, length)`, then verify standalone `GET_CUR` and `SET_CUR` transfers.
