# Unhilted

Made with **Godot 4.4+**

This game has **two regions**: the Heap (13 rooms, Shard I) and **the Underworks** (15 rooms, Shard II: Swing). The Forge Gate at the end of Line 4 is sealed: region 3 isn't built.

## Initial Running
Run with **godot --path . --resolution 1280x720 -- demo**

## Controls
| Action | Keyboard | Gamepad |
|---|---|---|
| Move / aim (8-way) | WASD or arrows | Left stick / D-pad |
| Jump (hold = higher) | Space | A |
| Attack (swings toward the cursor; aim below you in the air = pogo) | Right click | X (hold stick up/down to aim) |
| Throw blade: hold, flick, let go (flick speed = power; a hard flick charges it) | Hold Left click + flick | Hold RB, release (hold longer = charged) |
| Recall blade / reel in on a hook | Left click while the blade is out | RB |
| Dash (with the blade stuck in an enemy = Zip to it; with Shard II, in a wall = wall zip) | L or Shift | B |
| Slide (or down while running) | Ctrl or C | LT |
| Swing (Shard II): with the blade on a hook or ring, press throw again; lean to pump, up/down to climb, jump to let go | Left click | RB |
| Talk / read / enter a door / charge at dock | E | Y |
| Walk indoors (8 directions) | WASD or arrows | Left stick |
| Repair kit | Q | LB |
| Pause / journal (map, lore, settings) | Esc | Start |
| Map | Tab or M | |
| Fullscreen | F11 | |

Hold attack to keep swinging. You can run, jump and dash out of swings and throws.



## What's in this build
- **Chassis select** (girl/boy) as a boot sequence; changes the body and dialogue pronouns (`{they}` `{them}` `{their}`)
- **Player:** state machine (idle, run, jump, fall, attack, throw, grapple, dash, hurt, dead), coyote time, jump buffer, variable jump height, pogo
- **Tethered blade:** flick-to-throw with the mouse (or hold-release on a gamepad), auto-recall at max wire length, hits on the way out *and* back, grapples hooks (with aim-assist)
- **Any screen shape:** stretch aspect "expand" plus a camera that always shows 360 px of world vertically, so ultrawide sees more sideways, 4:3 and 16:10 zoom slightly, and rooms narrower than the screen are zoomed to fill it. No black bars.
- **Character sprites:** rig-posed layered pixel art for both chassis, every outfit piece and the blade (`tools/art/build_character.py`); rebuild after adding a cosmetic and it gets sprites and a shop icon automatically
- **UI:** one look everywhere, the shop's: riveted iron frames with brass corners, iron-plate buttons, brass nameplate headings, wooden display cases (`tools/art/build_ui.py`)
- **Shop:** stall with awning, riveted item cards with price tags and stamps, a display case and a brass Buy plate
- **Walk-in buildings (top-down, like Undertale):** Rusty's shop, Dot's map room and Mags' garage in the camp. [E] at a door to go in; inside, walk in 8 directions with front/back/side sprites, [E] to look at things and talk; walk down over the doormat to leave (`scripts/interior/`, rooms from `tools/level/build_interiors.py`, sprites from `tools/art/build_overworld.py`)
- **Heap rooms (13):** Under the Heap (tunnels you work through), Scavenger Camp, the Hollow (secret), Scrap Fields, Crane Yard, Conveyor Hall, the Intake (boss), Compactor Pit (wave arena), Giant's Brow (mini-boss), Sinkhole, Seep Tunnels, Old Tram Stop (secret), Underworks Gate (stairs down). Plan: `docs/HEAP_LAYOUT.md`
- **The Underworks (15 rooms):** a gaslit steampunk city in the old maintenance tunnels. Pipe Market (town of the Bellows Kin, three walk-in buildings), Bellows Row, Boiler Works, Gearworks, Lamplighter's Gallery (mini-boss), Condensate Falls, the Cistern, Pressure Gauge Hall, Steam Trials (arena), Pendulum's Approach, the Pendulum (boss, Shard II), Swing Galleries, Clockmaker's Loft (secret), Old Tram Tunnel. Plan: `docs/UNDERWORKS_LAYOUT.md`
  - Gimmicks: steam vents (lift you, or scald on a rhythm), valves you hit to switch vents and turrets, gear-wheel platforms, piston lifts, gas lamps, boiling water, brass swing rings
  - Enemies: Piston Walker (stomp shockwaves), Valve Turret (steam jet; any hit stalls it), Bellows Bat (swoops), Clockwork Spider (leaps), Boiler Bloat (swells and bursts, even when killed)
  - Quests: Pressure Drop (three relief valves), The Last Lamplighter, Letters Home (three letters). Currency: Brass Cogs (30)
