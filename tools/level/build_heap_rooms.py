"""Generates the Heap's newer rooms as Godot scenes from compact descriptions.
Run from the project root:  python3 tools/level/build_heap_rooms.py

Hand-made rooms (camp, Hollow, Intake) are edited directly; the starting
tunnels and nine other rooms are described here so their geometry stays readable and consistent with the
movement rules: 40 px steps, staggered platform columns with a 44 px gap,
hooks placed so the reel-in path clears the ledge (see docs/HEAP_LAYOUT.md).
Re-running overwrites these scenes.
"""
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "scenes", "rooms", "heap")
H = "res://scenes/rooms/heap/"
# room id prefix -> scene folder, so exits can cross regions (heap_13 -> uw_01)
REGION_DIRS = {"heap_": "heap", "uw_": "underworks"}


def room_path(room_id):
    for prefix, folder in REGION_DIRS.items():
        if room_id.startswith(prefix):
            return "res://scenes/rooms/%s/%s.tscn" % (folder, room_id)
    return H + room_id + ".tscn"


# ------------------------------------------------------------------ godot literals
def V(x, y): return "Vector2(%g, %g)" % (x, y)
def R(x, y, w, h): return "Rect2(%g, %g, %g, %g)" % (x, y, w, h)
def C(r, g, b, a=1.0): return "Color(%g, %g, %g, %g)" % (r, g, b, a)
def SN(s): return '&"%s"' % s
def S(s): return '"%s"' % s.replace('"', '\\"')
def SA(items): return "Array[String]([%s])" % ", ".join(S(i) for i in items)
def RA(items): return "Array[Rect2]([%s])" % ", ".join(R(*r) for r in items)


