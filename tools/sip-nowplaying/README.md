# SIP-gated Now Playing helper

Ships **now**. Works for real after Big Dawg turns **SIP off** on wake. Overnight desktop keeps using Homebrew `media-control` + AppleScript (`cider-bridge`).

## Why SIP
The private `MediaRemote` entitlement (`com.apple.private.mediaremote.read-write`) and library-validation bypass in `veil-nowplaying-sip.entitlements` are blocked by SIP + AMFI while SIP is enabled. The binary still builds and is inert/fallback-safe.

## Overnight (SIP on) — default
```bash
veil feature list          # sip-nowplaying is off
# music dropdown uses media-control / Music / Spotify as today
```

## After wake — enable
1. Boot into Recovery → Terminal → `csrutil disable` → reboot (Big Dawg does this; not overnight).
2. Rebuild and resign:
   ```bash
   ~/.config/veil/tools/sip-nowplaying/build.sh
   ~/.config/veil/bin/veil-nowplaying-sip status   # expect sip=disabled mediaremote=ok
   ~/.config/veil/bin/veil-nowplaying-sip get
   ```
3. Opt in (default off):
   ```bash
   veil feature enable sip-nowplaying
   ```
4. Optional: if AMFI still strips entitlements, after SIP is already off they may also need a documented AMFI boot-arg — only with their consent post-wake. See handoff.

## Disable / stay usable
```bash
veil feature disable sip-nowplaying   # back to media-control path immediately
```

## Commands
`veil-nowplaying-sip status|get|play|pause|toggle|next|previous`
