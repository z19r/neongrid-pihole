# NEON//GRID

A synthwave cyberdeck theme for the Pi-hole v6 web UI: a scrolling perspective
grid floor, CRT scanlines, neon glass panels with clipped corners, a glitching
logo, a terminal ticker of 1337 quips, and neon chart colours.

Easter egg: `↑↑↓↓←→←→BA` (or type `1337`) toggles 1337 mode, which adds a hue
cycle and neon glyph rain. It is remembered per browser.

**Light mode — NEON//GRID DAYDREAM:** a pastel sunrise sky, frosted white glass,
dark text and deeper neons. The ticker and code blocks stay as dark terminal
windows. Switch with `sudo neongrid mode light|dark`.

## How it works

Pi-hole v6 only offers themes from a fixed list built into FTL, so the installer
(based on [pihole-lizard-theme][lizard]) takes over the `default-darker` slot.
It deploys the stock file with the NEON//GRID CSS appended, so any page the
theme doesn't style still gets the dark theme. A cron job puts it back after the
Sunday `pihole -up` and after a reboot. It runs side by side with Lizard, which
lives in `high-contrast-dark`.

[lizard]: https://github.com/hbrtkp/pihole-lizard-theme

## Use

```bash
just deploy      # self-test, copy to z19r-networking, install, doctor
just doctor      # check the wiring on the Pi
just restore     # back to stock, cron and command removed
```

On the Pi itself:
`sudo neongrid install|mode dark|light|reapply|doctor|status|restore`.

Switch between themes in Settings → Web interface / API → Theme
(`default-darker` = NEON//GRID, `default-light` = DAYDREAM, `high-contrast-dark`
= Lizard).

## Dev

`just fmt`, `just fmt-check` (prettier + shfmt, 80 columns), `just test`.

Code: MIT. Fonts: Orbitron and Share Tech Mono, both under the SIL Open Font
License 1.1 (see `theme/fonts-license/`).