class RoomBuilder:
    def __init__(self, room_id, name, bounds, backdrop="heap_outdoor", tileset="heap_scrap", grade="heap",
                 music="industrial", ambient=(0.88, 0.8, 0.78), motes=(1, 0.84, 0.6, 0.3), motes_amount=30,
                 region="heap", out_dir=None, bg=None):
        self.id = room_id
        self.region = region
        self.out_dir = out_dir or OUT
        self.bg = bg  # (top, bottom) colour hex strings for the room's sky fill
        self.head = dict(name=name, bounds=bounds, backdrop=backdrop, tileset=tileset, grade=grade, music=music,
                         ambient=ambient, motes=motes, motes_amount=motes_amount)
        self.solids = []
        self.ext = {}       # path -> (id, type)
        self.subs = []      # (id, text)
        self.nodes = []     # text blocks
        self.spawns = {}
        self.caps = 0
        self._n = 0

    # resources
    def res(self, path, kind):
        if path not in self.ext:
            self.ext[path] = ("e%d" % (len(self.ext) + 1), kind)
        return 'ExtResource("%s")' % self.ext[path][0]

    def shape(self, w, h):
        sid = "s%d" % (len(self.subs) + 1)
        self.subs.append((sid, '[sub_resource type="RectangleShape2D" id="%s"]\nsize = Vector2(%g, %g)\n' % (sid, w, h)))
        return 'SubResource("%s")' % sid

    # geometry
    def solid(self, x, y, w, h, style="ground"):
        self.solids.append(((x, y, w, h), style))

    def spawn(self, name, x, y):
        self.spawns[name] = (x, y)

    # nodes
    def node(self, name, typ=None, script=None, scene=None, pos=None, props=None, parent="."):
        head = '[node name="%s"' % name
        if scene:
            head += ' parent="%s" instance=%s]' % (parent, self.res(scene, "PackedScene"))
        else:
            head += ' type="%s" parent="%s"]' % (typ, parent)
        lines = [head]
        if pos is not None:
            lines.append("position = %s" % V(*pos))
        if script:
            lines.append("script = %s" % self.res(script, "Script"))
        for k, v in (props or {}).items():
            lines.append("%s = %s" % (k, v))
        self.nodes.append("\n".join(lines) + "\n")

    def exit(self, name, x, y, w, h, target, spawn):
        self.node(name, "Area2D", "res://scripts/world/room_exit.gd", pos=(x, y),
                  props={"target_room": S(room_path(target)), "target_spawn": SN(spawn)})
        self.nodes.append('[node name="CollisionShape2D" type="CollisionShape2D" parent="%s"]\nshape = %s\n' % (name, self.shape(w, h)))

    def prop(self, name, tex, x, y, **kw):
        props = {"texture": self.res("res://art/props/%s.png" % tex, "Texture2D")}
        for k, v in kw.items():
            props[k] = v
        self.node(name, "Node2D", "res://scripts/world/prop.gd", pos=(x, y), props=props)

    def glow(self, name, x, y, color, radius=40, light=90, energy=0.8, emit=None):
        props = {"glow_color": color, "glow_radius": "%g" % radius, "light_radius": "%g" % light, "light_energy": "%g" % energy}
        if emit:
            props["emit"] = S(emit)
        self.node(name, "Node2D", "res://scripts/world/prop.gd", pos=(x, y), props=props)

    def cap(self, name, x, y):
        self.caps += 1
        self.node(name, scene="res://scenes/world/collectible.tscn", pos=(x, y), props={"kind": "1"})

    def scrap(self, name, x, y, amount=4):
        self.node(name, scene="res://scenes/world/collectible.tscn", pos=(x, y), props={"amount": str(amount)})

    def item(self, name, x, y, kind, item_id, display=""):
        props = {"kind": str(kind), "item_id": SN(item_id)}
        if display:
            props["display_name"] = S(display)
        self.node(name, scene="res://scenes/world/collectible.tscn", pos=(x, y), props=props)

    def hook(self, name, x, y, chain=120):
        self.node(name, scene="res://scenes/world/grapple_point.tscn", pos=(x, y), props={"chain_length": "%g" % chain})

    def drone(self, name, x, y):
        self.node(name, scene="res://scenes/enemies/scrap_drone.tscn", pos=(x, y))

    def spotter(self, name, x, y):
        self.node(name, scene="res://scenes/enemies/spotter_drone.tscn", pos=(x, y))

    def crawler(self, name, x, y, ceiling=True):
        self.node(name, "CharacterBody2D", "res://scripts/enemies/rustcrawler.gd", pos=(x, y),
                  props={"start_on_ceiling": "true" if ceiling else "false"})

    def compactor(self, name, x, y):
        self.node(name, "CharacterBody2D", "res://scripts/enemies/compactor.gd", pos=(x, y))

    def hazard(self, name, x, y, w, h, kind="sludge"):
        self.node(name, "Area2D", "res://scripts/world/hazard.gd", pos=(x, y), props={"size": V(w, h), "kind": S(kind)})

    def conveyor(self, name, x, y, w, speed):
        self.node(name, "StaticBody2D", "res://scripts/world/conveyor.gd", pos=(x, y), props={"size": V(w, 12), "speed": "%g" % speed})

    def crusher(self, name, x, y, width, drop, period, offset=0.0):
        self.node(name, "Node2D", "res://scripts/world/crusher.gd", pos=(x, y),
                  props={"width": "%g" % width, "drop": "%g" % drop, "period": "%g" % period, "offset": "%g" % offset})

    def readable(self, name, x, y, title, lines, prompt="Read", lore="", size=(24, 32)):
        props = {"prompt": S(prompt), "title": S(title), "lines": SA(lines), "size": V(*size)}
        if lore:
            props["lore_id"] = S(lore)
        self.node(name, "Area2D", "res://scripts/world/readable.gd", pos=(x, y), props=props)

    def gate(self, name, x, y, w, h, gate_id="", shard=1):
        props = {"required_shard": str(shard), "size": V(w, h)}
        if gate_id:
            props["gate_id"] = S(gate_id)
        self.node(name, scene="res://scenes/world/ability_gate.tscn", pos=(x, y), props=props)

    def shaft(self, name, x, y, length, top=8, bottom=46, slant=20, energy=0.7, color=C(1, 0.84, 0.6, 0.16)):
        self.node(name, "Node2D", "res://scripts/world/light_shaft.gd", pos=(x, y),
                  props={"length": "%g" % length, "top_width": "%g" % top, "bottom_width": "%g" % bottom,
                         "slant": "%g" % slant, "land_light": "%g" % energy, "color": color})

    def scaffold(self, name, columns=(), ties=(), stilts=(), hangers=(), ground_y=336, hang_top=0):
        props = {"columns": RA(columns), "ties": "PackedFloat32Array(%s)" % ", ".join("%g" % t for t in ties),
                 "stilts": RA(stilts), "ground_y": "%g" % ground_y, "hangers": RA(hangers), "hang_top": "%g" % hang_top}
        # scaffolds go first so they draw behind everything
        self.node(name, "Node2D", "res://scripts/world/scaffold.gd", props=props)
        self.nodes.insert(0, self.nodes.pop())

    # output
    def save(self):
        h = self.head
        room_script = self.res("res://scripts/world/room.gd", "Script")
        lines = []
        ext_lines = ['[ext_resource type="%s" path="%s" id="%s"]' % (k, p, i) for p, (i, k) in self.ext.items()]
        total = len(self.ext) + len(self.subs) + 1
        lines.append("[gd_scene load_steps=%d format=3]\n" % total)
        lines += ext_lines
        lines.append("")
        for sid, text in self.subs:
            lines.append(text)
        root = ['[node name="%s" type="Node2D"]' % "".join(w.capitalize() for w in self.id.split("_")),
                "script = %s" % room_script,
                "room_id = %s" % SN(self.id), "region_id = %s" % SN(self.region), "tileset = %s" % S(h["tileset"]),
                "solid_styles = PackedStringArray(%s)" % ", ".join(S(st) for _, st in self.solids),
                "backdrop = %s" % S(h["backdrop"]), 'music = %s' % S(h["music"]),
                "ambient = %s" % C(*h["ambient"]), "grade = %s" % SN(h["grade"]), 'weather = "none"',
                "motes_color = %s" % C(*h["motes"]), "motes_amount = %d" % h["motes_amount"],
                "display_name = %s" % S(h["name"]), "bounds = %s" % R(*h["bounds"]),
                "solids = %s" % RA([r for r, _ in self.solids])]
        if self.bg:
            hexc = lambda h: C(*(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)))
            root += ["bg_top = %s" % hexc(self.bg[0]), "bg_bottom = %s" % hexc(self.bg[1])]
        root.append("")
        lines += root
        lines += self.nodes
        lines.append('[node name="Spawns" type="Node2D" parent="."]\n')
        for n, (x, y) in self.spawns.items():
            lines.append('[node name="%s" type="Marker2D" parent="Spawns"]\nposition = %s\n' % (n, V(x, y)))
        os.makedirs(self.out_dir, exist_ok=True)
        open(os.path.join(self.out_dir, self.id + ".tscn"), "w").write("\n".join(lines))
        return self.caps


