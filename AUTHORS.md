# Authors and Credits

## Raiden_MiSTer core

**Author**: Umberto Parisi ([rmonic79](https://github.com/rmonic79))

The original RTL source files for the Raiden-specific logic (under
`rtl/Raiden/`, excluding the third-party CPU cores listed below) and the
project wrapper `Raiden.sv` are copyright Umberto Parisi and distributed
under GNU GPL v3 or later.

## Third-party components

This core builds on top of excellent open-source projects. All third-party
sources retain their original copyright and license. The core as a whole
is distributed under **GNU GPL v3 or later** to stay compatible with the
most restrictive upstream (JTFRAME / JTCORES).

| Component | Author | Project | License |
|-----------|--------|---------|---------|
| **NEC V30** — V30 (8086-compatible) main/sub CPU core | Taken from the R-Type MiSTer core by Martin Donlon ([wickerwaka](https://github.com/wickerwaka)), who modified it; original WonderSwan V30 by Robert Peip ([@RobertPeip](https://github.com/RobertPeip), FPGAzumSpass) | [wickerwaka/Arcade-Rtype_MiSTer](https://github.com/wickerwaka/Arcade-Rtype_MiSTer) | GPL-3 |
| **T80** — Zilog Z80 (sound CPU) core | Daniel Wallner | [T80](https://opencores.org/projects/t80) | BSD-like |
| **JTOPL** — Yamaha YM3812 (OPL2) FM synthesizer | Jose Tejada ([@topapate](https://twitter.com/topapate)) | [jotego/jtopl](https://github.com/jotego/jtopl) | GPL-3 |
| **JT6295** — OKI MSM6295 ADPCM decoder | Jose Tejada | [jotego/jt6295](https://github.com/jotego/jt6295) | GPL-3 |
| **JTFRAME** — framework, clock enables, filters, mixer, shift registers | Jose Tejada | [jotego/jtframe](https://github.com/jotego/jtframe) | GPL-3 |
| **Savestate infrastructure** — ssbus, memory_stream, ram adaptors | Martin Donlon ([wickerwaka](https://github.com/wickerwaka)) | [wickerwaka/Arcade-TaitoF2_MiSTer](https://github.com/wickerwaka/Arcade-TaitoF2_MiSTer) | GPL-3 |
| **SDRAM controller** | Sorgelig / MiSTer-devel | [MiSTer-devel](https://github.com/MiSTer-devel) | GPL-3 |
| **MAME** — reference for Seibu hardware, memory maps, ROM decryption, timing | MAMEDev team | [mamedev/mame](https://github.com/mamedev/mame) | GPL-2+ |
| **sys/ framework** — MiSTer HPS/IO, OSD, video scaler, audio | Sorgelig / MiSTer-devel | [MiSTer-devel/Main_MiSTer](https://github.com/MiSTer-devel/Main_MiSTer) | GPL-3 |

Thanks also to **Andrea Bogazzi** ([@asturur](https://github.com/asturur))
for help with the core-side Analog H-Size implementation.

## Reference

- **Raiden arcade hardware** — Seibu Kaihatsu, 1990. This FPGA core is a
  reimplementation from hardware documentation, MAME source code, and
  observation of real hardware behavior. ROMs are **not** included and must
  be provided by the user.
- **MAME project** — invaluable reference for memory maps, timing, the Seibu
  video/sprite hardware and the main/sub ROM decryption.
  [mamedev/mame](https://github.com/mamedev/mame)
