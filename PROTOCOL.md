# Audient iD44 USB Control Protocol

Reverse-engineering notes for controlling the Audient iD44 (VID `0x2708`, PID
`0x0005`) over USB Audio Class (UAC) control transfers, without the Audient iD
app. Derived from iD.app v4.4.2 (`UacLib`) plus live hardware verification.

The macOS `AppleUSBAudio` driver keeps streaming audio; we only send control
transfers on endpoint 0. The Audient iD app must be quit (it holds the control
endpoint), but it need not be installed.

## Transfer format

All controls are UAC `SET_CUR` / `GET_CUR` requests on the audio-control
interface (interface 0):

```
SET_CUR: bmRequestType=0x21 bRequest=0x01 wValue wIndex wLength data
GET_CUR: bmRequestType=0xA1 bRequest=0x01 wValue wIndex wLength
  wValue = (selector << 8) | channel
  wIndex = (unitID  << 8) | interface(0)
```

In iD.app every Audient extension-unit setter funnels into:

```
UacLib::UacUnitBase::sendSetRequest(RequestType, char selector, char channel,
                                    const u8* data, u32 length)
```

with register mapping `x0`=unit, `w1`=requestType(1=CUR), `w2`=selector,
`w3`=channel, `x4`=data, `w5`=length. The unit ID is a property of the extension
unit object, taken from the device's USB descriptors.

## Unit / topology map (from the device's config descriptor)

The iD44 reports these audio-control units (UAC2):

| Unit | Kind | Notes |
|------|------|-------|
| `0x29`,`0x2c`,`0x2d` | Clock Source | |
| `0x28` | Clock Selector | |
| `0x01` | Input Terminal | USB/DAW in |
| `0x02` | Input Terminal | analogue in |
| `0x0a` | Feature Unit | input feature unit (preamp gain path) |
| `0x0b` | Feature Unit | DAW feature unit |
| `0x0c`,`0x0d` | Feature Unit | from mixer units `0x3c`/`0x3d` |
| `0x14` | Output Terminal | |
| `0x3c`,`0x3d` | Mixer Unit | cue/stereo mixes |
| **`0x32`** | Extension Unit | extCode 0, 30 ch — input side |
| **`0x33`** | Extension Unit | extCode 0, 24 ch — output/routing side |
| **`0x36`** | Extension Unit | **extCode 1 — Monitor** (verified) |
| **`0x37`** | Extension Unit | extCode 2 — MonoMix (no setters) |

iD.app picks the extension unit for each controller by matching
`getExtensionCode()` against the descriptor's `wExtensionCode`:

| Controller | extCode | Unit |
|------------|---------|------|
| `UacXUAudientMonitorController` | 1 | `0x36` |
| `UacXUAudientMonoMixController` | 2 | `0x37` |
| `UacXUAudientRoutingMatrix` | 0 | `0x32`/`0x33` |
| `UacXUAudientBlendMixer` | 0 | `0x32`/`0x33` |
| `UacXUAudientInputControl` | 0 | `0x32`/`0x33` |
| `UacXUAudientOutputControl` | 0 | `0x32`/`0x33` |
| `UacXUAudientSystemControl` | 0 | `0x32`/`0x33` |

extCode 0 is shared by five controllers across two units, disambiguated at
runtime by the selector and which unit the model layer hands to the controller.

## Monitor unit `0x36` — VERIFIED

Selectors recovered from `UacXUAudientMonitorController` and confirmed on
hardware (`oa monitor dump`; Cut also cross-checked against the `id44cut` C tool).

| Control | selector | len | encoding | GET on iD44 |
|---------|----------|-----|----------|-------------|
| Mono | `0x00` | 1 | bool | yes |
| Mono Mode | `0x01` | 1 | uint8 | yes |
| Mono Atten | `0x02` | 2 | Q8.8 dB | stalls |
| Polarity | `0x03` | 1 | bool | yes |
| **Cut** | `0x04` | 1 | bool | yes |
| Dim | `0x05` | 1 | bool | yes |
| Dim Atten | `0x06` | 2 | Q8.8 dB | yes (−15.0) |
| Talkback | `0x07` | 1 | bool | yes |
| Talkback Input | `0x08` | 1 | uint8 | yes |
| Monitor Output Sel | `0x0c` | 1 | uint8 | yes |
| Function Key Mode | `0x10` | 2 | ch = key | — |
| Main Volume | `0x12` | 2 | Q8.8 dB | yes (−10.0) |
| Cue 1 Volume | `0x13` | 2 | Q8.8 dB | stalls |
| Cue 2 Volume | `0x14` | 2 | Q8.8 dB | stalls |
| Source | `0x15` | 1 | uint8 | yes |
| Monitor Output Trim | `0x17` | 2 | Q8.8, ch = output | — |
| Stand-Alone State | `0x18` | 4 | raw | — |
| HW Monitor Mode | `0x19` | 1 | bool | stalls |

"stalls" = `GET_CUR` returns a USB error on iD44 (control is set-only, absent, or
only valid in a particular mode); the corresponding `SET_CUR` may still work.

### Encodings

- **bool**: 1 byte, `0x00`/`0x01`.
- **uint8**: 1 byte enumeration/index.
- **Q8.8**: signed `int16`, little-endian, `raw = round(value × 256)`. iD.app
  produces it with `fcvtzs w8, d0, #8`. Decoded readings match expected dB
  (Dim −15, Main −10).

## Remaining controls — not yet mapped (need probing)

These do not use simple inline selectors and require live probing
(`oa probe`, `oa get`, `oa set`) to confirm unit + selector + encoding:

- **Preamp** (gain, phantom/48V, pad, HPF, polarity): the input model calls
  standard UAC **feature-unit** controls — e.g. `UacFeatureUnit::setInputGain`,
  `getChannelControlIsPresent(channel, control=0x300000)` — on the input feature
  unit (`0x0a`), not an Audient XU.
- **Mixer faders / pans** (`MixerNode::setVolumeDB`/`setPan`): the model only
  updates state and notifies JUCE listeners; a separate sync layer pushes to the
  mixer units (`0x3c`/`0x3d`) or routing XU (`0x33`). Crosspoint addressing TBD.
- **Routing** (`UacXUAudientRoutingMatrix::setRouteSource(unit, index, source)`):
  selector fixed inside the XU; index is the channel byte. Unit `0x32`/`0x33` TBD.
- **Input/Output/System control** (`setParameter(unit, selector, channel, value)`):
  generic; selectors live in the `*Model` callers. Unit `0x32`/`0x33` TBD.

### Method to map a new control

1. Find the iD.app model setter and its `UacXUAudient…::setParameter` /
   `sendSetRequest` call; note selector, channel, length, encoding.
2. Pick the candidate unit (`0x32` or `0x33`) from the topology above.
3. Confirm on hardware: `oa get <unit> <selector> <len>` should return data (not
   stall). Toggle in iD.app and re-read to see the value change, or
   `oa set <unit> <selector> <channel> <bytes>` and verify audibly, then restore.
