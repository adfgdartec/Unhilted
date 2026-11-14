# The Heap: room plan (milestone 1 demo)

Every room has one job. Map coordinates are in map cells (1 cell = 320x180 px
of room), used by the in-game map. "S1" = needs Shard I (Edge).

```
                       [07 Crane Yard]---[08 Conveyor Hall]---[03 Intake: BOSS]
                             |                  |
 [01 Under the Heap]---[02 Camp]---[05 Scrap Fields]---[09 Giant's Brow: mini-boss]
        |  (S1 wall)       |hatch        | drop (one-way)          [12 Compactor Pit]
 [04 Seep Tunnels]----+  [02b Hollow]  [10 Sinkhole]                (off 08)
        |             |       | brass door (after Shard I)
 [11 Old Tram Stop]   +-------+--[13 Underworks Gate: demo end]
   (secret)               (10 lands in 04: a loop back to camp)
```

| # | Room | Job | Key contents | Gate / secret |
|---|------|-----|--------------|---------------|
| 01 | Under the Heap | Wake up and learn the moves in order, in tunnels | Wake chamber -> step + 64 px spike pit (jump) -> girder chimney (climb) -> upper tunnel + 96 px spike gap (dash-jump) -> 80 px wall with a hook (throw, reel in) -> out to camp | S1 scrap wall in the chimney: Scrap Plating chip; vest nook |
| 02 | Scavenger Camp | Town: residents, dock, quests | Rusty tower, lookout, market, noticeboard; walk-in buildings: Rusty's shop, Dot's map room, Mags' garage (top-down interiors, like Undertale) | Hook alcove; hatch to 02b |
| 02b | The Hollow | First glimpse of the world below | Tablet lore, brass door, goggles, core cell | Brass door opens after Shard I -> 13 |
| 05 | Scrap Fields | Open combat field, crossroads | Spotters, Rustcrawlers on the junk walls | Drop to 10; side path to 09 |
| 07 | Crane Yard | Grapple traversal test | Hook chains over a dump pit, girders | Cap on a hidden hook route |
| 08 | Conveyor Hall | Industrial gauntlet before the boss | Conveyor belts, crushers (timing), Compactors | Dock right before the boss door; side door to 12 |
| 03 | The Intake | Boss: Intake Unit 7 | Arena | Shard I |
| 09 | Giant's Brow | Optional mini-boss | The brass giant's waking head | Port expansion + lore |
| 10 | Sinkhole | Vertical drop, collectibles on ledges | Ledges, hazards | One-way drop into 04: a loop back toward camp |
| 04 | Seep Tunnels | Hazard room: toxic sludge, dash gaps | Sludge pools (hurt + respawn at last safe ground) | Reached from 10 (drop) or 01 (S1 wall) |
| 11 | Old Tram Stop | Secret: lore + reward | A dead tram (fast-travel teaser), Wren's cloak | Breakable wall in 04 |
| 12 | Compactor Pit | Optional arena: waves | Compactors + crawlers | Chip reward |
| 13 | Underworks Gate | Demo ending | The brass door opens: steam, light, "to be continued" | After Shard I |

Critical path: 01 -> 02 -> 05 -> 07 -> 08 -> 03 (boss, Shard I) -> back to 02b -> 13.
Optional: 09, 10/04/11 loop, 12, every secret. Bottlecaps: 23 total in the Heap.
