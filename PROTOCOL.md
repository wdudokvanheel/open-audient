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

## Mixer, routing, headphones — verified

These were cross-referenced with the [MixiD](https://github.com/TheOnlyJoey/MixiD)
Linux project (which targets the same iD44, PID 0x0005) and confirmed readable on
hardware (`oa dump`). MixiD also independently reproduces every monitor selector
above, raising confidence in the whole map.

| Function | unit | selector | channel | len | encoding |
|----------|------|----------|---------|-----|----------|
| Mixer crosspoint level | `0x3c` | `0x01` | mixer channel | 2 | Q8.8 dB (`0x8000` = −128/min) |
| Output route source | `0x33` | `0x06` | output 0…5 | 1 | source ID byte |
| Headphone volume | `0x0a` | `0x02` | 3 (L), 4 (R) | 2 | Q8.8 dB |
| Headphone mute | `0x0a` | `0x01` | 3, 4 | 1 | bool |

Notes:
- Mixer input fader L/R map to mixer channels `input×6` and `input×6+1` (MixiD
  `set_channel_volume`). A live read showed channels 0/1 at −3.6 dB, 8/9 active,
  the rest at −128 dB (muted) — i.e. real mixer state.
- All level controls are UAC2-standard signed Q8.8 dB (verified across monitor,
  mixer and headphone units). MixiD's linear `float→u16` mapping is its own
  approximation; this project follows the iD app's Q8.8.
- MixiD maps a per-channel **phase** to feature unit `0x0b`, selector `0x0d`,
  channel `1+n`, but `GET_CUR` stalls there on this iD44 (MixiD flags it
  unverified), so it is **not** implemented yet.

## Remaining controls — not yet mapped

Still need probing/RE; not present in MixiD or the monitor unit:

- **Preamp**: phantom power (48V), pad, input gain, HPF. The iD app routes these
  through standard UAC **feature-unit** controls plus a string-keyed parameter /
  OSC bus (`UacFeatureUnit::setInputGain`,
  `getChannelControlIsPresent(channel, control=0x300000)` on input feature unit
  `0x0a`), so they need empirical probing (sweep selector × channel) or RE of the
  parameter tables.
- **Per-channel phase/polarity**: see the MixiD note above (unverified).

Why the preamp is harder than the monitor unit: in iD.app, `InputChannelModel`
setters call `InputControlModel::setParameter(InputControlParameter, channel,
value)` (param enum: HPF=9, Routing=8, …), which builds a **juce::String key** and
dispatches through a named-parameter / OSC bus (`InputControlModel::setOSCSender`
exists) rather than a direct USB call. So preamp selectors are not inline
constants and must be found by probing or by RE'ing the parameter tables.

### Probe findings (GET_CUR sweep)

- **`0x0a`** (input/HP feature unit): MUTE (`0x01`) and VOLUME (`0x02`) respond,
  channel-addressed. Headphones are channels 3/4; other channels are inputs.
- **`0x32`** (input XU, 30 ch): only selector `0x06` responds at channel 0; the
  rest are channel-addressed (channel = input index) — candidate for preamp.
- **`0x33`** (routing XU): selector `0x06` is channel-addressed by output (0…5),
  returning the source ID per output — the routing matrix (see table above).

### Method to map a remaining control (empirical)

1. In iD.app, change one control to a known value, then quit iD.app.
2. `oa probe <unit>` / `oa get <unit> <sel> <len> <channel>` and look for the
   value; sweep the channel byte (input/output index) as well as the selector.
3. Confirm with `oa set <unit> <sel> <channel> <bytes>` (verify audibly, then
   restore). Feature-unit controls (`0x0a`) use selector 1 = mute, 2 = volume,
   channel = input number.