CAVE = dict(backdrop="heap_cave", grade="cave", music="cave", ambient=(0.6, 0.55, 0.64), motes=(1, 0.86, 0.66, 0.2), motes_amount=24)
INDUSTRIAL = dict(backdrop="intake_interior", tileset="heap_industrial", grade="intake", music="industrial", ambient=(0.82, 0.72, 0.72), motes=(1, 0.7, 0.5, 0.25))


# ------------------------------------------------------------------ 05 Scrap Fields
def fields():
    r = RoomBuilder("heap_05_fields", "Scrap Fields", (0, 0, 1600, 480))
    r.solid(0, 0, 16, 368)
    r.solid(0, 432, 520, 48)
    r.solid(520, 404, 180, 76)
    r.solid(700, 432, 300, 48)
    r.solid(1100, 432, 500, 48)
    r.solid(1200, 392, 400, 40)
    r.solid(1260, 352, 340, 40)
    r.solid(1320, 312, 280, 40)
    r.solid(1380, 272, 220, 40)
    r.solid(1584, 0, 16, 208)
    for i, y in enumerate((232, 192, 152, 112, 72, 32)):   # the old crane mast (columns 44 px apart)
        r.solid(1256 if i % 2 == 0 else 1380, y, 80, 12, "girder")
    r.scaffold("CraneMast", columns=[(1256, 72, 80, 280), (1380, 32, 80, 240)], ties=(32, 72, 112, 152, 192, 232, 272))
    r.exit("ExitToCamp", 4, 400, 8, 64, "heap_02_camp", "from_fields")
    r.exit("ExitToSinkhole", 1050, 476, 100, 8, "heap_10_sinkhole", "from_fields")
    r.exit("ExitToCrane", 1370, 4, 260, 8, "heap_07_crane", "from_fields")
    r.exit("ExitToGiant", 1596, 240, 8, 64, "heap_09_giant", "from_fields")
    r.spawn("from_camp", 60, 432)
    r.spawn("from_sinkhole", 1150, 432)
    r.spawn("from_crane", 1420, 32)
    r.spawn("from_giant", 1550, 272)
    r.prop("CarCube", "car_cube", 300, 432, background="true")
    r.prop("Tyres", "tyres", 470, 432, background="true")
    r.prop("Barrel", "barrel", 560, 404, background="true")
    r.prop("Lamp", "street_lamp", 650, 404, background="true", light_radius="80", light_energy="0.8",
           glow_color=C(1, 0.75, 0.4, 0.5), glow_radius="26", glow_offset=V(5, -52), glow_flicker="0.25")
    r.prop("JunkA", "junk_a", 780, 432, background="true")
    r.prop("SinkSign", "warning_sign", 985, 432)
    r.readable("SinkholeSign", 985, 432, "SIGN", ["DANGER: SINKHOLE. The ground here eats things.",
                                                   "Underneath, in marker: \"Sprocket's left boot. RIP.\""], lore="fields_sinkhole")
    r.prop("JunkB", "junk_b", 1160, 432, background="true")
    r.prop("Crt", "crt_pile", 1235, 392, background="true", frames="2", fps="5")
    r.compactor("Compactor", 300, 432)
    r.spotter("Spotter", 820, 300)
    r.crawler("CrawlerFloor", 880, 432, ceiling=False)
    r.crawler("CrawlerMast", 1296, 164)
    r.cap("CapMound", 610, 384)
    r.cap("CapMast", 1420, 96)
    r.scrap("ScrapA", 450, 420)
    r.scrap("ScrapB", 1500, 256)
    return r.save()


