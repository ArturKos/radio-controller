# RF 433MHz Radio Controller — HOWTO

## Overview

Control 433MHz RF lights in bedroom and living room from Home Assistant and Alexa using ESP8266 (NodeMCU) + CC1101 transceiver via ESPHome. Also monitors all 433MHz RF activity (weather stations, door sensors, remotes).

## Hardware

- NodeMCU ESP8266 (board: nodemcuv2)
- CC1101 433MHz transceiver module (SMA antenna)
- Breadboard + jumper wires

## Wiring

```
CC1101          NodeMCU
──────          ───────
VCC      ────►  3.3V  (NOT 5V!)
GND      ────►  GND
SCK      ────►  D5  (GPIO14)
MISO     ────►  D6  (GPIO12)
MOSI     ────►  D7  (GPIO13)
CSN      ────►  D8  (GPIO15)
GDO0     ────►  D2  (GPIO4)   ← shared RX/TX pin
GDO2     ────►  D1  (GPIO5)   ← connected but unused currently
```

**Important:**
- CC1101 is **3.3V only** — 5V will damage it
- GDO0 (D2) handles both receiving and transmitting — the CC1101 switches modes via `cc1101.begin_tx` / `cc1101.begin_rx` triggers
- If Chip ID shows `0xFFFF` → SPI wiring is wrong or loose

## How It Works

```
┌──────────┐     SPI      ┌────────┐    433MHz    ┌──────────┐
│ NodeMCU  │◄────────────►│ CC1101 │◄────────────►│ RF Lights│
│ ESP8266  │              │  TX/RX │              │ (bedroom)│
└────┬─────┘              └────────┘              └──────────┘
     │ WiFi                                    ┌──────────────┐
     ▼                                         │Weather stations│
┌──────────┐                                   │Door sensors    │
│  Home    │  ◄── Alexa (emulated_hue)         │Other 433MHz   │
│Assistant │                                   └──────────────┘
└──────────┘
```

## Button Mapping

### Bedroom (Remote 1 — rc_switch protocol 1) ✅ Working

| Button | Function | Code |
|--------|----------|------|
| 1 | Toggle on/off | `001101010011111111000000` |
| 2 | Toggle on/off | `001101010011111100110000` |
| 3 | ON | `001101010011111100001100` |
| 4 | OFF | `001101010011111100000011` |

### Living Room (Remote 2 — rc_switch protocol 3) ❌ Not working

| Button | Function | Code |
|--------|----------|------|
| 1 | Toggle on/off | `000100011111101100010000` |
| 2 | Toggle on/off | `000100011111101100100000` |
| 3 | OFF | `000100011111101111100000` |
| 4 | ON | `000100011111101111000000` |
| 5 | OFF | `000100011111101101100000` |
| 6 | Timer 30s | `000100011111101101000000` |
| 7 | Timer 30min | `000100011111101110100000` |
| 8 | Timer 60min | `000100011111101110000000` |

Note: Living room codes were sniffed successfully but TX doesn't trigger the lights. Original remote also stopped working — may be a pairing issue.

## Setup

### 1. Flash ESPHome

First time (USB):
```bash
esphome run radio-controller.yaml
# Select USB/serial port
```

Update (OTA — device already running ESPHome):
```bash
esphome run radio-controller.yaml
# Select OTA / 192.168.1.172
```

Or use ESPHome dashboard: **HA → ESPHome → radio-controller → INSTALL → Wirelessly**

### 2. Verify CC1101

Check logs for:
```
[C][cc1101:224]: CC1101:
[C][cc1101:224]:   Chip ID: 0x0014       ← CC1101 detected
```

### 3. Alexa Integration

The bedroom light is exposed to Alexa via emulated_hue:
- **"Alexa, turn on bedroom light"**
- **"Alexa, turn off bedroom light"**

How it works:
1. `input_boolean.bedroom_light` — virtual switch in HA
2. Automation watches the boolean → presses ESPHome button (ON or OFF)
3. `emulated_hue` exposes the boolean to Alexa as "Bedroom light"

If Alexa doesn't see the device, say **"Alexa, discover devices"**.

### 4. RF Activity Monitoring

