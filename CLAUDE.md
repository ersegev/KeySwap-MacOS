# KeySwap macOS

Native macOS background daemon that corrects bilingual Hebrew/English typing errors via F9 hotkey.

## Documentation

Read these files before implementing anything:

1. `Documents/KeySwap Design Doc - Translation First MVP.md` — primary spec (CEO-reviewed)
2. `Documents/KeySwap Engineering Design Doc.md` — 7 design changes from eng review + security review
3. `Documents/TODOS.md` — deferred work and open verification items

## Archived docs — DO NOT USE

`Documents/Arxiv/` contains 4 obsolete documents written before the Design Doc. They have known inaccuracies (wrong clipboard approach, wrong hotkey API, incomplete AppState enum, missing features). Do not read, reference, or implement from these files. They exist only as historical record.

## Source of truth hierarchy

1. Engineering Design Doc (for the 7 design deltas + security mitigations)
2. Design Doc - Translation First MVP (for everything else)
3. TODOS.md (for deferred work)
