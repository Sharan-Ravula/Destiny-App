# Vendored dependencies

## Swiss Ephemeris

- Upstream: https://github.com/aloistr/swisseph (official Astrodienst mirror)
- Commit: `3fd0f956d73898b91cc4f67cf18b21af656d1342` (2026-08-08)
- License: dual AGPL-3.0 / Swiss Ephemeris Professional License. Destiny
  uses the AGPL-3.0 option — see `LICENSE-swisseph` and `agpl-3.0.txt` in
  this directory.

Vendored, unmodified:

- `Sources/CSwissEphemeris/*.c`, `*.h` — the canonical `libswe` source set
  (upstream `Makefile`'s `SWEOBJ` list: `swedate swehouse swejpl swemmoon
  swemplan sweph swephlib swecl swehel`).
- `Sources/DestinyEngine/Resources/Ephemeris/sepl_18.se1`,
  `semo_18.se1` — compact planet/Moon ephemeris files covering 1800–2399
  CE, sub-arcsecond precision. Sufficient for all currently-planned use;
  extend with additional `sepl_*`/`semo_*`/`seas_*` blocks from the same
  upstream `ephe/` directory if births outside that range are needed.

Do not hand-edit vendored files — re-vendor from upstream so provenance
stays traceable.