# ------------------------------------------------------------------ 07 Crane Yard
def crane():
    r = RoomBuilder("heap_07_crane", "Crane Yard", (0, 0, 720, 600))
    r.solid(0, 0, 16, 600)
    r.solid(704, 0, 16, 272)
    r.solid(704, 336, 16, 264)
    r.solid(16, 568, 200, 32)
    r.solid(276, 584, 428, 16)
    r.solid(286, 512, 70, 12, "girder")
    r.solid(404, 442, 70, 12, "girder")
    r.solid(524, 372, 70, 12, "girder")
    r.solid(600, 336, 104, 16, "girder")
    r.solid(262, 372, 70, 12, "girder")
    r.scaffold("YardFrame", columns=[(604, 336, 96, 248)], ties=(400, 470, 540),
               hangers=[(286, 512, 70, 12), (404, 442, 70, 12), (524, 372, 70, 12), (262, 372, 70, 12)], hang_top=0)
    r.hazard("Spikes", 296, 572, 300, 12, "spikes")
    r.hook("Hook1", 300, 470)
    r.hook("Hook2", 420, 400)
    r.hook("Hook3", 540, 330)
    r.hook("HookSecret", 330, 330)
    r.exit("ExitToFields", 246, 596, 60, 8, "heap_05_fields", "from_crane")
    r.exit("ExitToConveyor", 716, 304, 8, 64, "heap_08_conveyor", "from_crane")
    r.spawn("from_fields", 110, 568)
    r.spawn("from_conveyor", 650, 336)
    r.prop("Tyres", "tyres", 80, 568, background="true")
    r.prop("Bales", "bale_stack", 170, 568, background="true")
    r.spotter("Spotter", 400, 220)
    r.cap("CapSecret", 296, 356)
    r.scrap("ScrapP2", 440, 426)
    return r.save()


# ------------------------------------------------------------------ 08 Conveyor Hall
def conveyor():
    r = RoomBuilder("heap_08_conveyor", "Conveyor Hall", (0, 0, 1280, 360), **INDUSTRIAL)
    r.solid(0, 0, 16, 272, "tiles")
    r.solid(1264, 0, 16, 272, "tiles")
    r.solid(0, 336, 600, 24, "tiles")
    r.solid(600, 348, 420, 12, "tiles")
    r.solid(1020, 336, 260, 24, "tiles")
    r.solid(16, 0, 344, 40, "tiles")
    r.solid(554, 0, 710, 40, "tiles")
    for i, y in enumerate((296, 256, 216, 176, 136, 96)):    # a service ladder up to the pit
        r.solid(360 if i % 2 == 0 else 484, y, 80 if i % 2 == 0 else 70, 12, "girder")
    r.scaffold("LadderFrame", columns=[(360, 136, 80, 200), (484, 96, 70, 240)], ties=(96, 136, 176, 216, 256, 296))
    r.conveyor("Belt", 600, 336, 420, -45)
    for i, x in enumerate((680, 820, 960)):
        r.crusher("Crusher%d" % (i + 1), x, 48, 48, 264, 2.4, i * 0.8)
    r.node("ChargingDock", scene="res://scenes/world/charging_dock.tscn", pos=(1130, 336), props={"spawn_name": SN("dock")})
    r.exit("ExitToCrane", 4, 304, 8, 64, "heap_07_crane", "from_conveyor")
    r.exit("ExitToIntake", 1276, 304, 8, 64, "heap_03_intake", "from_camp")
    r.exit("ExitToPit", 457, 4, 190, 8, "heap_12_compactor", "from_conveyor")
    r.spawn("from_crane", 50, 336)
    r.spawn("from_intake", 1220, 336)
    r.spawn("from_pit", 520, 96)
    r.spawn("dock", 1130, 336)
    r.prop("Bales", "bale_stack", 140, 336, background="true")
    r.prop("Chute", "chute", 1060, 336, background="true")
    r.prop("Lamp1", "warning_lamp", 750, 40, frames="2", fps="2", light_radius="40", light_energy="0.6",
           light_on_frame_zero="true", glow_color=C(1, 0.6, 0.25, 0.45), glow_radius="12", glow_offset=V(0, -5), hanging="true")
    r.prop("Sign", "warning_sign", 1235, 336)
    r.readable("BossSign", 1235, 336, "SIGN", ["INTAKE UNIT 7. AUTHORISED PERSONNEL ONLY.",
                                               "Someone has added, in paint: \"it can't see straight up.\""], lore="intake_warning")
    r.compactor("Compactor", 220, 336)
    r.crawler("Crawler1", 760, 40)
    r.crawler("Crawler2", 900, 40)
    r.cap("CapLadder", 400, 200)
    r.scrap("ScrapBelt", 1060, 320, 6)
    return r.save()


