# Unhilted: progress and honest status

Last updated: 2026-11-05 (Ultrakill-style movement, the whole Underworks). "Tested" means covered by the automated suites, run headless in Godot 4.4.1:
- `tools/smoke_test.tscn`: 190 checks, systems, the camp and the walk-in buildings, map data for both regions
- `tools/heap_test.tscn`: 42 checks, a bot that plays through the Heap's rooms, the starting tunnels included
- `tools/underworks_test.tscn`: 93 checks, a bot that plays through the Underworks

It can also mean looked at in rendered screenshots. **Nothing has been hand-played with a keyboard or controller yet, and none of the audio has been listened to by a person.**

## Showcase demo build (2026-11-14: now the Heap up to the first boss)
The opening of the game, about 3 minutes (an estimate, not a timed play session). It ends at a natural point; there's no timer.
- Under the Heap (wake-up scene, the tunnels that teach the moves) -> Scavenger Camp -> Scrap Fields -> Crane Yard -> Conveyor Hall -> the Intake (INTAKE UNIT 7). It ends once Shard I is attached and its scene has played, on an "end of demo" card, then returns to the title.
- Exits off the route (the Hollow hatch, the Sinkhole, Giant's Brow, the Compactor Pit) are shut and solid in the demo. The camp's walk-in buildings stay open.
- Only active in the demo exports (preset feature `demo`) or with `-- demo` on the command line. The full game is unchanged.
- Never saves. Dying respawns you at the entrance of the room you were in. 45 s without input resets to the title.
- Export presets for Windows, Linux and macOS (`export_presets.cfg`, output in `build/demo/`). The macOS build is unsigned (right-click > Open the first time). ETC2/ASTC texture import is enabled (macOS universal builds need it).
- `tools/demo_test.tscn` (25 checks, run with `-- demo`) crosses every room by its exits and fights the boss through its real states. **Not yet played by hand.**
- An earlier version of the demo (12 Nov) was the Underworks slice (Governor, Shard II, Swing Galleries); that's replaced.
- Restored the art-style variant generator (`tools/art/build_room_art.py`) and its off-by-default wiring after a workspace reset.

## Ultrakill-style movement and the Underworks (previous increment)
**Movement** (fluid, not more buttons; about 1.5x faster than before):
- Momentum: speed above run speed is kept in the air and bleeds off slowly; on the ground it bleeds off faster.
- Slide (Ctrl / C / LT, or down while running): low hitbox (the hurtbox ducks too), keeps speed; slide-jump goes further. Land into a slide.
- Wall slide and up to 3 wall jumps between landings, with a little wall coyote time.
- Dash-jump keeps 75% of the dash; dash into a slide; grapple fling (hold the direction you're flying) and whiplash jump.
- Healing by fighting up close: 3 close hits (melee, zip strike, or a blade hit within 56 px) restore a cell; banked when full. HUD notches.
- **Shard II, Swing:** with the blade on a hook or brass ring, press throw again to hang. Lean to pump, up/down to climb the wire, jump to let go with the speed. Dash still whiplashes. Brass rings only hold with Swing. A blade stuck in a wall stays longer, and dash zips you to it.

**The Underworks: 15 rooms** (`tools/level/build_underworks.py`, plan in `docs/UNDERWORKS_LAYOUT.md`):
- Pipe Market town of the Bellows Kin (new lineage: tall, tailored coats with brass buttons, stovepipe hats, monocles, brass arms; NPC canvas is taller for the hats).
- Three walk-in buildings: Gauge & Gear (Gilda's shop), The Kettle (tea house; Wick's quest), Line 4 Depot (Hale's quest, Quill sells the map).
- Gimmicks: steam vents (lift or scald, on a rhythm or switched by a valve), valves, gear-wheel platforms, piston lifts, gas lamps you can snuff and relight, boiling water, brass swing rings.
- Enemies: Piston Walker (stomp shockwaves you jump), Valve Turret (steam jet; any hit stalls it, a linked valve kills its pressure), Bellows Bat (swoops), Clockwork Spider (leaps, rewinds after three), Boiler Bloat (swells and bursts; killing it still bursts it, and the burst hurts other enemies).
- Mini-boss: **the Lamplighter** (sweeps a pole at chest height: slide under or jump; snuffs lamps until only its lantern shows; relighting a lamp beside it dazzles it). Drops a core cell and its lantern.
- Boss: **the Pendulum** (flyballs sweep the hall, harmful only on the near pass: jump the low one, slide under the high one; floor vents; the crown opens on overpressure and can only be hit from hook height). Drops Shard II.
- Steam Trials wave arena (core cell), Clockmaker's Loft secret (port expansion), Old Tram Tunnel with the sealed Forge Gate.
- Three quests: Pressure Drop (relief valves), The Last Lamplighter, Letters Home. Items found before taking a quest still count.
- Currency: Brass Cogs, 30 (13 found, 17 from quests). Each region now has its own coin sprite and HUD icon.
- Two new chips (Piston Legs: jump higher; Ball Bearings: run faster) and two cosmetics (Bellows Frock Coat, Verdigris Monocle), drawn in both the side-view and top-down sprite generators.
- Art (`tools/art/build_underworks.py`): vault and works backdrops, brick/pipe/grate/plate terrain, props, shopfronts, signs, interiors, enemy and boss sprites. An `underworks` colour grade.
- Audio: `underworks` (a 3/4 waltz) and `governor` music; steam, valve, gear, bat, burst and wire-creak sounds. Not listened to.
- A title card the first time you enter a region. The Heap's demo ending is gone: the Gate's stairs now lead down into the Underworks.
- Rendered screenshots checked for the market, Row, Gearworks, Lamplighter, Governor, Galleries and all three interiors. One fix came out of that: Tamsin was hidden behind her bar.

**Found and fixed by the Underworks bot:** two pieces of geometry left exactly 28 px of headroom (the robot's height), so you couldn't walk under them (Condensate Falls stair, Gauge Hall catwalk step). A ring sat beyond reach once you allow for falling while the blade flies. A walkway sat over a swing's release point, so you hit its underside. The Falls had no way back up from the Cistern side.

**Found while recording the trailer:** the Governor's two hooks hung about 200 px up, beyond the 150 px wire, so the crown couldn't be reached in real play (the test had applied hits directly). They now hang at y 150, and the test throws at one for real.

**Not done yet / differs from the plan in REGIONS.md** (listed there too):
- The Heap's "gate back" swing secrets (Crane Yard, Sinkhole) aren't built.
- The Clockwork Spider stays on floors; it doesn't climb walls or ceilings.
- The Governor isn't fought by swinging, because Swing is its reward.
- Boss, mini-boss and arena numbers come from design, not play. The bot tests hit the bosses directly; they check the fights' rules and geometry (which heights you can slide under or jump), not that they're fun or fair at full speed.
- Region 3 (the Fallen Forge) doesn't exist; the Forge Gate is sealed.

## UI to match the shop, a tunnel start, walk-in buildings (previous increment)
**All UI now uses the shop's look**, from the same generated art (`tools/art/build_ui.py`):
- Every panel is a riveted iron frame with brass corner brackets.
- Every button is an iron plate (cyan bead line and bright brass when focused, dull when disabled).
- Screen titles sit on engraved brass nameplates; readouts and previews sit in wooden display cases.
- **Title:** plate buttons. **Chassis select:** each chassis on a brass plinth in a display case.
- **Dock menu:** nameplate and a battery icon. **Settings:** plate rows.
- **Wardrobe:** the robot on a plinth in a case; each outfit slot is a shop-style card with the item in a brass well.
- **Port loadout:** the readout moved into a display case.
- **Journal:** folder tabs and a JOURNAL nameplate.
  - Quests are iron cards with an ink stamp (ACTIVE / TURN IN / DONE) and brass checkboxes per objective.
  - Lore entries are plates beside a display case.
  - Controls are drawn as key caps.
- **Dialogue box:** iron frame, speaker on a brass nameplate. **HUD:** the [E] prompt and toasts sit on iron plates.
- Still plain: the HUD numbers and the boss bar.

**Under the Heap is now tunnels you work through** (rebuilt in `tools/level/build_heap_rooms.py`, 1280x720). It teaches one move at a time:
1. The wake chamber.
2. A tunnel with a step and a 64 px spike pit (jump).
3. A 160 px chimney of staggered girders (climb). A vest nook opens off one girder, and the Shard I scrap wall hides the Scrap Plating chip.
4. The upper tunnel: Tinker's power cell on a hump, a drone, and a 96 px spike gap you can only clear with a dash-jump.
5. An 80 px wall too tall to jump, with a hook above it (throw, reel in), then out to the camp.

More on the new room:
- Scratched-in hints explain the dash-jump and the hook.
- The walls are a new "rock" style: compacted junk drawn edge by edge, so tunnels carved from many rectangles read as one mass, with lit lumpy tops, dripping undersides and a soft inner band.
- The old flat layout lives on as a test fixture (`tools/fixtures/test_pit.tscn`), so the smoke test's system checks don't depend on level design.

**Bugs the bot found while building it:**
- The first drone could kill the robot during the intro dialogue, while it can't move. It now waits at the foot of the chimney.
- A 96 px-tall tunnel left only 64 px of headroom over the step, which cut the jump short. That tunnel is now 128 px tall.
- The Spotter hovered in the hook's throw line. It now guards the dash gap.
- Not in this room: the Seep's lowest shaft girder left zero clearance over the robot's head and could block walking. It's now raised 8 px.

**Walk-in buildings, top-down like Undertale:**
- In the camp, Rusty's shop, Dot's map room and Mags' garage have shopfronts with doors. Press [E] in a doorway to go in.
- Inside is a flat pixel room seen from above, the way Undertale does it: the back wall facing you across the top, a tiled floor, black beyond the walls, and furniture standing on the floor. Everything sorts by its feet, so you walk behind shelves and in front of counters. The camera follows you and never shows past the room.
- (An earlier 3D take on these rooms was replaced at your request.)
- The robot has new top-down walking sprites (`tools/art/build_overworld.py`): front, back and side, 4 frames each, for both chassis and every outfit piece (hood tip, capes and their trims, goggles, plate mask, vest stripes, her braid). They're drawn with the same kit as the side-view sprites, so it's recognisably the same robot. Left is the side view mirrored.
- Walk in 8 directions. [E] looks at things, with Undertale-style flavour text on shelves, posters, maps, the globe, the half-built robot and more. People come first when they're in reach: talk to Rusty across her counter to open the shop.
- The shopkeepers are their ordinary NPC nodes standing in the room, so shops and dialogue work unchanged. They turn to face you.
- Walk down over the doormat to leave: you're back outside the same door. The camp stays loaded but paused while you're inside.
- Code: `scripts/interior/` (room, player, overworld visuals, prop, NPC) and `scripts/world/door.gd`; `WorldManager.enter_interior / leave_interior`. Rooms are generated by `tools/level/build_interiors.py`; art by `tools/art/build_interiors.py`.

**Tests:** smoke test 178 (15 new for the walk-in shops):
- the doors exist, and the shopkeepers moved indoors
- entering hides the camp and shows the room from above, and the camp stays loaded
- top-down sprites for the chassis and outfit, and you come in facing into the room
- 8-way walking; walking down shows the front, walking left the mirrored side
- shelves are solid, and Look is offered by a shelf
- [E] at the counter is for Rusty and opens her shop
- the doormat brings you back out at Rusty's door
- Mags talks to you

Heap test 42 (14 new):
- the starting tunnels played start to finish: plain jumps, the chimney, the power cell
- the 96 px gap fails with a plain jump but works with a dash-jump
- the wall can't be jumped, but the hook works
- the camp exit, the vest nook, and the scrap wall before and after Shard I
- every building door has a real interior and return marker

The Heap test's bot was also made stricter:
- `hop_to` now has to arrive horizontally, not just at the right height.
- It re-applies invulnerability after hazard respawns.
- It clears an enemy only where the enemy's body could block a traversal check.

**Checked in screenshots:** every UI screen, all six points along the tunnel route, the three shopfronts, all three interiors (with Rusty behind her counter), and the dialogue box indoors.

**Not verified by hand:**
- How walking indoors feels: speed 4.2 units/s, the camera follow.
- How the tunnel obstacles feel on a real keyboard.
- How the top-down walk cycle reads in motion (checked as sheets and stills only).
- NPCs still use their side-view family looks indoors (they turn left and right but have no front or back views).

## Map and shop UI pass (previous increment)
Both screens were flat rectangles and lines. They now use generated pixel art built the same way as the port sockets (`tools/art/build_ui.py`: one palette, top-left light, 9-slice frames).

**Map:**
- Dot's ink map on parchment, with torn edges.
- Each room is drawn from its real level geometry (the room scene's `solids`, read without instancing the scene). You see the actual caves, ledges and shafts, and passages show where rooms meet.
- Visited rooms get a wash, and the room you're in gets an amber wash. Rooms known only from Dot's map are drawn in broken pencil lines. Without the map, everything you've seen is a pencil sketch.
- Ink icons (dock, shop, boss, mini-boss, way on, camp), a title ribbon, a compass, a legend, and a hood pin for the robot.
- Hover a room to read its name.

**Journal:** folder tabs, and a bigger page (608x336).

**Shop:**
- A striped awning, the keeper's portrait in a wooden frame, and the wallet in a coin tray.
- Wares are riveted iron cards with brass corner brackets. Each item sits in a round brass well, like a port socket. Prices are on paper tags (red ink when you can't afford it), and OWNED / SOLD OUT is an ink stamp.
- The selected item floats over a brass plinth in a display case, with a brass Buy plate (it greys out when disabled).
- The repair kit, core cell and map have proper 24 px icons. Before, 7 px icons were scaled up 4x.

**Tests:** 5 new checks:
- the map reads every room's geometry
- the map texture is actually inked
- Dot's map shows unvisited rooms but hides secrets
- the kit's 24 px icon
- the brass Buy and display case

**Checked in screenshots:** both shops (affordable, unaffordable and owned states), the map with and without Dot's map, and the journal tabs.

**Not verified by hand:** mouse hover on the map, and how the shop feels with a controller.

## Milestone 1: the Heap as a playable demo (previous increment)
The plan: 5 regions (Heap, Underworks, Fallen Forge, Neon Sprawl, Spire) and 5 shards. Milestone 1 finishes the Heap as a self-contained demo that ends at the door to the Underworks. Layout and the job of each room: `docs/HEAP_LAYOUT.md`.

**13 rooms (4 before).** Nine new ones, built by `tools/level/build_heap_rooms.py`, which regenerates the .tscn files:
- **05 Scrap Fields**: open crossroads; Spotters and Rustcrawlers; a hill and a braced crane mast climb up to the Crane Yard.
- **07 Crane Yard**: a hook-to-hook chain over a spike pit.
- **08 Conveyor Hall**: you push against a belt while timed crushers drop. A service ladder leads up to the Compactor Pit, and a dock sits before the boss door.
- **12 Compactor Pit**: optional arena. The hatch seals and three waves come. The reward is the new **Piston Heart** chip.
- **09 Giant's Brow**: optional mini-boss, the brass giant's head.
- **10 Sinkhole**: a ledge climb with collectibles; a one-way drop into the Seep.
- **04 Seep Tunnels**: toxic sludge pits, two of which need a dash-jump.
- **11 Old Tram Stop**: secret behind a breakable wall. A dead tram (fast-travel teaser), lore, and Wren's coat.
- **13 Underworks Gate**: the demo ending.

**Critical path:** Under the Heap > Camp > Fields > Crane Yard > Conveyor Hall > Intake (boss, Shard I) > back to the Hollow > brass door > Underworks Gate.
- Shard I also opens a shaft from the Hollow floor down into the Seep, which closes the loop.

**New enemies:**
- **Rustcrawler**: clings to a ceiling, drops when you pass under, then chases.
- **Compactor**: armoured front, so the blade glances off it. It winds up, charges, and is stunned after hitting a wall: hit it from behind or during the stun.
- **Brass Head (mini-boss)**: the eye is the only weak point and can't be hurt while shut. Attacks: a sweeping eye beam, falling debris, steam vents. It drops a port expansion and stays defeated.

**Hazards:**
- Sludge and spikes cost one health and put you back on the last safe ground. Safe ground is recorded after a 0.25 s delay, so you never respawn on the lip of a pit.
- Conveyor belts carry you at their full speed.
- Crushers run on a visible timed cycle.

**Map and journal:**
- Esc opens a journal: the map, collected lore, and settings.
- Tab or M opens the map directly.
- Rooms are revealed as you visit them. The full Heap map is sold by Dot, the mapmaker.
- A test checks every map rectangle against its room's real size.

**Audio, synthesized by `tools/audio/build_audio.py`:**
- 41 sound effects, including blade throw, hit, pin, recall, glance, hook, slam, damage, dock and UI.
- 6 music loops: cave, camp, hollow, industrial, boss, title.
- An `AudioManager` autoload with Music and SFX buses, crossfades, a per-room `music` setting and a boss override.
- Volume sliders in Settings, saved.
- **Unheard by a person:** the sounds were checked only as waveforms and by duration, so mix levels and quality are unknown.

**Demo ending:** the brass door rolls aside once you hold Shard I. Stairs lead down into steam and light. Then: dialogue, credits, "to be continued", and you're returned to the Hollow so you can keep exploring.

**New content data:**
- Piston Heart chip
- Conductor's Coat (cloak_wren)
- Brass Goggles shop entry
- Dot's map item
- The Heap now has 23 bottlecaps.

**New art (generated):**
- Rustcrawler, Compactor and Brass Head sprites. The head was redrawn after review: the first pass read as an egg.
- Hanging junk, noticeboard, telescope, hatch, brass door (shut and open), pipe runs, lore tablet, water tank, dish, tram.
- Scaffold towers and light shafts.

**Level bugs the playthrough bot found (and were fixed):**
- The camp tower and the Fields mast had overhangs that blocked jumps.
- The hook alcove's reel-in path clipped a ledge.
- The conveyor's belt formed a 12 px wall.
- A 120 px sludge pit couldn't be cleared even with a dash-jump. It's now 100 px.

**Checked in screenshots:** Fields, Crane Yard, Conveyor Hall, Sinkhole, Seep (sludge pits), Tram Stop, Underworks Gate, the brass head with its beam firing and its boss bar, the journal map.

**Not verified:**
- How any of the new rooms feel in hand.
- Mini-boss and arena difficulty.
- Whether the sludge respawn is too lenient or too harsh.
- The whole audio mix.

## Audit (earlier increment)
Foundation was stable (45/45 checks). Code review found these gaps against the master brief:

| # | Problem | Severity | Status |
|---|---|---|---|
| 1 | Shard I could only be obtained with a debug key, so the progression loop did not exist | Critical | Fixed: boss drops it |
| 2 | One enemy type; throwing the blade had little tactical purpose | High | Fixed: Spotter drone |
| 3 | Blade damaged everything; no armour interaction | High | Fixed: armour glances, blade bounces back |
| 4 | Death penalty silent; a second death erased the first drop without telling you | Medium | Fixed: both cases announced |
| 5 | Screen shake and hit-stop could not be turned off | Medium | Fixed: settings menu, saved |
| 6 | Hits only had shake/hit-stop as feedback | Low | Fixed: hit sparks |

## Implemented and tested
- Title, chassis select (girl/boy), pronoun tokens in dialogue
- Movement: run, variable jump, coyote time, jump buffer, dash, knockback, i-frames
- Melee: 2-hit combo, up/down attacks, pogo
- Tethered blade: 8-way throw, auto-recall, damage on the way out and back, wall stick, grapple with aim-assist, glances off armour
- Enemies: Scrap Drone (ground patrol), Spotter Drone (ranged flyer, 0.6 s eye glow + aim line before firing, bolts can be cut out of the air)
- **Boss: INTAKE UNIT 7** (new): armoured while raised; track, warn (0.55 s red drop line), slam, 1.35 s punish window with open core; bale drops with marked landing spots; phase 2 at half health (faster, shorter window, magnet pull you can resist by running or hooking a side anchor); door locks during the fight; health bar; stays beaten
- **Shard I** (new): dropped by the boss, attach dialogue, the blade then pierces and splits orange-marked scrap walls; the Pit's wall now opens on return to a reward (the full progression loop works)
- 3 rooms: The Pit, Scavenger Camp, The Intake (boss arena)
- Ports/chips (6 chips, overclock), outfits (8 pieces) with wardrobe, two currencies, death drop/recovery, Tinker quest, Rusty shop, Pip, charging dock, save/load, pause, settings

## Art pass (this increment)
Everything except characters now has real pixel art, generated from one palette by scripts in `tools/art/` (see STYLE.md):
- Two tilesets (Heap scrap ground, corp industrial plating) with automatic top caps, edges and undersides.
- Parallax backdrops: Heap night sky with the megacity and the Spire; Intake bay wall ("07") with girders.
- 21 props, each placed for a reason: the robot's cracked brass pod at the wake-up spot; the half-buried bus as the camp landmark; Tinker's generator and the camp lights, dark until his quest is done; Rusty's stall and flickering SCRAP neon; Pip's tarp; an Intake warning sign at the east exit; chutes, bale stacks and warning lamps in the Intake.
- Sprites for the charging dock, crane-hook grapple points, the orange-marked scrap wall, the boss door, every pickup, both projectile types, landing dust, and banded additive light.
- UI: pixel fonts (Silkscreen 8/16, Pixelify Sans 16 for dialogue), salvaged-terminal panels, cursor bar, battery-cell health, currency and kit icons, title screen over the Heap skyline.
- Reviewed in rendered screenshots at game scale; four assets were redrawn after review (face-like brazier, unreadable tyres, flag-like car cube, floating camp lights), and the 8 px body font was swapped for one built on an 8 px grid.

## Follow-up fixes
- The Hollow's way out (west tunnel at floor level) was an unlit gap; it now has a warm tunnel glow, and a test walks out through it.
- The camp's climbable platforms are now one rusty steel tower: a `Scaffold` node draws legs, ties, X-bracing, rivets and rust streaks behind the solids (a shade darker so the girder floors read as standable), with a beacon mast and rag flag on top. The three western ledges stand on braced stilts, and the hidden alcove hangs from two chains. No collision changes, so every reachability test still applies.

## Shop, cave start, bigger camp + the Hollow, real character sprites (previous increment)
**Throw vs melee.** The thrown blade now does 2 damage, melee 1 (Rush slash +1, zip strike melee+1, charged throw x2 = 4). Throwing is the strong, committal option; swing-spamming on bosses is half as effective.

**Shop.** Rusty's stall is a proper screen: shopkeeper portrait and greeting, wallet with currency icons (counts down when you buy), a grid of item cards (icon well, name, price in its currency; red when you can't afford it; stamped SOLD OUT / OWNED), and a detail panel with a large icon, type (CHIP, 1 PORT / OUTFIT, CLOAK / CONSUMABLE / UPGRADE), description and a Buy button. Chip cards use the chip emblems; outfit cards use icons generated from the outfit sprites.

**Starting room is a cave under the heap.** "Under the Heap" (was "The Pit"): jagged packed-junk ceiling (new `ceiling` solid style with dangling cable ends and grit), a two-layer cave backdrop (compacted strata with a car, fridge, washer, TV and bedsprings pressed into it; junk pillars rim-lit by the shafts), daylight shafts leaking through cracks with drifting dust and real light where they land (the strongest one falls on your wake-up pod), hanging junk (rebar bundles, a clump with a cable tail, a fridge door on a chain), a cooler "cave" colour grade, and a glowing tunnel mouth out to the camp. All the climb, hook and gate geometry is unchanged, so the existing reachability tests still pass.

**Bigger camp (960 -> 1920 px wide, plus 200 px of height).**
- Scrap tower: two staggered columns of containers and girders (40 px steps, clear jump paths) up to a lookout with a telescope you can look through (lore: the Spire is pulling the smog toward it). A bottlecap at the top.
- Hidden alcove: from the lookout, hook the crane hook above and reel in to a secret ledge with a bottlecap and scrap.
- Market row: noticeboard (four readable notes, one hinting at the hatch), Mags the mechanic and Dot the would-be mapmaker (new heapfolk residents with idle lines), a tarp stall, string lights, a brazier, a lamp, a water tank, a bottlecap behind the crates. The Intake exit moved to the new east end.
- **The Hollow (secret):** a rusted hatch in the market floor breaks after 3 hits (pogo works). Falling through leads to a hidden cave room under the camp: brass pipes and a steam leak, an old tablet with lore about the seven smiths and the sword, a sealed round brass door that hums like your blade (foreshadows the steampunk Underworks; "Not yet."), a drone, two bottlecaps, scrap, a Core Cell (+1 max health) and the new **Brass Goggles** mask. The hatch stays broken; a tunnel leads back up to the market.
- Heap bottlecap total is now 15 (10 before).

**Character and blade sprites (replacing the placeholder shapes).** `tools/art/build_character.py` poses a small 2D rig (hips, knees, feet, shoulders, elbows, hands, head) by hand for 41 frames across all 12 animations, and draws every layer from those joints with 5-step hue-shifted ramps lit from the top-left plus a dark outline per layer:
- body for each chassis (boy: broader, antenna nub; girl: narrower waist, rounded crest, a cable braid with a glowing bead that swings), front arm as its own layer, face screen with eyes (red X eyes when hurt, off when dead), the blade (brass grip and guard, cyan light blade with a white core and halo) and a thrown-blade world sprite.
- every outfit piece: tattered hood with a long drooping point (from the concept sketch), three cloaks with a back drape and a front capelet (teal: neon trim; rust: bitten hem; patchwork: patches), hazard vest with reflective stripes, baggy cargo pants with a thigh pocket and cuffs, chunky boots, scrap-plate mask with eye slits, brass goggles.
- Animations: idle (breathing), run (8 frames), jump, fall, attack forward/up/down, throw, grapple, dash, hurt, dead (collapses and lies down). Dash afterimages copy the exact frame. Landing squash still works. The blade sprite disappears from the hand while the blade is out.
- The old shape drawing remains only as a fallback if the sheets are missing.

**Tests:** 136, all passing. New: blade > melee damage, shop cards/emblems/stamp/disabled Buy/can't afford/unlock, camp width, a platforming bot climbs the whole tower with plain running jumps, the lookout hook reaches and lands in the hidden alcove, noticeboard reads, hatch breaks in 3 hits, falling through reaches the Hollow, the Hollow's platforms climb to the goggles and you pick them up, the hatch stays broken, the robot renders with real sprite layers, the blade leaves the hand sprite when thrown.

**Not verified by hand:** animation timing and readability in motion (checked as sheets and in still renders only), and whether the 40 px tower steps feel too easy or just right.

## Any-screen scaling, feel pass, socket loadout (previous increment)
**Scaling.** Stretch aspect is now `expand` (was the default `keep`, which letterboxed anything not 16:9). The camera always shows 360 px of world vertically (`Player.WORLD_HEIGHT`), so: ultrawide shows more of the room sideways; 4:3 / 16:10 zoom in slightly instead of showing empty sky; a room narrower than the screen (the 640 px Intake on ultrawide) is zoomed until it fills the screen. The zoom updates when the window is resized. F11 / Settings toggles fullscreen (saved). The title backdrop tiles sideways and fills below the skyline. Checked in rendered screenshots at 21:9 (1680x720), 16:9, and 4:3 (960x720): no bars and nothing visible past room walls.

**Feel (Hollow Knight / Terraria references).** The clunk came from specific things, each fixed:
- Ground movement took ~0.1 s to start and stop and slid on turns: ground accel 1300 -> 3200, friction 1600 -> 4200, turnarounds add friction, air control 900 -> 2400 (HK-style full air steering).
- Swings and throws locked you in place: the attack state applied friction and allowed no jump or dash. Now you keep full movement while swinging (`free_move`), can jump mid-swing, and can dash, throw or recall once the hit frames end (0.14 s). Throws never stop movement.
- Inputs pressed a moment early were lost: attack and dash presses are buffered for 0.12 s.
- Terraria autoswing: hold attack to keep swinging every 0.3 s; consecutive swings sweep alternate ways.
- Jump: release cuts to 25% of upward speed (was 45%) for crisp short hops; a little hang time near the apex while jump is held.
- Corner correction: rising into a ledge corner by up to 5 px slides you past it; moving into a lip up to 6 px above your feet while airborne pops you onto it.
- Camera: one smoothing layer instead of two, a small facing lead that eases in (turning no longer whips the view 56 px), and a vertical dead zone so normal jumps don't bob the screen.
- Terraria-style floating damage numbers on enemy hits (gold and larger for 2+); toggle in Settings.
- Throw: a click (or any press that isn't a real flick) now throws at normal power toward the cursor instead of a weak toss, so no press is a dud. Flicks still add direction, speed and the charge.

**Socket loadout.** Port Loadout is now a 4x2 grid of round brass sockets above a tray of round chips, each with its own emblem (spiral wire, horseshoe magnet, saw, hourglass shield, riveted plate with a cell, valve with steam). Selecting a tray chip flies it to the next free socket, where it squashes in, flashes and lights the socket contacts; selecting a seated chip (in a socket or the tray) pops it back out. Two-port chips fill two sockets joined by a lit conduit. The overclock socket is red, unlocked-later sockets are bolted caps, and chips that won't fit shake. The right panel shows a large emblem, name, port cost, description and live stats. Works with mouse (hover selects) and keyboard/pad focus.

**Tests:** 117 total, all passing. 16 new: expand aspect, run speed in 0.1 s, near-instant stop, jump mid-swing, autoswing, dash into Rush slash, corner correction off the first girder, camera fit zoom (small and large rooms), loadout sockets/emblem/conduit/overclock, eject from tray, eject from socket, insert into the next free socket.

**Not verified by hand:** whether the new movement numbers feel right on a real keyboard/mouse, and the insert animation timing in motion. Those need a human playtest.

## Combat flow: flick throw + tether moves (previous increment)
Design goal: one loop that keeps the robot moving: **flick -> pin -> zip -> bounce -> flick**, with every step using a button the player already knows.
- **Flick to throw (mouse):** hold left click, flick, let go. The direction comes from the last 0.09 s of mouse motion; the speed sets throw power (blade speed 0.75x to 1.2x; weak tosses only use 60% of the wire). A flick at or above the hard threshold throws a **charged** blade: gold trail, double damage, pierces. A slow drag throws a weak toss along the drag; no movement tosses softly at the cursor. Throws aimed at a hook always get the full wire.
- **Gamepad:** hold RB and release; holding 0.35 s or more charges the throw.
- **Pin:** a normal throw sticks in the first enemy it hits (follows it, pulses, 0.9 s). Left click rips it out for one more hit.
- **Zip:** dash while the blade is pinned: the robot rides the wire (560 px/s, invulnerable), strikes for melee+1, catches the blade and bounces up with the air dash back. Zip only targets enemies, not walls, so it can't skip ability-gated climbs (wall zips are a candidate for a later shard).
- **Catch hop:** catching a blade that hit something while airborne restores the air dash and gives a small lift. A blade that hit nothing gives nothing, so throw-catch spam can't be used to hover.
- **Rush slash:** a right-click swing while the robot's recent speed is 230+ px/s (dash, zip, grapple, long fall) does +1 damage with a bigger arc. Attacking mid-dash cancels into a Rush slash. A slower afterimage trail shows when a Rush is ready.
- **Aim-assist** bends throws up to ~17 degrees onto enemies in reach and in sight (hooks still win, at ~28 degrees). The aim guide brightens and follows the flick while gripping; red brackets mark the enemy a throw will bend to.
- **Settings:** "Mouse throw: Flick / Click" (accessibility fallback to the old click-to-throw) and "Flick sensitivity: Low / Normal / High", saved in settings.cfg.
- **Tests:** 19 new checks (101 total, all passing): the flick reader (hard, medium, drag, no-move, sensitivity), pin, rip, zip strike and bounce, catch hop, Rush slash, charged pierce through two drones, enemy aim-assist, gamepad hold-to-charge. Effects were checked in rendered screenshots: grip guide, charged trail, pin pulse, zip afterimages.
- **Not verified:** how the flick *feels* with a real mouse. The thresholds (220 and 1300 px/s in the 640x360 view) are first guesses and need hand-tuning; the sensitivity setting exists for exactly that. Headless tests feed synthetic mouse samples, not a real mouse.

## Controls and reachability fixes (previous increment)
- Melee attack moved from J to **right mouse click**, swinging toward the cursor (above = upward slash, below you in the air = pogo, beside = forward and the robot turns). Gamepad X unchanged.
- Blade throw / recall / reel-in moved from K to **left mouse click**, aimed freely at the cursor (gamepad RB still aims with the stick). Pixel crosshair cursor; a faint dotted aim line that stops at the wire's real reach; amber brackets on the hook a throw will snap to. The robot turns toward a throw, not toward every mouse movement.
- Bug: the Pit's first girder was 64 px up but the jump is 58 px. The opening climb was rebuilt (every step 48 px or less) and the tutorial hook moved so the reel-in lands you on the vest ledge. The Intake's side platforms (84 px) were also unreachable and were lowered.
- New tests actually perform those jumps and the tutorial grapple, so unreachable geometry fails the test run.

## Town families (previous increment)
- Residents now share a family look per town via `Lineage` + `NPCLook` (see STYLE.md): common silhouette, palette and amber-lens signature; individual height, build, hunch, patches, headwear, goggles, scarf and tools. Residents turn to face the robot and breathe; their lenses cast a faint light.
- Tinker, Rusty and Pip got their family look. Two new camp residents: Gran Oxa (the family elder by the fire, foreshadows the brass giant) and Sprocket (teen lookout who times the Intake's dumps).
- Tested: looks are deterministic, two residents are never identical, every resident carries the family lens.
- Other characters (the robot, enemies, boss) are still placeholder shapes.

## Art direction change (previous increment)
Feedback: it looked "too AI". Diagnosis: default neon-night cyberpunk palette, visibly procedural backdrops, floating slab platforms, stacked filters. Changes:
- Painterly HD pixel at dusk: warm smog sun, slate-teal sky, rust and oxidised green; cyan reserved for the robot and its tech.
- Hand-composed backdrops with landmarks (dark Spire needle, trash conveyors, toppled crane, buried brass giant) and aerial perspective.
- New terrain: lumpy sunlit junk ground with scattered debris instead of a tile grid; girder and shipping-container platforms; open sky in outdoor rooms; hooks hang from a visible cable.
- Effects trimmed: no lens fringe or rain, bloom only on light sources, backdrops ignore world lights, warmer and brighter ambient.

## Effects pass (previous increment)
Modern presentation over the pixel art (details in STYLE.md): dynamic 2D lighting with per-room ambient, bloom/grade/vignette post-processing, rain and drifting motes, embers/smoke/sparks, slash arcs, hit sparks, blade trail and light, glowing tether, dash afterimages, shockwave rings, look-ahead camera, smooth motion, animated menus/dialogue/toasts, lagging boss bar, flashing health cells, and Settings toggles for post effects and flashing.
Checked in rendered screenshots (including slow-motion captures of slash, throw and dash). The first lighting pass was too dark and the bloom blew out bright surfaces; both were rebalanced after review.

## Placeholder or partial (do NOT treat as finished)
- **Audio exists but has never been listened to by a person.** It's synthesized placeholder sound; expect to replace or retune it.
- Nothing in milestone 1 has been hand-played. Boss, mini-boss and arena balance come from design numbers only.
- NPCs use generated family looks. Enemies and bosses are generated sprites with simple code animation (no frame-by-frame animation).
- The HUD numbers and the boss bar are still plain. HUD text overlaps the playfield in places.
- Level geometry is rectangles drawn by code, not TileMapLayers.
- The tram is only a teaser: fast travel doesn't exist yet.

## Missing
- Control remapping.
- A designed opening cutscene.
- Shards III to V.
- Regions 3 to 5 (the Fallen Forge onward).
- Fast travel (the trams are scenery).

## Known issues
- Exiting the tests prints harmless "RIDs leaked" / "resources still in use" warnings on teardown.

## Next priorities
1. **Hand-play the demo start to finish.** Tune the flick thresholds, movement numbers, boss and mini-boss timings, and the audio mix.
2. Fix whatever that playtest turns up before adding regions.
3. More buildings to walk into (Tinker's shack, Gran Oxa's home), and front/back views for the NPCs indoors.
4. Hand-play the Underworks: swing feel (pump strength, release boost), the Governor's flyball speed, the Lamplighter's sweep timing.
5. The Heap's Swing secrets, then region 3, the Fallen Forge (Shard III, Ricochet).

## Robot v2: Dead Cells-style redesign (2026-11-14)
- New design from Jai's drawing: pointy-cap hood (tip curls up), round screen face with two oval eyes, navy poncho/hoodie with a strap, baggy cargo pants with straps and a thigh pocket, chunky striped boots, two short light daggers with small grips, each on a neon wire to a reel on the hip.
- `tools/art/build_character.py` v2 draws 96x96 frames (2x detail, aimed at a 1280x720 screen) with normal-based cel shading from an upper-right light; `PlayerVisuals` shows them at half scale, so the robot keeps its world size and hitboxes. Old generator kept in `tools/art/legacy/build_character_v1.py` (the top-down indoor sprites still use it).
- New layer `blade_back` (off-hand dagger behind the body). New starting cosmetics `hood_navy` and `cloak_navy`; every other cloak/hood still restyles the design.
- Next for the art direction: redraw backgrounds, tiles, props and enemies at the same 2x pixel density, then switch the base resolution to 1280x720.
- All suites pass (smoke 190, heap 42, underworks 93, demo 25). Not hand-played yet.

## Robot v3, motion, backgrounds, controls, boss throw, death (2026-11-14, afternoon)
- Robot is a metal frame in thin cloth: armoured chest with core light, open segmented spine and waist, ball joints, armour on forearms and shins, neutral-grey steel so metal reads apart from the navy cloth. No shirt: a small shoulder piece, open at the front; a long cape from the back of the shoulders to the knee that streams, lifts and shows its lining; thin trousers that crease at the knee. Thinner neck scarf. 67 frames per layer (idle 8, run 12, attack 6, death 7 ...); `PlayerVisuals` adds a lean into speed and a jump stretch.
- Heap outdoor backdrop replaced by the dithered v2 (`tools/art/build_backdrops_v2.py --install`; v1 kept in `art/backdrops/legacy_v1/`, ignored by Godot). `Backdrop` draws live effects between layers: breathing sun glow, two drifting smog bands, flickering city windows, passing birds, embers; falling grit in the cave, hanging dust in the Intake.
- Controls: three schemes (Standard WASD + mouse, Arrows + Z X C, WASD + J K L) and per-action rebinding (Settings > Controls / Rebind keys), saved in settings.cfg; gamepad always works. `Keybinds` (scripts/components/keybinds.gd). Title screen and opening tip show the chosen keys.
- INTAKE UNIT 7 THROW attack: grabs a block, red aim line tracks then locks, hurls it straight at the robot; it shatters into skidding fragments (second dodge). Phase 2 throws twice, the second leading.
- Death: the world slows, the camera leans in, the core light gutters out in sparks (2.6 s). Respawn: squash, hop, springy settle. Respawns are unlimited.
- New suite `tools/features_test.tscn -- demo` (16 checks). All suites pass: smoke 190, heap 42, underworks 93, demo 25, features 16. Not hand-played yet.

## Haven theme: "Bouncing back" (2026-11-14)
- Demo rebuilt around it. Intro: discarded on the Heap, "DIRECTIVE RECOVERED: GET BACK UP". Title tag "SHOWCASE DEMO - BOUNCING BACK".
- `BouncePad` (scripts/world/bounce_pad.gd): tyre + bed spring, launches at 470 (a jump is ~340, so ~110 px high). DemoMode places up to 3 per route room under ledges 62-105 px above a floor, only on floors in air reachable from the room's spawns (flood fill over 8 px cells). 12 pads across the 5 rooms before the Intake.
- Rebound Strike: getting hit opens a 2.2 s window, respawning an 8 s one; the next attack does double damage ("REBOUND!"), the core light brightens while charged.
- INTAKE UNIT 7's thrown block can be hit back: it homes into the crane for 3 damage through the armour and knocks it STUCK. First throw shows the hint.
- End card: "BOUNCING BACK", knocked down N times / got back up N times, Rebound Strikes landed.
- features_test now 28 checks. All suites pass. Not hand-played yet.

## Demo boss: Governor -> crane showdown (2026-11-14)
- `IntakeShowdown` (scripts/enemies/intake_showdown.gd), demo only (in the full game it steps aside and the plain crane fight runs). THE PENDULUM (intake mode: 12 HP, hits count from the ledges) fights in the Intake with four `CrumblePlatform` ledges and two bounce pads; at 75/50/25% a flyball smashes a ledge, at 25% it's off balance (wobbles, crown hittable from anywhere), at 0 it topples and crashes.
- Cutscene: the bar drops, the shard glows in the wreck, then INTAKE UNIT 7 drops off its rail, slams the wreck to bits, hauls it off the side, picks up the shard and absorbs it. Then the empowered crane fight (cyan trim, shard in the core, faster tracking, shorter stun).
- Music: `AudioManager.set_music_pitch()`; the score sags at the fake win, winds up to 1.08 when the Governor is off balance, 1.12 for the empowered crane, 1.2 in its phase 2, back to 1.0 when it's over.
- Demo idle reset no longer counts time while controls are locked (cutscenes).
- All suites pass: smoke 190, heap 42, underworks 93, demo 32, features 25+.

## Music, lasers, Link proportions (2026-11-14, evening)
- Music (Jai's tracks, audio/music): beginning_underground (cave/hollow rooms of the Heap), beginning_aboveground (camp, fields, crane yard, conveyor, Intake and the other industrial Heap rooms), boss_og (THE PENDULUM), boss_final (INTAKE UNIT 7). Cut to their loop: the opening tracks to exactly 24.0 s (8 bars at 80 bpm), bossog to 17.479 s, Boss_fight from 0.12 s; 6 ms / 20 ms edge fades, loudness levelled (Boss_fight +17 dB, limited). Boss tracks via AudioManager.BOSS_TRACKS (by boss name). Showdown: bossog sags through the fake win (keep_music_on_boss_end), silence when the crane drops in, boss_final when it absorbs the shard.
- Crane pink phase: LASER attack. Steam rises over the bottom half (STEAM_TOP 150), three aim lines visible only inside the steam, track then lock, three beams fire 112 px apart.
- Robot: Link's proportions (about 6.5 heads: HEAD_R 3.0, LEG 18.6, ARM 14), slimmer hood shell; full mantle over both shoulders to mid-chest and a long, brighter cape to the calves.
- Demo: no bounce pads in the opening cave; the side nook off the cave's climb is walled up in the demo only (DemoMode.DEMO_WALLS; the full game keeps it, a cosmetic is in it).
- All suites pass: smoke 190, heap 42, underworks 93, demo 39, features 29.
