# Bird Hunting audio source and Roblox IDs

These three files are ready for Roblox Asset Manager import:

| File | Studio target | Roblox asset ID | Format |
| --- | --- | --- | --- |
| `SniperFire.ogg` | `SoundService.KenopsiaAudio.SFX.SniperFire.Primary` | `118803023612410` | Vorbis, 44.1 kHz, stereo |
| `SniperReload.ogg` | `SoundService.KenopsiaAudio.SFX.SniperReload.Primary` | `83110281478101` | Vorbis, 44.1 kHz, stereo |
| `BulletRicochet.ogg` | `SoundService.KenopsiaAudio.SFX.BulletRicochet.Primary` | `83668417079973` | Vorbis, 48 kHz, stereo |

## Verification

All three assets were preloaded successfully in Studio and returned `IsLoaded = true`. Their IDs are wired into the targets above. The release mix uses music `0.24`, fire `1.45`, reload `1.70`, and ricochet `1.10`. During any of those three weapon effects, `GoreClient` locally ducks Bird Hunting music to `0.055`, then restores it smoothly to `0.24`; live Client tests verified the dip and restoration for all three events while retaining positional rolloff.

Source pack: **Rust & Blood - SFX Library**. Its local game-asset license permits use and modification in games but forbids standalone redistribution or inclusion in asset packs. Treat this folder as an upload handoff, not a distributable sound pack.