# ------------------------------------------------------------------ 12 Compactor Pit (arena)
def compactor_pit():
    r = RoomBuilder("heap_12_compactor", "Compactor Pit", (0, 0, 640, 360), **INDUSTRIAL)
    r.solid(0, 0, 16, 360, "tiles")
    r.solid(624, 0, 16, 360, "tiles")
    r.solid(16, 0, 608, 40, "tiles")
    r.solid(0, 336, 220, 24, "tiles")
    r.solid(300, 336, 340, 24, "tiles")
    r.solid(120, 256, 80, 12, "girder")
    r.solid(440, 256, 80, 12, "girder")
    r.solid(280, 196, 80, 12, "girder")
    r.scaffold("PitFrame", stilts=[(120, 256, 80, 12), (440, 256, 80, 12)], ground_y=336, hangers=[(280, 196, 80, 12)], hang_top=40)
    r.exit("ExitDown", 260, 356, 80, 8, "heap_08_conveyor", "from_pit")
    r.spawn("from_conveyor", 340, 336)
    r.node("Arena", "Node2D", "res://scripts/world/arena_waves.gd", props={
        "trigger": R(380, 200, 200, 136), "seals": RA([(220, 320, 80, 16)]),
        "waves": SA(["rustcrawler@200,rustcrawler@460", "compactor@500,rustcrawler@160:52", "compactor@150,compactor@520"]),
        "floor_y": "336", "reward_kind": "3", "reward_id": SN("piston_heart"), "reward_pos": V(320, 180)})
    r.prop("Bales", "bale_stack", 560, 336, background="true")
    r.prop("Chute", "chute", 80, 336, background="true")
    return r.save()


# ------------------------------------------------------------------ 10 Sinkhole
def sinkhole():
    r = RoomBuilder("heap_10_sinkhole", "Sinkhole", (0, 0, 400, 720), **CAVE)
    r.solid(0, 0, 16, 632)
    r.solid(384, 0, 16, 720)
    r.solid(0, 696, 400, 24)
    r.solid(16, 0, 104, 24, "ceiling")
    r.solid(280, 0, 104, 24, "ceiling")
    tops = list(range(656, 55, -40))
    for i, y in enumerate(tops):    # junk ledges zig-zagging up the shaft
        r.solid(184 if i % 2 == 0 else 60, y, 80, 12)
    r.solid(310, 336, 74, 12)
    r.shaft("ShaftTop", 200, 24, 420, 60, 110, 10, 0.8)
    r.exit("ExitToFields", 200, 4, 160, 8, "heap_05_fields", "from_sinkhole")
    r.exit("ExitToSeep", 4, 664, 8, 64, "heap_04_seep", "from_sinkhole")
    r.spawn("from_fields", 200, 40)
    r.spawn("from_seep", 40, 696)
    r.prop("Hang1", "hang_b", 60, 24, hanging="true", background="true")
    r.prop("Hang2", "hang_a", 330, 24, hanging="true", background="true")
    r.crawler("Crawler1", 100, 468)
    r.crawler("Crawler2", 100, 228)
    r.cap("CapAlcove", 346, 320)
    r.scrap("ScrapLow", 100, 600)
    r.scrap("ScrapMid", 224, 400)
    return r.save()


# ------------------------------------------------------------------ 04 Seep Tunnels
def seep():
    r = RoomBuilder("heap_04_seep", "Seep Tunnels", (0, 0, 3000, 300), backdrop="heap_cave", grade="cave", music="cave",
                    ambient=(0.55, 0.62, 0.55), motes=(0.7, 1, 0.6, 0.18), motes_amount=24)
    r.solid(0, 0, 16, 212)
    r.solid(2984, 0, 16, 212)
    r.solid(16, 0, 1660, 40, "ceiling")
    r.solid(1784, 0, 1200, 40, "ceiling")
    r.solid(1676, 0, 24, 100, "ceiling")    # the shaft up to the Hollow
    r.solid(1760, 0, 24, 100, "ceiling")
    r.solid(1700, 0, 60, 40, "ceiling")
    # 80 px pits clear with a running jump; 168 px pits need a slide-jump or dash-jump
    segs = [(0, 420), (500, 300), (968, 442), (1490, 610), (2268, 732)]
    pits = [(420, 80), (800, 168), (1410, 80), (2100, 168)]
    for x, w in segs:
        r.solid(x, 276, w, 24)
    for i, (x, w) in enumerate(pits):
        r.solid(x, 292, w, 8)
        r.hazard("Sludge%d" % (i + 1), x, 280, w, 12)
    # the lowest girder leaves 8 px over the robot's head (28 px tall) so you can walk under it
    for i, y in enumerate((228, 188, 148)):
        r.solid(1690 if i % 2 == 0 else 1814, y, 80 if i % 2 == 0 else 70, 12, "girder")
    r.scaffold("ShaftFrame", stilts=[(1690, 228, 80, 12), (1814, 188, 70, 12)], ground_y=276, hangers=[(1690, 148, 80, 12)], hang_top=100)
    r.gate("ShaftGate", 1730, 100, 60, 14, "heap_seep_shaft")
    r.gate("TramWall", 48, 276, 16, 64)
    r.exit("ExitToSinkhole", 2996, 244, 8, 64, "heap_10_sinkhole", "from_seep")
    r.exit("ExitToTram", 4, 244, 8, 64, "heap_11_tram", "from_seep")
    r.exit("ExitToHollow", 1730, 80, 60, 8, "heap_02b_undercamp", "from_seep")
    r.spawn("from_sinkhole", 2940, 276)
    r.spawn("from_tram", 90, 276)
    r.spawn("from_hollow", 1730, 148)
    for i, x in enumerate((300, 980, 1300, 2500, 2800)):
        r.prop("Hang%d" % i, ("hang_a", "hang_b", "hanging_cables")[i % 3], x, 40, hanging="true", background="true")
    r.crawler("Crawler1", 650, 40)
    r.crawler("Crawler2", 1200, 40)
    r.crawler("Crawler3", 2400, 40)
    r.crawler("CrawlerFloor", 2600, 276, ceiling=False)
    r.compactor("Compactor", 1150, 276)
    r.cap("CapPit", 855, 236)
    r.cap("CapEnd", 2900, 260)
    r.scrap("ScrapA", 600, 260)
    r.scrap("ScrapB", 2300, 260)
    return r.save()