- **Movement (Ultrakill-style flow):** momentum carries over max speed in the air, slide (and slide-jump), wall slide and up to 3 wall jumps, dash-jumps, grapple flings, and the Shard II swing. Hitting enemies up close charges healing (3 close hits = 1 cell)
- **Heap enemies:** Scrap Drone, Spotter Drone, Rustcrawler (drops from ceilings), Compactor (armoured front, hit it from behind or while stunned)
- **Bosses:** INTAKE UNIT 7 (Shard I), Brass Head mini-boss (port expansion), the Lamplighter mini-boss (core cell), the Pendulum (Shard II)
- **Hazards:** sludge and spikes (lose a cell, back to last safe ground), conveyor belts, timed crushers
- **Map and journal:** an ink-on-parchment map drawn from each room's real geometry; rooms reveal as you visit; Dot sells the full Heap map; lore entries collect in the journal
- **Audio:** synthesized SFX and music (`tools/audio/build_audio.py`), Music/SFX volume in Settings
- **Port Loadout:** a grid of round port sockets and a tray of emblem chips you press in and pop out (art from `tools/art/build_chips.py`)
- **Wire combat ("tether flow"):** the blade pins into the enemy it hits; click to rip it out (one more hit) or dash to **Zip** along the wire, strike and bounce off. Catching a blade that hit something in mid-air restores the air dash with a small hop. Swinging while moving fast is a **Rush slash** (+1 damage). Charged throws do double damage and pierce. Settings: Flick / Click throw mode, flick sensitivity
- **Paper-doll outfits:** hood, mask, cloak, shirt, pants, shoes, each with its own sprite layer
- **Ports:** 3 to start (max 8), chips cost 1–3, swap only at docks, overclock 1 over = double damage
- **Currencies:** Scrap (universal, dropped on death, recover it where you died) + a local coin per region: Bottlecaps (Heap, 23) and Brass Cogs (Underworks, 30)
- **Side quest** (Tinker's power cell), **shop** (Rusty), **charging dock** (heal, respawn point, save, loadout, wardrobe)
- **Shard I gates:** orange scrap walls, the Hollow floor shaft, and the brass door to the Underworks Gate
- **Boss: INTAKE UNIT 7.** Armoured while raised; hit its core in the window after a slam. Beat it for **Shard I**, then head back to the Hollow's brass door
- Settings: screen shake, hit-stop, damage numbers, post effects, volumes, throw mode
- Save/load to JSON (`user://save_slot_1.json`)



<<<<<<< HEAD
## Automated tests
- `godot --headless --path . res://tools/smoke_test.tscn` (190 checks). Covers:
  - movement, blade, grapple, the enemies
  - the boss fight to Shard I
  - quest, shop, ports, wardrobe, settings
  - death and respawn, save and load
  - map data
- `godot --headless --path . res://tools/heap_test.tscn` (42 checks). A bot plays through the new rooms:
  - every exit, spawn and building door is valid
  - the starting tunnels, start to finish
  - every climb, hook chain and sludge pit is clearable
  - the arena waves
  - the brass door, the stairs down to the Underworks, and the Seep shaft
  - the mini-boss
- `godot --headless --path . res://tools/demo_test.tscn -- demo` (25 checks): the showcase demo route, start to end card.
- `godot --headless --path . res://tools/underworks_test.tscn` (93 checks). A bot plays the Underworks:
  - every exit, door and spawn
  - the critical path: vent lifts, pistons, gear wheels, the Falls, the Gauge Hall, the boiling pit
  - every enemy (Steam Trials waves), the Lamplighter, the Pendulum, Shard II
  - swinging across the Swing Galleries, wire climbing, the secret Loft, the market's swing ring
  - the three quests, Gilda's shop, Quill's map
  - run one section with `-- only=galleries` (also `gate`, `row`, `gear`, `gauge`, `enemies`, `lamp`, `side`; add `dbg` for traces)
=======
>>>>>>> 178740712a0bfd9359dfeef2b0c5461ab36441ad