The device continuously listens for all 433MHz signals. In Home Assistant:
- **RF Signals Received** — counter of signals caught (resets at midnight)
- **Last RF Code** — protocol + hex code of last received signal
- **ESPHome Logs** — detailed view of all received codes

#### Discovering Devices

1. Open **ESPHome → Logs** for radio-controller
2. Watch for repeating codes:
   - Every 30-60s → likely a **weather station**
   - On door open/close → **door/window sensor**
   - Random bursts → other remotes, car key fobs, etc.
3. Note the protocol and hex code from logs

#### Adding Door/Window Sensors

After identifying a sensor's codes, edit the YAML:

1. Uncomment the `binary_sensor` template for `front_door`
2. Add the sensor's open/close codes to the `on_rc_switch` lambda:
```cpp
if (x.protocol == 1 && x.code == 0xYOUR_OPEN_CODE) {
  id(door_sensor_1_state) = true;
  id(front_door).publish_state(true);
}
if (x.protocol == 1 && x.code == 0xYOUR_CLOSE_CODE) {
  id(door_sensor_1_state) = false;
  id(front_door).publish_state(false);
}
```

### 5. Sniff New Remote Codes

To capture codes from a new remote, temporarily change dump mode:
```yaml
remote_receiver:
  dump: all          # change from rc_switch to all
  filter: 50us       # reduce from 200us
  idle: 10ms         # increase from 4ms
  buffer_size: 2048  # add this line
```

Flash, open logs, press remote buttons, note the codes. Then revert settings.

## Key Technical Notes

- **CC1101 mode switching is critical:** The `on_transmit: cc1101.begin_tx` and `on_complete: cc1101.begin_rx` triggers in `remote_transmitter` are what make TX work. Without them, the CC1101 stays in RX mode and transmitting silently fails.
- **Single pin for RX+TX:** Both `remote_receiver` and `remote_transmitter` share GDO0 (D2) with `allow_other_uses: true`. The CC1101 component handles mode switching.
- **Board must be `nodemcuv2`:** Using `esp01_1m` causes "Cannot resolve pin name" errors for D-pin aliases.
- **Lambda types:** `x.code` in `on_rc_switch` is `uint64_t`, not string. Use `%llX` format.
- **dbuezas external component is dead:** Broken since ESPHome 2025.2. Use the native `cc1101:` component (available since ESPHome 2025.12.0).

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Chip ID: 0xFFFF | SPI wiring wrong or loose. Check all wires. Verify 3.3V power. |
| No codes when pressing remote | Check GDO0→D2 wire. Press remote close to antenna. Use `dump: all`. |
| Codes sniffed but TX doesn't work | Check `on_transmit: cc1101.begin_tx` trigger exists. Increase `repeat: times:`. |
| "Cannot resolve pin name" | Change board from `esp01_1m` to `nodemcuv2`. |
| Compilation error on x.code.c_str() | `x.code` is uint64_t — use `%llX` format, not `.c_str()`. |
| Alexa doesn't find device | Say "Alexa, discover devices". Check emulated_hue config in HA. |
| OTA upload fails | Check WiFi. Use USB as fallback. |
| Boot loop | Hold FLASH button during boot → safe mode. Re-flash via USB. |

## Files

| File | Purpose |
|------|---------|
| `radio-controller.yaml` | ESPHome config (CC1101 + RF RX/TX + 12 buttons + monitoring sensors) |
| `secrets.yaml` | WiFi password, API key, OTA password (git-ignored) |
| `.gitignore` | Excludes secrets and .esphome cache |

## HA Configuration Changes

These entries were added to the Home Assistant server (192.168.1.142):

- **configuration.yaml:** `input_boolean.bedroom_light` + `emulated_hue` entry
- **automations.yaml:** Two automations — bedroom light on/off via RF button press

## Technology Stack

- **ESPHome** 2026.3.1 (native CC1101 component)
- **Home Assistant** (API integration + emulated_hue for Alexa)
- **CC1101** TI sub-GHz transceiver (SPI, 433.92MHz ASK/OOK)
- **ESP8266** NodeMCU (WiFi, hostname: radio-controller, IP: 192.168.1.172)
- **Alexa** voice control via emulated_hue bridge
