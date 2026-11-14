"""Generates the Underworks (region 2) rooms as Godot scenes.
Run from the project root:  python3 tools/level/build_underworks.py

Same RoomBuilder and the same movement rules as the Heap (build_heap_rooms.py,
docs/HEAP_LAYOUT.md): 40 px steps, running jumps up to ~130 px, slide/dash
jumps to ~170 px, hooks placed so the reel-in path clears the ledge.
New pieces here: steam vents (lift / scald), valves, gear wheels, pistons,
gaslamps, swing anchors (Shard II), and the Underworks enemies.

Critical path: 01 Descent -> 02 Pipe Market -> 03 Bellows Row -> 04 Boiler
Works -> 05 Gearworks -> 07 Condensate Falls -> 08 Pressure Gauge Hall ->
09 Governor's Approach -> 10 The Pendulum (Shard II) -> 11 Swing
Galleries -> back up to the Pipe Market's high walkway.
Side rooms: 06 Lamplighter's Gallery (mini-boss), 12 Old Tram Tunnel (the
sealed Forge Gate), 13 Cistern, 14 Clockmaker's Loft (secret, Swing),
15 Steam Trials (arena).
Re-running overwrites these scenes.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from build_heap_rooms import RoomBuilder, ROOT, V, R, C, SN, S, SA, RA  # noqa: E402

OUT = os.path.join(ROOT, "scenes", "rooms", "underworks")
KIN = "res://data/lineages/bellows_kin.tres"

UW = dict(backdrop="uw_vault", tileset="heap_industrial", grade="underworks", music="underworks",
          ambient=(0.62, 0.6, 0.56), motes=(0.95, 0.93, 0.88, 0.22), motes_amount=26,
          region="underworks", out_dir=OUT, bg=("121a18", "2a2420"))
WORKS = dict(UW, backdrop="uw_works", ambient=(0.68, 0.6, 0.54))
DARK = dict(UW, ambient=(0.4, 0.4, 0.42))


class UWBuilder(RoomBuilder):
    """RoomBuilder plus the Underworks pieces."""

    def __init__(self, room_id, name, bounds, **kw):
        opts = dict(UW)
        opts.update(kw)
        super().__init__(room_id, name, bounds, **opts)
        self.coins = 0

    # --- shell: walls, ceiling and floor with openings for exits
    def cog(self, name, x, y):
        self.coins += 1
        self.node(name, scene="res://scenes/world/collectible.tscn", pos=(x, y), props={"kind": "1"})

    def letter(self, name, x, y):
        self.node(name, scene="res://scenes/world/collectible.tscn", pos=(x, y),
                  props={"kind": "2", "item_id": SN("letter"), "display_name": S("a lost letter")})

    # --- gimmicks
    def vent(self, name, x, y, reach=120, kind="lift", period=0.0, on_time=1.2, offset=0.0, width=24, valve=None, inverted=False):
        props = {"reach": "%g" % reach, "kind": S(kind), "width": "%g" % width}
        if period:
            props.update({"period": "%g" % period, "on_time": "%g" % on_time, "offset": "%g" % offset})
        if valve:
            props["valve_path"] = 'NodePath("../%s")' % valve
            if inverted:
                props["inverted"] = "true"
        self.node(name, "Node2D", "res://scripts/world/steam_vent.gd", pos=(x, y), props=props)

    def valve(self, name, x, y, quest=False, open_=False):
        props = {}
        if quest:
            props["quest_item"] = SN("relief_valve")
        if open_:
            props["is_open"] = "true"
        self.node(name, "Node2D", "res://scripts/world/valve.gd", pos=(x, y), props=props)

    def gear(self, name, x, y, radius=72, platforms=4, speed=0.5, width=36, start=0.0):
        self.node(name, "Node2D", "res://scripts/world/gear_wheel.gd", pos=(x, y),
                  props={"radius": "%g" % radius, "platforms": str(platforms), "speed": "%g" % speed,
                         "platform_width": "%g" % width, "start_angle": "%g" % start})

    def piston(self, name, x, y, travel, period=3.0, offset=0.0, direction=(0, -1), size=(40, 16)):
        self.node(name, "Node2D", "res://scripts/world/piston.gd", pos=(x, y),
                  props={"direction": V(*direction), "travel": "%g" % travel, "period": "%g" % period,
                         "offset": "%g" % offset, "size": V(*size)})

    def lamp(self, name, x, y, wall=False, radius=90, energy=0.9):
        props = {"radius": "%g" % radius, "energy": "%g" % energy}
        if wall:
            props["wall_mounted"] = "true"
        self.node(name, "Node2D", "res://scripts/world/gas_lamp.gd", pos=(x, y), props=props)

    def anchor(self, name, x, y, chain=40):
        self.node(name, scene="res://scenes/world/grapple_point.tscn", pos=(x, y),
                  props={"chain_length": "%g" % chain, "swing_only": "true"})

    def boiling(self, name, x, y, w, h=16):
        self.hazard(name, x, y, w, h, "boiling")

    # --- enemies
    def enemy(self, name, cls, x, y, **props):
        self.node(name, "CharacterBody2D", "res://scripts/enemies/%s.gd" % cls, pos=(x, y),
                  props={k: str(v) for k, v in props.items()})

    def turret(self, name, x, y, face=1, valve=None, offset=0.0):
        props = {"face": str(face), "offset": "%g" % offset}
        if valve:
            props["valve_path"] = 'NodePath("../%s")' % valve
        self.node(name, "CharacterBody2D", "res://scripts/enemies/valve_turret.gd", pos=(x, y), props=props)

    # --- town
    def npc(self, name, x, y, npc_id, display, lines, quest=None, age="adult", headwear="", goggles="", accessory="", seed=0):
        props = {"npc_id": SN(npc_id), "display_name": S(display), "idle_lines": SA(lines),
                 "lineage": self.res(KIN, "Resource"), "age": S(age)}
        if quest:
            props["quest"] = self.res("res://data/quests/%s.tres" % quest, "Resource")
        if headwear:
            props["pin_headwear"] = S(headwear)
        if goggles:
            props["pin_goggles"] = S(goggles)
        if accessory:
            props["pin_accessory"] = S(accessory)
        if seed:
            props["look_seed"] = str(seed)
        self.node(name, scene="res://scenes/world/npc.tscn", pos=(x, y), props=props)

    def door(self, name, x, y, interior, spawn, prompt):
        self.node(name, "Area2D", "res://scripts/world/door.gd", pos=(x, y),
                  props={"interior": S("res://scenes/interiors/%s.tscn" % interior), "return_spawn": SN(spawn), "prompt": S(prompt)})
        self.spawn(spawn, x, y)

    def dock(self, x, y):
        self.node("ChargingDock", scene="res://scenes/world/charging_dock.tscn", pos=(x, y), props={"spawn_name": SN("dock")})
        self.spawn("dock", x, y)


def lamp_glow():
    return dict(glow_color=C(1, 0.72, 0.36, 0.45), glow_radius="18")


# ------------------------------------------------------------------ 01 The Descent
def descent():
    r = UWBuilder("uw_01_descent", "The Descent", (0, 0, 640, 480))
    r.solid(16, 0, 624, 24, "brick")
    r.solid(0, 0, 16, 96, "brick")
    r.solid(0, 160, 120, 16, "grate")            # where the Heap's stairs come out
    r.solid(0, 176, 16, 304, "brick")
    for i in range(6):                            # a long iron stair down into the vault
        r.solid(120 + 64 * i, 200 + 40 * i, 64, 12, "grate")
    r.solid(16, 440, 624, 40, "plate")
    r.solid(624, 0, 16, 376, "brick")
    r.solid(476, 170, 64, 12, "grate")            # alcove over the vent
    r.vent("LiftVent", 584, 440, reach=230)
    r.cog("CogAlcove", 508, 150)
    r.exit("ExitToGate", 4, 128, 8, 64, "heap_13_gate", "from_underworks")
    r.exit("ExitToMarket", 636, 408, 8, 64, "uw_02_market", "from_descent")
    r.spawn("from_heap", 50, 160)
    r.spawn("from_market", 530, 440)            # clear of the vent column
    r.prop("Pipes", "uw_pipes", 300, 150, background="true")
    r.prop("Flywheel", "uw_flywheel", 120, 420, background="true", frames="4", fps="3")
    r.prop("Boiler", "uw_boiler", 380, 440, background="true", frames="2", fps="2",
           glow_color=C(1, 0.55, 0.25, 0.4), glow_radius="20", glow_offset=V(0, -12))
    r.lamp("LampTop", 80, 160)
    r.lamp("LampMid", 280, 440)
    r.lamp("LampLow", 520, 440)
    r.lamp("WallLamp", 200, 120, wall=True, radius=70)
    r.readable("Sign", 60, 160, "SIGN", [
        "> A brass plate, polished by a lot of hands: PIPE MARKET, DOWN AND RIGHT.",
        "> Under it, scratched: MIND THE STEAM. IT MINDS YOU."], lore="uw_sign")
    r.enemy("Bat", "bellows_bat", 360, 120)
    return r


# ------------------------------------------------------------------ 02 Pipe Market (town)
def market():
    r = UWBuilder("uw_02_market", "Pipe Market", (0, 0, 1600, 400), ambient=(0.72, 0.66, 0.58))
    r.solid(0, 0, 1600, 24, "brick")
    r.solid(0, 0, 16, 288, "brick")
    r.solid(0, 352, 1300, 48, "plate")
    r.solid(1380, 352, 220, 48, "plate")         # the stairwell down to Line 4
    r.solid(1584, 0, 16, 168, "brick")
    r.solid(1440, 232, 160, 12, "grate")         # the high walkway (Swing Galleries)
    r.solid(1584, 244, 16, 44, "brick")
    r.exit("ExitToDescent", 4, 320, 8, 64, "uw_01_descent", "from_market")
    r.exit("ExitToRow", 1596, 320, 8, 64, "uw_03_row", "from_market")
    r.exit("ExitToTunnel", 1340, 396, 80, 8, "uw_12_tunnel", "from_market")
    r.exit("ExitToGalleries", 1596, 200, 8, 64, "uw_11_galleries", "from_market")
    r.spawn("from_descent", 50, 352)
    r.spawn("from_row", 1550, 352)
    r.spawn("from_tunnel", 1270, 352)
    r.spawn("from_galleries", 1550, 232)
    # the shopfronts, with walk-in doors
    r.prop("FrontGauge", "front_gauge", 300, 352)
    r.door("DoorGauge", 320, 352, "gauge_gear", "from_gauge", "Enter Gauge & Gear")
    r.prop("FrontKettle", "front_kettle", 700, 352)
    r.door("DoorKettle", 716, 352, "kettle", "from_kettle", "Enter The Kettle")
    r.prop("FrontDepot", "front_depot", 1100, 352)
    r.door("DoorDepot", 1131, 352, "tram_depot", "from_depot", "Enter the depot")
    r.prop("SignMarket", "uw_sign_market", 700, 120, hanging="true")
    r.prop("SignLine4", "uw_sign_line4", 1340, 250, hanging="true")
    r.prop("HouseA", "uw_house_a", 140, 352, background="true")
    r.prop("HouseB", "uw_house_b", 880, 352, background="true")
    r.prop("StallA", "uw_stall", 470, 352)
    r.prop("StallB", "uw_stall", 960, 352)
    r.prop("Flywheel", "uw_flywheel", 1240, 230, background="true", frames="4", fps="2")
    r.prop("GaugeBig", "uw_gauge", 560, 230, background="true", frames="2", fps="1")
    r.dock(560, 352)
    for i, x in enumerate((40, 420, 640, 840, 1040, 1260, 1480)):
        r.lamp("Lamp%d" % i, x, 352, radius=110, energy=1.0)
    r.npc("Brask", 900, 352, "brask", "Foreman Brask", [
        "Gauges are all in the red. Have been for a week."], quest="pressure_drop", headwear="stovepipe", goggles="raised", accessory="apron")
    r.npc("Pell", 790, 352, "pell", "Pell", [
        "Are you a tram? You're a bit small for a tram.",
        "My gran says The Pendulum used to sing. Now it just screams.",
        "If you go to the Galleries, swing on the big rings! I'm not allowed. I'm too swingy, gran says."],
        age="child", headwear="none", goggles="double", accessory="none")
    r.npc("Corra", 1220, 352, "corra", "Old Corra", [
        "Sit, sit. Mind the steam.",
        "The smiths built The Pendulum to keep the city above warm. Then the city above forgot we were down here.",
        "That brass blade of yours. Seven hammers on the pommel? ...No. I'm imagining things. Old eyes."],
        age="elder", headwear="bowler", goggles="monocle", accessory="cane")
    r.npc("Fenwick", 470, 352, "fenwick", "Fenwick", [
        "Cogs! Spare cogs! Some are even round!",
        "Gilda sells the good stuff, I sell the stuff Gilda threw out. Very different."],
        headwear="bowler", goggles="monocle", accessory="brass_arm", seed=7)
    r.anchor("SwingRing", 1370, 170)               # with Swing: up to the walkway
    r.cog("CogStall", 470, 280)
    r.cog("CogWalk", 1520, 212)
    r.readable("Notice", 1180, 352, "NOTICE", [
        "> NOTICE: LINE 4 SUSPENDED UNTIL FURTHER NOTICE.",
        "> Further notice, in a different hand: STILL SUSPENDED.",
        "> In a third, very old hand: ask again in a hundred years."], lore="uw_notice")
    return r


# ------------------------------------------------------------------ 03 Bellows Row
def row():
    r = UWBuilder("uw_03_row", "Bellows Row", (0, 0, 1280, 400))
    r.solid(0, 0, 1280, 24, "brick")
    r.solid(0, 0, 16, 288, "brick")
    r.solid(1264, 0, 16, 288, "brick")
    r.solid(0, 352, 1280, 48, "brick")
    r.solid(340, 312, 40, 40, "plate")           # a crate step up to the roofs
    r.solid(420, 270, 80, 10, "grate")
    r.solid(560, 230, 100, 10, "grate")
    r.solid(720, 270, 80, 10, "grate")
    r.solid(840, 312, 40, 40, "plate")
    r.exit("ExitToMarket", 4, 320, 8, 64, "uw_02_market", "from_row")
    r.exit("ExitToWorks", 1276, 320, 8, 64, "uw_04_works", "from_row")
    r.spawn("from_market", 50, 352)
    r.spawn("from_works", 1230, 352)
    # scalding vents along the street: time the gaps, or take the roofs
    for i, x in enumerate((530, 690, 920)):      # between the roofs, never under them
        r.vent("ScaldVent%d" % i, x, 352, reach=110, kind="scald", period=2.4, on_time=1.0, offset=i * 0.8)
    r.valve("ReliefValve", 630, 230, quest=True)
    for i, (x, tex) in enumerate(((180, "uw_house_a"), (300, "uw_house_b"), (980, "uw_house_a"), (1120, "uw_house_b"))):
        r.prop("House%d" % i, tex, x, 352, background="true")
    r.prop("Sign", "uw_sign_row", 160, 140, hanging="true")
    r.prop("Pipes", "uw_pipes", 640, 140, background="true")
    for i, x in enumerate((90, 520, 900, 1200)):
        r.lamp("Lamp%d" % i, x, 352)
    r.enemy("SpiderA", "clock_spider", 960, 352)
    r.enemy("SpiderB", "clock_spider", 1100, 352)
    r.enemy("Bat", "bellows_bat", 700, 140)
    r.cog("CogRoof", 760, 250)
    return r


# ------------------------------------------------------------------ 04 Boiler Works
def works():
    r = UWBuilder("uw_04_works", "Boiler Works", (0, 0, 960, 480), **WORKS)
    r.solid(0, 0, 960, 24, "brick")
    r.solid(0, 0, 16, 376, "brick")
    r.solid(0, 440, 960, 40, "plate")
    r.solid(944, 0, 16, 136, "brick")
    r.solid(944, 212, 16, 228, "brick")
    r.solid(480, 280, 200, 12, "grate")          # the catwalk the first piston lifts you to
    r.solid(760, 200, 184, 12, "grate")          # the high exit ledge
    r.exit("ExitToRow", 4, 408, 8, 64, "uw_03_row", "from_works")
    r.exit("ExitToGearworks", 956, 168, 8, 64, "uw_05_gearworks", "from_works")
    r.spawn("from_row", 50, 440)
    r.spawn("from_gearworks", 900, 200)
    r.piston("LiftA", 420, 440, 120, period=3.0)
    r.piston("LiftB", 650, 280, 100, period=3.0, offset=1.5)
    r.valve("ReliefValve", 520, 280, quest=True)
    r.valve("TurretValve", 880, 440)
    r.turret("Turret", 944, 420, face=-1, valve="TurretValve")
    r.enemy("Walker", "piston_walker", 640, 440)
    for i, x in enumerate((140, 300)):
        r.prop("Boiler%d" % i, "uw_boiler", x, 440, background="true", frames="2", fps="2",
               glow_color=C(1, 0.55, 0.25, 0.4), glow_radius="20", glow_offset=V(0, -12))
    r.prop("Gauge", "uw_gauge", 600, 200, background="true", frames="2", fps="2")
    r.prop("Pipes", "uw_pipes", 820, 150, background="true")
    r.lamp("Lamp0", 60, 440)
    r.lamp("Lamp1", 560, 280)
    r.lamp("Lamp2", 860, 200)
    r.readable("Plate", 220, 440, "MAKER'S PLATE", [
        "> BOILER 3. INSTALLED BY THE GUILD OF THE SEVEN HAMMERS.",
        "> PRESSURE SET BY The Pendulum. DO NOT ADJUST.",
        "> Somebody has adjusted it. The needle is wedged with a spoon."], lore="uw_boiler_plate")
    r.cog("CogCatwalk", 610, 250)
    return r


# ------------------------------------------------------------------ 05 Gearworks
def gearworks():
    r = UWBuilder("uw_05_gearworks", "Gearworks", (0, 0, 960, 480), **WORKS)
    r.solid(0, 0, 960, 24, "brick")
    r.solid(0, 0, 16, 136, "brick")
    r.solid(0, 200, 160, 12, "grate")            # entry ledge
    r.solid(0, 212, 16, 268, "brick")
    r.solid(16, 440, 704, 40, "plate")           # pit floor (spiked)
    r.solid(720, 300, 240, 180, "brick")         # the far landing
    r.solid(800, 120, 144, 12, "grate")          # high ledge to the Gallery
    r.solid(944, 0, 16, 56, "brick")
    r.solid(944, 132, 16, 104, "brick")
    r.hazard("Spikes", 160, 428, 560, 12, "spikes")
    r.gear("GearA", 300, 250, radius=70, speed=0.6)
    r.gear("GearB", 540, 250, radius=70, speed=-0.6, start=0.785)
    r.vent("LiftVent", 760, 300, reach=200)
    r.exit("ExitToWorks", 4, 168, 8, 64, "uw_04_works", "from_gearworks")
    r.exit("ExitToGallery", 956, 88, 8, 64, "uw_06_gallery", "from_gearworks")
    r.exit("ExitToFalls", 956, 268, 8, 64, "uw_07_falls", "from_gearworks")
    r.spawn("from_works", 60, 200)
    r.spawn("from_gallery", 900, 120)
    r.spawn("from_falls", 900, 300)
    r.dock(850, 300)
    r.cog("CogHigh", 420, 140)
    r.enemy("BatA", "bellows_bat", 300, 110)
    r.enemy("BatB", "bellows_bat", 560, 110)
    r.prop("Flywheel", "uw_flywheel", 420, 430, background="true", frames="4", fps="4")
    r.lamp("Lamp0", 60, 200)
    r.lamp("Lamp1", 880, 120)
    r.lamp("WallLamp", 700, 340, wall=True, radius=70)
    return r


# ------------------------------------------------------------------ 06 Lamplighter's Gallery (mini-boss)
def gallery():
    r = UWBuilder("uw_06_gallery", "Lamplighter's Gallery", (0, 0, 640, 360), **DARK)
    r.solid(0, 0, 640, 24, "brick")
    r.solid(0, 0, 16, 256, "brick")
    r.solid(624, 0, 16, 360, "brick")
    r.solid(0, 320, 640, 40, "plate")
    r.exit("ExitToGearworks", 4, 288, 8, 64, "uw_05_gearworks", "from_gallery")
    r.spawn("from_gearworks", 50, 320)
    for i, x in enumerate((120, 260, 400, 540)):
        r.lamp("Lamp%d" % i, x, 320, radius=100, energy=1.0)
    r.node("BossArena", "Node2D", "res://scripts/world/boss_arena.gd", props={
        "boss_flag": S("boss_lamplighter_defeated"), "boss_name": S("THE LAMPLIGHTER"), "trigger_x": "140",
        "door_rect": R(0, 256, 16, 64), "boss_path": 'NodePath("Lamplighter")', "reward": S("core_cell"),
        "reward_id": S("uw_lamplighter_cell"), "shard_position": V(330, 296),
        "victory_text": S("The Lamplighter's lantern gutters out. The Gallery's lamps catch, one by one."),
        "intro_lines": SA(["> A tall shape at the end of the Gallery reaches up with a long hook-pole.",
                           "> A lamp goes out. It turns its lantern head toward you."])})
    r.node("Lamplighter", "CharacterBody2D", "res://scripts/enemies/lamplighter.gd", pos=(500, 320), parent="BossArena")
    r.prop("Portrait", "uw_gauge", 330, 150, background="true")
    return r


# ------------------------------------------------------------------ 07 Condensate Falls
def falls():
    r = UWBuilder("uw_07_falls", "Condensate Falls", (0, 0, 640, 440))
    r.solid(0, 0, 640, 24, "brick")
    r.solid(0, 0, 16, 88, "brick")
    r.solid(0, 120, 110, 12, "grate")            # stops short of the stair, so you can jump back up onto it
    r.solid(0, 132, 16, 204, "brick")
    for i in range(5):                           # a stair of grates down past the falling water
        r.solid(140 + 80 * i, 160 + 40 * i, 80, 12, "grate")
    r.solid(540, 360, 100, 80, "plate")          # the stair lands here (nothing low to walk under)
    r.solid(624, 0, 16, 296, "brick")
    r.solid(16, 400, 144, 40, "plate")           # the Cistern side
    r.solid(160, 420, 380, 20, "plate")          # the pool's bottom
    r.boiling("Pool", 160, 404, 380, 16)
    # a staggered ladder of grates up the left wall, back to the entry ledge
    for i, (x, y) in enumerate(((16, 360), (84, 320), (16, 280), (84, 240), (16, 200), (84, 168))):
        r.solid(x, y, 56, 8, "grate")
    r.exit("ExitToGearworks", 4, 88, 8, 64, "uw_05_gearworks", "from_falls")
    r.exit("ExitToCistern", 4, 368, 8, 64, "uw_13_cistern", "from_falls")
    r.exit("ExitToGauge", 636, 328, 8, 64, "uw_08_gauge", "from_falls")
    r.spawn("from_gearworks", 50, 120)
    r.spawn("from_cistern", 50, 400)
    r.spawn("from_gauge", 590, 360)
    r.valve("ReliefValve", 604, 360, quest=True)
    for i, x in enumerate((250, 400, 520)):      # the falls themselves (steam where they hit)
        r.glow("Fall%d" % i, x, 404, C(0.85, 0.9, 0.95, 0.3), 26, 60, 0.4, "smoke")
    r.enemy("Bloat", "boiler_bloat", 330, 130)
    r.enemy("Spider", "clock_spider", 580, 360)
    r.lamp("Lamp0", 60, 120)
    r.lamp("WallLamp", 600, 260, wall=True)
    r.cog("CogLedge", 44, 340)
    return r


# ------------------------------------------------------------------ 08 Pressure Gauge Hall
def gauge():
    r = UWBuilder("uw_08_gauge", "Pressure Gauge Hall", (0, 0, 1280, 400), **WORKS)
    r.solid(0, 0, 900, 24, "brick")
    r.solid(980, 0, 300, 24, "brick")
    r.solid(0, 0, 16, 288, "brick")
    r.solid(1264, 0, 16, 288, "brick")
    r.solid(0, 352, 1280, 48, "plate")
    r.solid(400, 312, 32, 40, "brick")           # a block with a turret bolted to its face
    r.solid(520, 312, 40, 40, "plate")
    r.solid(580, 260, 160, 10, "grate")          # catwalk over the vents (a hop up from the step)
    r.solid(1100, 300, 80, 12, "grate")
    r.exit("ExitToFalls", 4, 320, 8, 64, "uw_07_falls", "from_gauge")
    r.exit("ExitToApproach", 1276, 320, 8, 64, "uw_09_approach", "from_gauge")
    r.exit("ExitToTrials", 940, 4, 80, 8, "uw_15_trials", "from_gauge")
    r.spawn("from_falls", 50, 352)
    r.spawn("from_approach", 1230, 352)
    r.spawn("from_trials", 880, 352)
    r.turret("TurretA", 400, 330, face=-1, valve="HallValve")
    r.valve("HallValve", 250, 352)
    for i, x in enumerate((600, 700)):
        r.vent("Scald%d" % i, x, 352, reach=90, kind="scald", period=2.2, on_time=0.9, offset=i * 1.1)
    r.vent("LiftVent", 940, 352, reach=220)
    r.enemy("Walker", "piston_walker", 1000, 352)
    r.letter("Letter", 1140, 290)
    for i, x in enumerate((200, 640, 1060)):
        r.prop("Gauge%d" % i, "uw_gauge", x, 150, background="true", frames="2", fps="1")
    for i, x in enumerate((60, 480, 820, 1220)):
        r.lamp("Lamp%d" % i, x, 352)
    r.cog("CogCatwalk", 650, 230)
    return r


# ------------------------------------------------------------------ 09 Governor's Approach
def approach():
    r = UWBuilder("uw_09_approach", "Governor's Approach", (0, 0, 960, 400), **WORKS)
    r.solid(0, 0, 960, 24, "brick")
    r.solid(0, 0, 16, 288, "brick")
    r.solid(944, 0, 16, 288, "brick")
    r.solid(0, 352, 400, 48, "plate")
    r.solid(490, 312, 40, 88, "brick")           # an island in the boiling pit
    r.solid(620, 352, 340, 48, "plate")
    r.solid(400, 384, 220, 16, "plate")
    r.boiling("Pit", 400, 368, 220, 16)
    r.solid(820, 200, 124, 12, "grate")          # a ledge only Swing reaches (for now)
    r.exit("ExitToGauge", 4, 320, 8, 64, "uw_08_gauge", "from_approach")
    r.exit("ExitToGovernor", 956, 320, 8, 64, "uw_10_governor", "from_approach")
    r.spawn("from_gauge", 50, 352)
    r.spawn("from_governor", 910, 352)
    r.dock(200, 352)
    r.anchor("SwingRing", 760, 140)
    r.cog("CogLedge", 900, 180)
    r.gear("Gear", 510, 150, radius=60, platforms=0, speed=0.3)  # decorative: The Pendulum's drive train
    r.readable("Warning", 300, 352, "PLAQUE", [
        "> The Pendulum. KEEPS THE PRESSURE OF THE WHOLE UNDERWORKS.",
        "> WHEN THE BALLS FLY OUT, IT IS RUNNING FAST. WHEN THE CROWN LIFTS, IT IS ABOUT TO BURST.",
        "> Scratched underneath: hooks either side of the crown. Hit it while it's open. -B."], lore="uw_governor_plaque")
    r.enemy("Bat", "bellows_bat", 510, 180)
    r.lamp("Lamp0", 120, 352)
    r.lamp("Lamp1", 700, 352)
    return r


# ------------------------------------------------------------------ 10 The Pendulum (boss)
def governor():
    r = UWBuilder("uw_10_governor", "The Pendulum", (0, 0, 640, 360), music="governor", **{k: v for k, v in WORKS.items() if k != "music"})
    r.solid(0, 0, 640, 24, "brick")
    r.solid(0, 0, 16, 256, "brick")
    r.solid(624, 0, 16, 256, "brick")
    r.solid(0, 320, 640, 40, "plate")
    r.exit("ExitToApproach", 4, 288, 8, 64, "uw_09_approach", "from_governor")
    r.exit("ExitToGalleries", 636, 288, 8, 64, "uw_11_galleries", "from_governor")
    r.spawn("from_approach", 40, 320)
    r.spawn("from_galleries", 600, 320)
    # in reach of the wire from a jump (150 px), level with the crown's rim
    r.hook("HookL", 240, 150, chain=110)
    r.hook("HookR", 400, 150, chain=110)
    r.node("BossArena", "Node2D", "res://scripts/world/boss_arena.gd", props={
        "boss_flag": S("boss_governor_defeated"), "boss_name": S("The Pendulum"), "trigger_x": "100",
        "door_rect": R(0, 256, 16, 64), "boss_path": 'NodePath("GreatGovernor")', "reward": S("shard"),
        "shard_number": "2", "shard_position": V(320, 290),
        "victory_text": S("The Pendulum slows... and settles into a steady, quiet hum."),
        "intro_lines": SA(["> The whole hall is one machine. Its flyballs lift as it notices you.",
                           "> The gauge on its crown swings into the red."])})
    r.node("GreatGovernor", "Node2D", "res://scripts/enemies/great_governor.gd", parent="BossArena")
    # the way on stays shut until The Pendulum stops (Shard II opens it)
    r.gate("ShutGate", 616, 320, 16, 64, gate_id="uw_governor_gate", shard=2)
    return r


# ------------------------------------------------------------------ 11 Swing Galleries
def galleries():
    r = UWBuilder("uw_11_galleries", "Swing Galleries", (0, 0, 1280, 400))
    r.solid(0, 0, 1280, 24, "brick")
    r.solid(0, 0, 16, 288, "brick")
    r.solid(1264, 0, 16, 136, "brick")
    r.solid(1160, 200, 104, 10, "grate")         # the ledge to the Loft: only a swing gets you up here
    r.solid(1264, 212, 16, 76, "brick")
    r.solid(0, 352, 200, 48, "plate")
    r.solid(440, 320, 48, 80, "brick")           # pillars between the boiling pits
    r.solid(720, 320, 48, 80, "brick")
    r.solid(960, 352, 320, 48, "plate")
    r.solid(200, 384, 760, 16, "plate")
    r.boiling("PitA", 200, 368, 240, 16)
    r.boiling("PitB", 488, 368, 232, 16)
    r.boiling("PitC", 768, 368, 192, 16)
    r.anchor("RingA", 320, 200)
    r.anchor("RingB", 604, 196)
    r.anchor("RingC", 864, 200)
    r.anchor("RingLoft", 1100, 180)
    r.exit("ExitToGovernor", 4, 320, 8, 64, "uw_10_governor", "from_galleries")
    r.exit("ExitToMarket", 1276, 320, 8, 64, "uw_02_market", "from_galleries")
    r.exit("ExitToLoft", 1276, 168, 8, 64, "uw_14_loft", "from_galleries")
    r.spawn("from_governor", 50, 352)
    r.spawn("from_market", 1230, 352)
    r.spawn("from_loft", 1220, 200)
    r.readable("Rings", 120, 352, "PLAQUE", [
        "> THE SWING GALLERIES. FOR THE INSPECTION OF THE UPPER WORKS.",
        "> Hook a ring. Press [throw] again to hang. Lean left and right to swing; up and down climbs the wire.",
        "> Jump to let go: you keep the speed."], lore="uw_galleries")
    r.lamp("Lamp0", 80, 352)
    r.lamp("Lamp1", 1000, 352)
    r.lamp("WallLamp", 600, 120, wall=True)
    r.cog("CogPillar", 744, 300)
    return r


# ------------------------------------------------------------------ 12 Old Tram Tunnel
def tunnel():
    r = UWBuilder("uw_12_tunnel", "Old Tram Tunnel", (0, 0, 1280, 360), **DARK)
    r.solid(0, 0, 16, 360, "brick")
    r.solid(96, 0, 1184, 24, "brick")
    r.solid(16, 320, 1264, 40, "plate")
    r.solid(480, 280, 40, 40, "plate")          # a crate: one hop up, then a running jump onto the roof
    r.solid(560, 262, 160, 8, "grate")           # the tram's roof
    r.solid(1264, 0, 16, 360, "brick")
    r.vent("LiftVent", 56, 320, reach=260)
    r.exit("ExitToMarket", 56, 4, 80, 8, "uw_02_market", "from_tunnel")
    r.spawn("from_market", 120, 320)
    r.prop("Tram", "uw_tram", 640, 320)
    r.prop("ForgeGate", "uw_forge_gate", 1220, 320)
    r.readable("Gate", 1220, 320, "THE FORGE GATE", [
        "> A heavy door at the end of Line 4, stamped with the seven hammers.",
        "> It's barred from the far side. The metal is warm, and somewhere behind it a hammer strikes, very slowly.",
        "> The way to the Fallen Forge. Not open yet."], prompt="Look", lore="uw_forge_gate", size=(60, 80))
    r.letter("Letter", 640, 250)
    r.cog("CogTrack", 900, 300)
    r.enemy("SpiderA", "clock_spider", 820, 320)
    r.enemy("SpiderB", "clock_spider", 1040, 320)
    r.enemy("Bat", "bellows_bat", 400, 120)
    r.lamp("Lamp0", 200, 320, radius=80)
    r.lamp("Lamp1", 1100, 320, radius=80)
    return r


# ------------------------------------------------------------------ 13 The Cistern
def cistern():
    r = UWBuilder("uw_13_cistern", "The Cistern", (0, 0, 800, 400), **DARK)
    r.solid(0, 0, 800, 24, "brick")
    r.solid(0, 0, 16, 400, "brick")
    r.solid(784, 0, 16, 288, "brick")
    r.solid(16, 352, 124, 48, "plate")
    r.solid(680, 352, 120, 48, "plate")
    r.solid(140, 384, 540, 16, "plate")
    r.boiling("Water", 140, 368, 540, 16)
    for i, (x, y) in enumerate(((580, 330), (470, 310), (360, 330), (250, 310))):
        r.solid(x, y, 56, 10, "grate")
    r.exit("ExitToFalls", 796, 320, 8, 64, "uw_07_falls", "from_cistern")
    r.spawn("from_falls", 750, 352)
    r.letter("Letter", 60, 352)
    r.cog("CogStone", 388, 300)
    r.enemy("BloatA", "boiler_bloat", 300, 200)
    r.enemy("BloatB", "boiler_bloat", 540, 180)
    r.lamp("Lamp0", 740, 352, radius=80)
    r.lamp("Lamp1", 90, 352, radius=80)
    r.readable("Mark", 110, 352, "SCRATCHES", [
        "> Tally marks on the wall: hundreds of them. Then a note.",
        "> \"Waited for the mail tram. It didn't come. Going up to ask. - T.\""], prompt="Look", lore="uw_cistern")
    return r


# ------------------------------------------------------------------ 14 Clockmaker's Loft (secret)
def loft():
    r = UWBuilder("uw_14_loft", "Clockmaker's Loft", (0, 0, 480, 360), ambient=(0.72, 0.64, 0.56))
    r.solid(0, 0, 480, 24, "brick")
    r.solid(0, 0, 16, 256, "brick")
    r.solid(464, 0, 16, 360, "brick")
    r.solid(0, 320, 480, 40, "plate")
    r.exit("ExitToGalleries", 4, 288, 8, 64, "uw_11_galleries", "from_loft")
    r.spawn("from_galleries", 60, 320)
    r.item("Port", 400, 296, 6, "port", "port expansion")
    r.cog("CogShelf", 60, 300)
    r.prop("Flywheel", "uw_flywheel", 330, 260, background="true", frames="4", fps="1")
    r.prop("Gauge", "uw_gauge", 80, 200, background="true", frames="2", fps="1")
    r.lamp("Lamp0", 300, 320)
    r.readable("Notes", 330, 320, "THE CLOCKMAKER'S NOTES", [
        "> Pages of drawings of The Pendulum. Then drawings of something smaller: a robot, with a blade on a wire.",
        "> \"The smiths left five pieces of the edge in five places, and a body to carry them.\"",
        "> \"If it ever wakes, it will come down here looking for the second. Leave it something useful.\""],
        lore="uw_clockmaker", size=(40, 40))
    return r


# ------------------------------------------------------------------ 15 Steam Trials (arena)
def trials():
    r = UWBuilder("uw_15_trials", "Steam Trials", (0, 0, 640, 360), **WORKS)
    r.solid(0, 0, 640, 24, "brick")
    r.solid(0, 0, 16, 360, "brick")
    r.solid(624, 0, 16, 360, "brick")
    r.solid(16, 320, 264, 40, "plate")
    r.solid(360, 320, 264, 40, "plate")
    r.solid(120, 220, 80, 10, "grate")
    r.solid(440, 220, 80, 10, "grate")
    r.exit("ExitToGauge", 320, 356, 80, 8, "uw_08_gauge", "from_trials")
    r.spawn("from_gauge", 230, 320)
    r.node("Arena", "Node2D", "res://scripts/world/arena_waves.gd", props={
        "trigger": R(120, 240, 400, 80), "seals": RA([(280, 320, 80, 16)]),
        "waves": SA(["clock_spider@150,clock_spider@480", "bellows_bat@200:120,piston_walker@450",
                     "boiler_bloat@160:160,boiler_bloat@480:160,clock_spider@320"]),
        "floor_y": "320", "reward_kind": "7", "reward_id": SN("core_cell"), "reward_pos": V(320, 200)})
    r.vent("VentL", 60, 320, reach=140)
    r.vent("VentR", 580, 320, reach=140)
    r.lamp("Lamp0", 100, 320)
    r.lamp("Lamp1", 540, 320)
    return r


ROOMS = (descent, market, row, works, gearworks, gallery, falls, gauge, approach, governor, galleries, tunnel, cistern, loft, trials)


if __name__ == "__main__":
    coins = 0
    for fn in ROOMS:
        r = fn()
        r.save()
        coins += r.coins
    print("underworks rooms written: %d; cogs in the world: %d" % (len(ROOMS), coins))
