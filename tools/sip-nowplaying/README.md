# SIP-gated Now Playing helper

Default sign is **soft** (library-validation bypass only) so the binary runs after `csrutil disable` **without** an AMFI boot-arg.

## Why
Direct `MRMediaRemoteGetNowPlayingInfo` often returns nil without `com.apple.private.mediaremote.read-write`. Claiming that private entitlement under hard AMFI → **Killed: 9**. Soft-sign loads MediaRemote for status/commands; `get` falls back to Homebrew `media-control` (MediaRemoteAdapter) for real metadata.

## Enable (SIP off)
```bash
~/.config/veil/tools/sip-nowplaying/build.sh
~/.config/veil/bin/veil-nowplaying-sip status   # sip=disabled mediaremote=ok adapter=ok
veil feature enable sip-nowplaying
```

## Optional private entitlements
```bash
# Needs AMFI relaxed (amfi_get_out_of_my_way=1) — Big Dawg consent only
VEIL_SIP_PRIVATE_ENTITLEMENTS=1 ~/.config/veil/tools/sip-nowplaying/build.sh
```

## Disable
```bash
veil feature disable sip-nowplaying
```

## Commands
`veil-nowplaying-sip status|get|play|pause|toggle|next|previous`