# ------------------------------------------------------------------ 11 Old Tram Stop (secret)
def tram():
    r = RoomBuilder("heap_11_tram", "Old Tram Stop", (0, 0, 600, 300), backdrop="heap_cave", grade="cave", music="hollow",
                    ambient=(0.62, 0.56, 0.62), motes_amount=18)
    r.solid(0, 0, 16, 300)
    r.solid(584, 0, 16, 212)
    r.solid(0, 276, 600, 24)
    r.solid(16, 0, 568, 36, "ceiling")
    r.solid(450, 216, 100, 12, "girder")
    r.scaffold("Platform", stilts=[(450, 216, 100, 12)], ground_y=276)
    r.prop("Tram", "tram", 280, 276, light_radius="70", light_energy="0.7", glow_color=C(0.22, 0.95, 1, 0.35),
           glow_radius="14", glow_offset=V(46, -30))
    r.readable("TramPlate", 280, 276, "TRAM, LINE 4", [
        "> A plate by the door, enamel under the rust: LINE 4. HEAP - UNDERWORKS. SERVICE SUSPENDED.",
        "> The timetable lists stops nobody up top has heard of: Pipe Market. Bellows Row. The Forge Gate.",
        "> Someone lived in here once. A coat still hangs by the driver's seat, brass buttons polished.",
        "> The cab lamp is on. After all this time, the line still has power somewhere."], prompt="Look", lore="tram_line4", size=(90, 40))
    r.item("Coat", 500, 200, 4, "cloak_wren")
    r.cap("CapTram", 120, 260)
    r.exit("ExitToSeep", 596, 244, 8, 64, "heap_04_seep", "from_tram")
    r.spawn("from_seep", 550, 276)
    r.glow("Lantern", 150, 120, C(1, 0.75, 0.4, 0.4), 22, 80, 0.6)
    return r.save()


# ------------------------------------------------------------------ 13 Underworks Gate (demo end)
def gate():
    r = RoomBuilder("heap_13_gate", "Underworks Gate", (0, 0, 520, 360), backdrop="intake_interior", tileset="heap_industrial",
                    grade="intake", music="hollow", ambient=(0.95, 0.8, 0.66), motes=(1, 0.8, 0.5, 0.35), motes_amount=40)
    r.solid(0, 0, 16, 56, "tiles")
    r.solid(0, 120, 120, 16, "girder")
    for i in range(5):
        r.solid(120 + i * 40, 152 + i * 32, 40, 8, "girder")
    r.solid(300, 336, 220, 24, "tiles")
    r.solid(16, 0, 504, 24, "tiles")
    r.solid(504, 0, 16, 272, "tiles")            # opening at the bottom right: the way down
    r.solid(0, 136, 16, 224, "tiles")
    r.scaffold("Stairs", stilts=[(120 + i * 40, 152 + i * 32, 40, 8) for i in range(5)], ground_y=360)
    for i, (x, y) in enumerate(((180, 100), (330, 200), (460, 150))):
        r.prop("Pipe%d" % i, "pipe_run", x, y, background="true")
    r.glow("SteamA", 360, 336, C(1, 0.75, 0.45, 0.4), 30, 120, 1.0, "smoke")
    r.glow("SteamB", 470, 336, C(1, 0.75, 0.45, 0.3), 24, 100, 0.8, "smoke")
    r.glow("DeepLight", 420, 300, C(1, 0.7, 0.4, 0.5), 60, 200, 1.2)
    r.readable("Arch", 400, 336, "INSCRIPTION", [
        "> Letters in the smiths' tongue are cut into the arch. Somehow you can read them.",
        "\"TAL REN VES. Here the last edge goes down, to be made whole.\""], lore="gate_inscription", size=(40, 40))
    r.exit("ExitToUnderworks", 516, 304, 8, 64, "uw_01_descent", "from_heap")
    r.exit("ExitToHollow", 4, 88, 8, 64, "heap_02b_undercamp", "from_gate")
    r.spawn("from_hollow", 40, 120)
    r.spawn("from_underworks", 470, 336)
    return r.save()


