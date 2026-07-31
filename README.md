# HIDAttack

A proof-of-concept USB HID man-in-the-middle built with [Nerves](https://nerves-project.org/).
The device sits between a Logitech G29 Driving Force racing wheel and the host it is
plugged into: it reads the wheel's HID input reports from `/dev/hidraw0`, rewrites the
steering-angle field, and re-emits the modified reports through a USB HID gadget
(`/dev/hidg0`) that impersonates the G29. Output reports (force feedback) coming back
from the host are forwarded to the real wheel unchanged.

It was built as a conference demo in 2019 (the branch history references `CLOUDSEC-2019-TW`,
and the default gadget descriptor identifies the manufacturer as "Trend Micro") to show that a
small Linux board with USB gadget support can transparently tamper with the input of a
driving simulator. It is demo code, not a product: the attacks are hardcoded, error
handling is minimal, and the repo has been unmaintained since 2019.

## Repository layout

This is a Nerves "poncho" project — three sibling Mix projects wired together by path
dependencies, rather than an umbrella:

| Directory | App | Purpose |
| --- | --- | --- |
| `app/` | `:app` | The attack logic: HID device reader, USB HID gadget, and the proxy that rewrites reports. |
| `ui/` | `:ui` | A Phoenix 1.4 web UI with buttons that trigger the attacks. Depends on `app`. |
| `fw/` | `:fw` | The Nerves firmware project. Depends on `ui`, and holds the target configuration. |

Version is tracked in the top-level `VERSION` file (`0.0.4-hf1`). The individual `mix.exs`
files all still carry the generator default `0.1.0`.

## How it works

`App.AttackProxy` is the core. On start it:

1. Starts `App.G29Device`, which opens the real wheel at `/dev/hidraw0` via
   [`hidraw`](https://github.com/udoschneider/hidraw) and reads its HID report descriptor.
2. Picks a gadget profile from the descriptor size — 157 or 123 bytes are treated as
   PS3 configurations, 160 bytes as PS4, anything else falls back to PS3 — and creates a
   matching USB HID gadget through
   [`usb_gadget`](https://github.com/nerves-project/usb_gadget) (configfs), cloning the
   Logitech vendor/product IDs.
3. Starts `App.G29Gadget` on `/dev/hidg0` and begins a 20 Hz tick.

Each input report is unpacked as `<<head::binary-size(4), steering_angle::little-size(16), tail::binary>>`.
The angle is normalised to −1.0…1.0 and transformed as:

```
new_angle = (angle * mirror_amplitude * cos(t * mirror_frequency))
          + (wiggle_amplitude * cos(t * wiggle_frequency))
```

Both effect parameters ramp towards their target over 5 seconds rather than jumping, so
the change is gradual.

## Attacks

`App.AttackDemo` wraps the raw proxy calls with the values used in the demo:

| Function | Effect |
| --- | --- |
| `App.AttackDemo.clear/0` | Pass-through (wiggle amplitude 0, mirror amplitude 1). |
| `App.AttackDemo.wiggle/0` | Adds a 0.2-amplitude oscillation to the steering angle. |
| `App.AttackDemo.mirror/0` | Inverts steering (mirror amplitude −1, frequency 0). |
| `App.AttackDemo.reboot_hid/0` | Calls `Nerves.Runtime.reboot/0`. |

The underlying API takes frequency and amplitude directly:

```elixir
# pass everything through unmodified
App.AttackProxy.clear()

# oscillate the steering angle: cos(t * 2.0) * 0.2 added to the angle
App.AttackProxy.wiggle(2.0, 0.2)

# invert the steering angle
App.AttackProxy.mirror(0.0, -1.0)
```

Frequencies are in radians per second (`t` is seconds since start, wrapping every
5 minutes); amplitudes are in normalised steering-angle units where 1.0 is full lock.

## Web UI

The Phoenix app exposes two routes (`ui/lib/ui_web/router.ex`):

* `GET /` — the stock Phoenix welcome page.
* `GET /attack` — the attack page. `?action=clear|wiggle|mirror|reboot_hid` invokes the
  corresponding `App.AttackDemo` function before rendering.

On the firmware the endpoint is configured to listen on port **80** (`fw/config/config.exs`).
The attack page loads Bootstrap, jQuery and Popper from public CDNs, so the browser
viewing it needs internet access. There is no `ui/assets` directory and `ui/priv/static`
is gitignored, so the `/js/app.js` referenced by the layout is not part of the repo.

## Requirements

* Elixir and Erlang as pinned in `.tool-versions`: Elixir 1.9.0-otp-22, Erlang 22.0.4.
  The `mix.exs` files require `~> 1.8` (`~> 1.5` for `ui`).
* `nerves_bootstrap` archive `~> 1.6` and the usual Nerves host tooling (`fwup`, etc.).
* A Logitech G29 Driving Force racing wheel on a USB **host** port of the target,
  exposed as `/dev/hidraw0`.
* A target with a USB **device/OTG** controller and Linux configfs USB gadget support, so
  the HID gadget can be created at `/dev/hidg0`.

`fw/mix.exs` lists targets `rpi`, `rpi0`, `rpi2`, `rpi3`, `rpi3a`, `x86_64` and `bbb`,
where `bbb` pulls a custom system fork,
[`gadget_system_bbb`](https://github.com/udoschneider/gadget_system_bbb) (`v2.3.0-us1`),
instead of the stock `nerves_system_bbb`. Combined with `nerves_init_gadget` being
configured for `ifname: "eth0"` (wired ethernet, not USB gadget ethernet — the USB device
port is taken by the HID gadget), the BeagleBone Black looks like the target this was
actually run on. The generic `rpi*` targets are the Nerves generator defaults and are not
known to have been used.

## Building and running

Build and burn the firmware from `fw/`:

```sh
cd fw
export MIX_TARGET=bbb          # or another target from mix.exs
mix deps.get
mix firmware
mix firmware.burn
```

Over-the-air updates to a running device use `nerves_firmware_ssh`:

```sh
./upload.sh hidattack.local
```

The device advertises itself over mDNS as `hidattack.local` and gets its address over
DHCP on `eth0`. Erlang distribution is enabled with node name `fw` in non-prod builds.

## Configuration

Because this is a poncho project, `fw/config/config.exs` is the configuration that applies
to the firmware build; the configs in `app/` and `ui/` only apply when those projects are
built standalone.

The one project-specific setting selects which gadget implementation `App.AttackProxy`
talks to:

```elixir
config :app, App.AttackProxy, gadget: App.G29Gadget
```

`fw` uses the real `App.G29Gadget`; `ui/config/config.exs` uses `App.G29GadgetMock`, a
no-op stand-in. Note that `App.AttackProxy` reads this with `Application.get_env/2` into a
module attribute, so it is resolved at **compile time** — changing it requires recompiling
`app`.

The mock only replaces the gadget half. `App.AttackProxy` still starts `App.G29Device`
against `/dev/hidraw0` on startup, so running the UI on a host machine without a wheel
attached will fail to bring up the supervision tree.

`fw/config/config.exs` also reads `fw/hidattack_rsa.pub` into
`:nerves_firmware_ssh, :authorized_keys`. **Replace this with your own public key** before
building anything you intend to keep. The checked-in secrets (`secret_key_base`, the
release cookie) are demo values and should be replaced too.

## Known rough edges

This is demo code — expect sharp corners. The test files are untouched generator stubs, the
per-project `README.md` files under `app/`, `ui/` and `fw/` are unedited boilerplate, and
there is some leftover dependency cruft from features that were removed.

## License

No license file is present in this repository.
