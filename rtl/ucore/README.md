# `rtl/ucore/` — NEC V30 cycle-exact core (imported, do not hand-edit)

These files are **not original work of this project**. They are imported
verbatim from **Martin Donlon** ([wickerwaka](https://github.com/wickerwaka)),
project [`nec_test`](https://github.com/wickerwaka/nec_test) — a
microcode-level reimplementation of the NEC V30 (µPD70116) in max mode,
validated against real V30 silicon.

- **Upstream**: https://github.com/wickerwaka/nec_test — `hdl/rtl/ucore/`
- **License**: GNU General Public License v2 (see the upstream `LICENSE`)
- **Aligned to upstream commit**: `c59d2054` — *"Fix REP termination before
  interrupt withdrawal"*
- **Local delta**: none. Every file here is byte-identical to upstream apart
  from line endings (verified with `cmp` after stripping CR).

## Why there are no per-file headers

The upstream files carry no license header (single author, project-level
`LICENSE`). They are kept **byte-identical on purpose**, so that a future
re-import is a straight copy and any divergence shows up immediately in a
`diff`. Adding our own headers inside them would break exactly that property —
hence this file, which carries the attribution for the whole directory.

**Do not hand-edit these files.** If a fix is needed, fix it upstream (or
report it) and re-import. That is what happened with `c59d2054`: the defect in
the interaction between `REP`-prefixed string instructions and interrupts was
found while integrating this core into Raiden, reported with a reproducer, and
fixed in `nec_test` itself — so every core using it benefits.

## What is *not* here

The bus adapter that connects this core to the Raiden buses is ours and lives
in [`rtl/Raiden/v30_new/`](../Raiden/v30_new/) (`v30_bus.sv`), together with
the earlier V30 core kept for reference. Those files carry their own headers.
