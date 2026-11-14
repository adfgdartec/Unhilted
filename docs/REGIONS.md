# Unhilted: the five regions

A design bible for the whole world. `STYLE.md` holds the rules that apply
everywhere (resolution, outlines, light from the top-left, the effects layer);
this file is what changes from region to region. Status: **The Heap is built**
(13 rooms, demo). Everything else is the plan.

## The world in one picture

```
                         [5  THE SPIRE]          the corp tower; the CEO at the top
                               |
   [4  NEON SPRAWL] ===========+==========       the megacity, on its stilts above everything
          |  (Live Wire lifts you up)
   ------------------------------------------- the surface: smog, dusk, the city's shadow
   [1  THE HEAP]  landfill at the city's feet   <- you wake here
          |  brass door
   [2  THE UNDERWORKS]  steam city in the old maintenance tunnels
          |  Forge Gate (tram line 4)
   [3  THE FALLEN FORGE]  the smiths' drowned workshop, deepest down
```

You go **down** first (the past: brass, steam, fire) and then **up** (the
present: neon, glass, the corp). The Heap sits on the line between the two
worlds; the brass door in the Hollow is the first crack in that line.

**Shared rules across all regions**
- **Cyan is living power.** Only the robot, its blade, docks, and (late) the
  Spire's drain conduits use it. When the corp's pipes glow cyan, the player
  should realise the corp is draining the same power that runs the robot.
- **Brass means older than the city.** It appears faintly in the Heap, rules the
  Underworks and the Forge, and disappears completely in the Sprawl and Spire,
  except in hidden places the smiths left behind.
- Every region has: a town with its own family (`Lineage`), a local currency, a
  dock network, 15 to 20 rooms, a shard boss, a mini-boss, a shard gate you
  come back to, and 5 or 6 enemy types built around what that region's shard
  teaches.

---

## 1. The Heap (built)
**Role:** tutorial and home. The city's landfill, piled against its foundations.
The robot wakes in a pod buried under it.

