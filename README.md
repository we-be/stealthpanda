<div align="center">

<img src="assets/logo.png" alt="StealthPanda" height="300">

# StealthPanda

**Make Lightpanda invisible to anti-bot detection.**

[![License](https://img.shields.io/github/license/we-be/stealthpanda)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/we-be/stealthpanda)](https://github.com/we-be/stealthpanda)
[![Zig](https://img.shields.io/badge/zig-0.15.2-f7a41d)](https://ziglang.org)

| Memory | Execution | Fingerprint | Turnstile |
|:--:|:--:|:--:|:--:|
| **16x less than Chrome** | **9x faster** | **Chrome 131** | **WIP** |

</div>

---

Fork of [Lightpanda](https://github.com/lightpanda-io/browser) that patches its JS fingerprint to match Chrome 131. Same speed and memory advantages, none of the bot signals.

```
         Lightpanda                          StealthPanda
   ┌──────────────────┐               ┌──────────────────┐
   │  Fast & light    │               │  Fast & light    │
   │  JS via V8       │               │  JS via V8       │
   │  CDP compatible  │               │  CDP compatible  │
   │                  │               │                  │
   │  ✗ Bot signals   │    ──────▶    │  ✓ Chrome UA     │
   │  ✗ Empty plugins │               │  ✓ 5 PDF plugins │
   │  ✗ No canvas     │               │  ✓ Canvas stub   │
   │  ✗ No audio ctx  │               │  ✓ AudioContext  │
   │  ✗ 0x0 screen    │               │  ✓ 1920x1080    │
   └──────────────────┘               └──────────────────┘
```

## Quick Start

```bash
git clone https://github.com/we-be/stealthpanda.git && cd stealthpanda
make build-dev
./zig-out/bin/lightpanda serve --host 127.0.0.1 --port 9222
```

Connect with Puppeteer:

```js
import puppeteer from 'puppeteer-core';

const browser = await puppeteer.connect({
  browserWSEndpoint: "ws://127.0.0.1:9222",
});

const page = await (await browser.createBrowserContext()).newPage();
await page.goto('https://example.com');
// fingerprint matches Chrome 131
```

Custom viewport:

```bash
./zig-out/bin/lightpanda serve --screen-width 1440 --screen-height 900 --host 127.0.0.1 --port 9222
```

## Fingerprint Coverage

| Signal | Lightpanda | StealthPanda | Phase |
|--------|-----------|--------------|:-----:|
| `navigator.userAgent` | `Lightpanda/1.0` | Chrome 131 UA | 0 ✅ |
| `navigator.vendor` | `""` | `"Google Inc."` | 0 ✅ |
| `navigator.plugins` | Empty | 5 Chrome PDF plugins | 0 ✅ |
| `navigator.webdriver` | `true` | `false` | 0 ✅ |
| `screen` / `window` dimensions | `0 x 0` | Configurable (default 1920x1080) | 0 ✅ |
| `canvas.toDataURL()` | Throws | Valid PNG data URL | 0 ✅ |
| `AudioContext` | Missing | Stub (state, sampleRate, baseLatency) | 0 ✅ |
| TLS fingerprint (JA3/JA4) | Default libcurl | Chrome-matching | 1 |
| Canvas rendering | Placeholder | Real pixels via z2d | 2 |
| WebGL fingerprint | Missing | Stub/emulated | 3 |
| CDP automation signals | Exposed | Masked | 4 |
| Headed rendering | None | Optional GUI mode | 5 |

## Roadmap

| Phase | What | Status |
|:-----:|------|:------:|
| 0 | Browser identity & API stubs | ✅ |
| 1 | TLS fingerprint mimicry | Planned |
| 2 | Canvas rendering (z2d) | Planned |
| 3 | WebGL fingerprint | Planned |
| 4 | CDP stealth | Planned |
| 5 | Headed rendering | Planned |

**Turnstile MVP = Phases 0–4.**

## Build

Requires [Zig](https://ziglang.org/) 0.15.2, [Rust](https://rust-lang.org/tools/install/), and system deps for V8/libcurl/html5ever.

```bash
# Debian/Ubuntu
sudo apt install xz-utils ca-certificates pkg-config libglib2.0-dev clang make curl git

# Or Nix
nix develop

make build-dev   # debug
make build       # release
make test        # unit tests
```

## Test

```bash
# Fingerprint verification (start CDP server first)
node test_fingerprint.js
```

## Upstream

Tracks [lightpanda-io/browser](https://github.com/lightpanda-io/browser) `main`. Periodically rebased to stay current.

## License

AGPL-3.0 — same as Lightpanda. See [LICENSE](LICENSE).