# ------------------------------------------------------------------ 09 Giant's Brow (mini-boss)
def giant():
    r = RoomBuilder("heap_09_giant", "Giant's Brow", (0, 0, 640, 480), music="industrial", ambient=(0.92, 0.82, 0.76))
    r.solid(0, 0, 16, 368)
    r.solid(0, 432, 640, 48)
    r.solid(624, 0, 16, 432)
    r.solid(120, 352, 80, 12, "girder")
    r.solid(300, 312, 80, 12, "girder")
    r.scaffold("Stilts", stilts=[(120, 352, 80, 12), (300, 312, 80, 12)], ground_y=432)
    r.node("BrassHead", "Node2D", "res://scripts/enemies/brass_head.gd", pos=(560, 442), props={
        "floor_y": "432", "arena_left": "20", "vents": "PackedFloat32Array(90, 240, 420)", "drop_pos": V(260, 400)})
    r.readable("MakersMark", 470, 432, "MAKER'S MARK", [
        "> Up close, the giant's brow is stamped with a maker's mark: seven hammers ringed around a blade.",
        "> The same seven as the tablet in the Hollow. The smiths built this, too.",
        "> Whatever it was guarding, it guarded it for two thousand years."], prompt="Look", lore="giant_mark", size=(40, 40))
    r.exit("ExitToFields", 4, 400, 8, 64, "heap_05_fields", "from_giant")
    r.spawn("from_fields", 50, 432)
    r.prop("Tyres", "tyres", 70, 432, background="true")
    r.prop("JunkA", "junk_a", 220, 432, background="true")
    return r.save()