| | |
|---|---|
| Mood | Scavenger hope under a dirty sunset. Warm, tired, friendly. |
| Light | Low smog sun from the upper right; warm rims on every top edge, cool slate shadows. Caves are cooler and darker with shafts of daylight. |
| Palette | Burnt orange to slate-teal sky, rust, oxidised container green, junk browns. Accent: **amber** (camp lights, goggle lenses). |
| Shapes | Lumpy piles, sagging cables, stacked containers, rusty scaffold towers. Nothing straight except corp machinery. |
| Terrain | `ground` (sunlit junk), `rock` (tunnels), `girder`, `container`, `ceiling`. |
| Backdrop | Megacity skyline with the dark Spire needle, trash conveyors, toppled crane, the buried brass giant. |
| Landmarks | The pod, the camp's rusty tower, the Intake (the corp's waste mouth), the brass head. |
| Music | `cave`, `camp`, `industrial`, `boss` |
| Town | Scavenger Camp. **Heapfolk:** hunched, patchwork coats, oversized boots, amber goggles. |
| Currency | Bottlecaps (23) |
| Enemies | Scrap Drone, Spotter, Rustcrawler, Compactor (+ redesign: the two drones need real sprites) |
| Mini-boss | The Brass Brow (the buried giant's waking head) |
| Boss | **Intake Unit 7**, the corp's garbage press |
| Shard | **I, Edge**: the blade pierces; cuts orange-marked scrap walls |
| Gate out | The brass door under the camp, which hums at your blade |

## 2. The Underworks
**Role:** discovery. A steampunk city nobody up top believes in, built in the
old world's maintenance tunnels. The people here kept the smiths' machines
running for 2,000 years without knowing what they were for.

| | |
|---|---|
| Mood | Wonder, then unease. Cosy and busy, but everything leaks and everyone is tired. |
| Light | Gaslight. Warm amber pools from lamps and furnace grates; green-black darkness between them; white steam catching the light. No sky. |
| Palette | Brass and copper, verdigris green, soot black, steam white, gaslight amber. Accent: **verdigris green** (the Bellows Kin signature). |
| Shapes | Round and riveted: pipes, gauges, gears, arched brick vaults, spiral stairs, pressure tanks. Curves everywhere (the opposite of the city's straight lines). |
| Terrain | New `brick` (arched vault brick), `pipe` (walkable pipe runs), `grate` (see-through walkway: steam rises through it), `gear` (rotating platforms). |
| Backdrop | Layers of vaults receding into haze, giant flywheels turning slowly, a waterfall of condensation, distant lit windows of Bellows Row. |
| Landmarks | Pipe Market (the town), Bellows Row (houses on pipes), The Pendulum (a building-sized regulator that keeps the whole city's pressure), tram line 4. |
| Music | New: `underworks` (music box and low brass), `pressure` (tense, ticking), boss |
| Town | **Pipe Market.** **Bellows Kin:** tall and thin, stovepipe hats, leather aprons, brass prosthetics (a hand, a jaw, an ear trumpet), soot-smudged faces, verdigris goggles. Walk-in shops: the gauge-maker, a tea house, the tram depot. |
| Currency | Brass cogs |
| Gimmicks | Steam vents that launch you; pressure valves (hit to open/close vents); rotating gear platforms; timed pistons. |
| Enemies | Piston Walker (stomps), Valve Turret (steam bursts, turn it off by hitting its valve), Bellows Bat (swoops on gusts), Clockwork Spider (on walls and ceilings), Boiler Bloat (swells and bursts) |
| Mini-boss | The Lamplighter (a tall automaton that snuffs the lamps; fight in the dark) |
| Boss | **The Pendulum**: a spinning flyball regulator. You swing around its arms. |
| Shard | **II, Swing**: pendulum swing on hooks and the wire, and wall-zip |
| Gate back | Swing gaps in the Heap's Crane Yard and Sinkhole (new secrets) |

## 3. The Fallen Forge
**Role:** the past. The workshop where the seven smiths made the sword, flooded
and half-cooled ever since the king destroyed them. The lore payoff region:
you learn what the sword was for and what the king did.

| | |
|---|---|
| Mood | Grief and awe. A huge, silent, sacred place. Slow, heavy, quiet music. |
| Light | Firelight from below: molten channels and embers light everything from underneath, so shadows fall **upward** (the only region that breaks the top-left rule, on purpose). Ash drifts like snow. |
| Palette | Black iron, ash grey, ember orange, molten yellow, cooled-metal violet. Accent: **ember orange**. |
| Shapes | Massive and angular: anvils the size of houses, chains, hammers, stone pillars carved with the seven-hammer mark, half-sunk statues of the smiths. |
| Terrain | New `iron` (black forged plate), `slag` (crusty cooled lava, can crack), `stone` (carved masonry), molten channels (hazard). |
| Backdrop | The great forge chimney rising into darkness, statues of the seven smiths, rivers of molten metal, an enormous broken anvil. |
| Landmarks | Cinder Hall (the town), the Seven Statues, the Quench Pool, the anvil where the sword was broken. |
| Music | New: `forge` (slow hammer rhythm, choir hum), boss |
| Town | **Cinder Hall.** **Forgeborn**, the smiths' descendants: broad and heavy, bare scarred forearms, leather and chain, hair tied back, a glowing ember-coloured burn mark (the signature), soft-spoken. Few left. |
| Currency | Ember beads |
| Gimmicks | Bounce the blade off angled iron shields to hit switches around corners; heat zones that drain health over time (stand in shade); cooling slag platforms that crumble. |
| Enemies | Ember Golem (slow, armoured until cooled), Slag Worm (bursts from molten channels), Anvil Drop (falls when you pass under), Ash Wraith (only visible near light), Hammer Sentry (smith-made guard, swings a wide arc) |
| Mini-boss | The Bellows Heart (a living furnace you must starve of air) |
| Boss | **The Warden of the Forge**: the last smith-made guardian, still guarding the broken anvil. Not evil: it thinks you are the king's agent. |
| Shard | **III, Ricochet**: the thrown blade bounces off surfaces and hits several targets |
| Gate back | Ricochet switches in the Underworks and Heap (shortcuts, the Hollow's sealed room) |

## 4. Neon Sprawl
**Role:** the present. The megacity on stilts above the Heap, the one you have
been looking up at since the start. Rich, loud, indifferent. The corp's world.

| | |
|---|---|
| Mood | Overwhelming, then lonely. Crowds that ignore you. Rain and ads. |
| Light | Night. Hard coloured light from signs, windows and ads; wet streets reflect everything. Sodium-orange streetlights below, pink and violet above. The only region with rain on by default. |
| Palette | Night indigo, hot pink, violet, wet asphalt black, sodium orange, ad-screen white. Accent: **hot pink** (city neon, already reserved for this). |
| Shapes | Straight lines and stacks: towers, billboards, fire escapes, cable bundles, elevated rails. Everything vertical. The opposite of the Underworks' curves. |
| Terrain | New `concrete`, `steel_deck` (catwalks), `glass` (see-through floors over long drops), `sign` (billboards you can stand on). |
| Backdrop | Endless lit windows, the Spire always in view and closer each room, maglev trains, giant animated ad screens. |
| Landmarks | The Underpass Bazaar (the town, under an overpass), the Stilts (the city's legs, reaching down to the Heap), the Corp Plaza at the Spire's base. |
| Music | New: `sprawl` (synth, rain), `chase`, boss |
| Town | **Underpass Bazaar.** **Sprawlers:** thin, tall, sleek jackets with collars up, visors and cheap glowing implants, pink-tinted, always looking at a screen. Plus Heap runaways who made it up here. |
| Currency | Corp scrip (the one currency that is ugly on purpose) |
| Gimmicks | Electrified wire that powers dead machinery: lifts, doors, fans, signs; conductive grapple rails; security cameras and alarm zones. |
| Enemies | Patrol Drone (corp version of the scrap drone, much cleaner), Laser Sentry, Enforcer (android cop with a riot shield), Holo Decoy (fake enemy that hides the real one), Ad Bot (harmless, follows you shouting; can be zapped for scrip) |
| Mini-boss | The Collector (corp repo agent who has been tracking the robot since the Heap) |
| Boss | **The Stilt Engine**: the machine that holds a district up; you fight it while the street tilts |
| Shard | **IV, Live Wire**: the tether carries current: power machines, shock enemies, zip on live rails |
| Gate back | Dead machinery all over the earlier regions (the tram to the Forge, the Heap's crane) |

## 5. The Spire
**Role:** the end. The corp's tower, where the world's power is drained into
the sky. The CEO, who is the king who destroyed the smiths, waits at the top.

| | |
|---|---|
| Mood | Cold, quiet and sterile, getting stranger as you climb. The last floors are where the corp's surface cracks and the old kingdom shows through. |
| Light | Even, shadowless white office light that gets colder as you go up; the drain conduits glow the robot's own **cyan** (the reveal). At the top: the old throne room, lit gold. |
| Palette | White, pale grey, cold blue-grey glass; drain-cyan; and at the very top, the king's tarnished gold and royal violet. Accent: **cold white**, then **gold**. |
| Shapes | Perfect geometry: grids, glass, identical corridors, logos. In the upper floors the walls peel back to show stone, brass and banners, the old palace the tower was built around. |
| Terrain | New `office` (clean panels), `glass`, `server` (rack walls), and old `palace` stone at the top. |
| Backdrop | The city far below, then clouds, then nothing (above the smog: the first clear sky in the game). |
| Landmarks | The Lobby, the Atrium, the Drain Core, the Throne. |
| Music | New: `spire` (sparse, clean, unsettling), the CEO's theme, the final theme |
| Town | None. A single hidden refuge: maintenance workers and a defector who help you. Every corp staffer looks identical: grey suit, blank mask face (they wear masks so nobody looks like anyone). |
| Currency | None. Nothing up here is for sale. |
| Enemies | Elite versions of earlier enemies, plus Suits (masked staff who only fight in groups), the Auditor (a floating eye that rewinds your last move), Drain Siphons |
| Mini-bosses | Rematches: a stronger Intake Unit, the Collector |
| Final boss | **The CEO / the King.** Polished, hooded and bright: what the robot could have become. Phase 1 corp, phase 2 king, phase 3 he takes the four shards. |
| Shard | **V, Whole**: the twist. The robot's own blade is the fifth shard, the one that was never set. Completing the sword is the ending. |

---

## Summary table

| # | Region | Direction | Feeling | Light | Accent | Town / family | Currency | Shard |
|---|---|---|---|---|---|---|---|---|
| 1 | The Heap | surface | hope, home | dusk sun | amber | Scavenger Camp / Heapfolk | bottlecaps | I Edge |
| 2 | The Underworks | down | wonder | gaslight | verdigris | Pipe Market / Bellows Kin | brass cogs | II Swing |
| 3 | The Fallen Forge | deepest | grief | firelight from below | ember | Cinder Hall / Forgeborn | ember beads | III Ricochet |
| 4 | Neon Sprawl | up | overwhelm | neon night, rain | hot pink | Underpass Bazaar / Sprawlers | corp scrip | IV Live Wire |
| 5 | The Spire | top | dread, then truth | cold white, then gold | white / gold | none | none | V Whole |

## Build order
1. **Heap** (done): demo.
2. **Underworks** (built; room plan in `UNDERWORKS_LAYOUT.md`). Where the build differs from the plan above:
   - The Pendulum is not fought by swinging (Swing is its reward, so the fight can't need it). You jump the low flyball, slide under the high one, and hit the open crown from two plain hooks.
   - The Clockwork Spider hops along floors; it doesn't climb walls or ceilings yet.
   - `gear` is a rotating-platform object (`GearWheel`), not a terrain style. The `pipe` terrain style exists but no room uses it as a floor yet.
   - Music: `underworks` (a 3/4 waltz) and `governor` (boss). There is no separate `pressure` track.
   - Not done yet: the "gate back" swing secrets in the Heap's Crane Yard and Sinkhole.
3. **Fallen Forge**, then **Neon Sprawl**, then **Spire**. Each region adds its terrain styles to `room.gd`, a backdrop set to `backdrop.gd`, a lineage to `data/lineages/`, a grade to `PostFX.GRADES`, and its music.