# ------------------------------------------------------------------ 01 Under the Heap (start)
def carve_rock(r, W, H, air, rock_back=(), cell=8):
    """Fill the room with compacted junk, cut out the `air` rects, put the
    `rock_back` rects back, and add the rock as merged rectangles (style "rock")."""
    cols, rows = W // cell, H // cell
    grid = [[True] * cols for _ in range(rows)]
    def paint(rects, val):
        for (x, y, w, h) in rects:
            assert x % cell == 0 and y % cell == 0 and w % cell == 0 and h % cell == 0, (x, y, w, h)
            for cy in range(y // cell, (y + h) // cell):
                for cx in range(x // cell, (x + w) // cell):
                    if 0 <= cx < cols and 0 <= cy < rows:
                        grid[cy][cx] = val
    paint(air, False)
    paint(rock_back, True)
    # merge row runs, then stack identical runs downwards
    open_runs = {}   # (x0, x1) -> start row
    rects = []
    for cy in range(rows + 1):
        runs = set()
        if cy < rows:
            cx = 0
            while cx < cols:
                if grid[cy][cx]:
                    x0 = cx
                    while cx < cols and grid[cy][cx]:
                        cx += 1
                    runs.add((x0, cx))
                else:
                    cx += 1
        for run in list(open_runs):
            if run not in runs:
                y0 = open_runs.pop(run)
                rects.append((run[0] * cell, y0 * cell, (run[1] - run[0]) * cell, (cy - y0) * cell))
        for run in runs:
            if run not in open_runs:
                open_runs[run] = cy
    for rect in sorted(rects, key=lambda q: (q[1], q[0])):
        r.solid(*rect, "rock")


def pit():
    """The wake-up tunnels. One route, taught in order:
    wake chamber (first drone) -> tunnel with a step and a 64 px spike pit (jump)
    -> a 160 px chimney of staggered girders, 40 px apart with a 44 px gap (climb;
    a vest nook off one girder; a Shard I scrap wall hides the Scrap Plating chip)
    -> the upper tunnel (power cell, drone) and a 176 px spike gap (slide-jump or dash-jump)
    -> an 80 px wall with a hook above it (throw, reel in) -> the way out to camp."""
    r = RoomBuilder("heap_01_pit", "Under the Heap", (0, 0, 1280, 720), backdrop="heap_cave", grade="cave", music="cave",
                    ambient=(0.6, 0.54, 0.66), motes=(1, 0.86, 0.66, 0.22), motes_amount=34)
    air = [
        (16, 528, 240, 128),     # A  wake chamber, floor 656
        (256, 528, 240, 128),    # B  tunnel east (128 tall: a full jump off the step needs 86 px)
        (368, 656, 64, 32),      #    the spike pit
        (496, 224, 160, 432),    # C  the chimney
        (440, 400, 56, 56),      #    secret alcove (behind the scrap wall)
        (656, 448, 48, 48),      #    vest nook
        (656, 240, 400, 96),     # D  upper tunnel, floor 336
        (896, 336, 176, 80),     #    the gap: too far to jump; dash-jump or slide-jump it
        (1056, 160, 160, 176),   # E  hook chamber
        (1216, 160, 64, 96),     # F  way out, floor 256
    ]
    rock_back = [
        (304, 624, 64, 32),      # B  the step up
        (432, 624, 64, 32),      #    landing after the pit
        (720, 320, 48, 16),      # D  hump with the power cell
        (1168, 256, 48, 80),     # E  the wall you hook up
    ]
    carve_rock(r, 1280, 720, air, rock_back)
    # chimney girders: 40 px apart, alternating sides with a 44 px gap between columns
    tops = [616, 576, 536, 496, 456, 416, 376, 336]
    for i, y in enumerate(tops):
        if i % 2 == 0:
            r.solid(496, y, 64, 12, "girder")
        else:
            r.solid(604, y, 52, 12, "girder")
    r.scaffold("ChimneyFrame", stilts=[(496, 616, 64, 12)], ground_y=656,
               hangers=[(604, 576, 52, 12), (496, 536, 64, 12), (604, 496, 52, 12), (496, 456, 64, 12),
                        (604, 416, 52, 12), (496, 376, 64, 12)], hang_top=224)
    # hazards
    r.hazard("Spikes1", 368, 676, 64, 12, "spikes")
    r.hazard("Spikes2", 896, 404, 176, 12, "spikes")
    # the way through
    r.prop("WakePod", "ancient_casing", 66, 658, light_radius="40", light_energy="0.45",
           glow_color=C(0.22, 0.95, 1, 0.35), glow_radius="14", glow_offset=V(17, -14))
    r.item("ChipLongTether", 336, 606, 3, "long_tether")
    r.item("PowerCell", 744, 300, 2, "power_cell", "Power Cell")
    r.readable("DashScratch", 868, 336, "SCRATCHED INTO THE JUNK", [
        "> Someone scratched an arrow here, pointing across the gap, and the word JUMP.",
        "> Under it, in different handwriting: NO. RUN, SLIDE, THEN JUMP. (Or dash and jump out of it.)"], prompt="Read", lore="pit_dash", size=(28, 32))
    r.hook("HookTutorial", 1180, 216, 56)
    r.readable("HookScratch", 1110, 336, "SCRATCHED INTO THE JUNK", [
        "> A crane hook dangles above the wall. Someone drew a little figure throwing a line at it.",
        "> (Throw your blade at the hook, then click again to reel yourself up.)"], prompt="Read", lore="pit_hook", size=(28, 32))
    r.gate("ScrapWall", 490, 456, 14, 56)
    r.item("ChipScrapPlating", 462, 440, 3, "scrap_plating")
    r.item("VestHazard", 684, 480, 4, "shirt_hazard_vest")
    # pickups
    r.cap("Cap1", 200, 636)
    r.cap("Cap2", 400, 580)
    r.cap("Cap3", 520, 516)
    r.cap("Cap4", 984, 300)
    r.scrap("Scrap1", 150, 640, 3)
    r.scrap("Scrap2", 840, 320, 3)
    # enemies
    r.drone("Drone1", 610, 656)        # waits at the foot of the chimney, away from the wake-up spot
    r.drone("Drone2", 800, 336)
    r.spotter("Spotter1", 984, 280)      # over the dash gap, not in the hook's throw line
    # light and dressing
    r.shaft("ShaftWake", 112, 528, 130, 6, 46, -26, 1.0, C(1, 0.84, 0.6, 0.2))
    r.shaft("ShaftChimney", 584, 224, 432, 8, 70, -12, 0.7)
    r.shaft("ShaftHook", 1150, 160, 176, 6, 40, 14, 0.6)
    r.glow("TunnelGlow", 1262, 228, C(1, 0.8, 0.55, 0.5), 54, 130, 1.1)
    r.prop("JunkA", "junk_a", 230, 656, background="true")
    r.prop("Tyres", "tyres", 470, 624, background="true")
    r.prop("CrtPile", "crt_pile", 1010, 336, background="true")
    r.prop("Barrel", "barrel", 1080, 336, background="true")
    r.prop("Hang1", "hang_a", 190, 528, hanging="true", background="true")
    r.prop("Hang2", "hanging_cables", 300, 528, hanging="true", background="true")
    r.prop("Hang3", "hang_b", 760, 240, hanging="true", background="true")
    r.prop("Hang4", "hang_c", 950, 240, hanging="true", background="true")
    r.prop("Hang5", "hanging_cables", 1240, 160, hanging="true", background="true")
    r.exit("ExitToCamp", 1276, 224, 8, 64, "heap_02_camp", "from_pit")
    r.spawn("wake", 80, 656)
    r.spawn("from_camp", 1236, 256)
    return r.save()


if __name__ == "__main__":
    caps = sum(fn() for fn in (pit, fields, crane, conveyor, compactor_pit, sinkhole, seep, tram, gate, giant))
    print("rooms written; bottlecaps in generated rooms:", caps)
