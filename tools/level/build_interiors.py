"""Generates the walk-in building interiors (top-down, Undertale style) as Godot scenes.
Run from the project root:  python3 tools/level/build_interiors.py

Coordinates are pixels. The back wall is the band y = 0..64; the floor runs
below it. "stand" props have their feet at (x, y) and sort in depth with the
robot; "wall" props hang on the back wall centred at (x, y); "floor" props lie
flat. Footprints are the solid base of a piece of furniture.
The shopkeepers are ordinary NPC nodes (look, lines, shop) standing in the
room, so shops and dialogue work exactly as they did outdoors.
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "scenes", "interiors")
os.makedirs(OUT, exist_ok=True)
WALL = 64


def V2(x, y): return "Vector2(%g, %g)" % (x, y)
def S(s): return '"%s"' % s.replace('"', '\\"')
def SN(s): return '&"%s"' % s
def SA(items): return "Array[String]([%s])" % ", ".join(S(i) for i in items)
def C(r, g, b, a=1.0): return "Color(%g, %g, %g, %g)" % (r, g, b, a)


class Interior:
    def __init__(self, iid, name, size, floor, wall, exit_x, music="camp", ambient=(1.0, 0.96, 0.92), grade="heap"):
        self.id = iid
        self.head = dict(name=name, size=size, floor=floor, wall=wall, exit_x=exit_x, music=music, ambient=ambient, grade=grade)
        self.ext = {}
        self.nodes = []

    def res(self, path, kind):
        if path not in self.ext:
            self.ext[path] = ("e%d" % (len(self.ext) + 1), kind)
        return 'ExtResource("%s")' % self.ext[path][0]

    def node(self, name, typ=None, script=None, scene=None, props=None):
        head = '[node name="%s"' % name
        head += (' parent="." instance=%s]' % self.res(scene, "PackedScene")) if scene else (' type="%s" parent="."]' % typ)
        lines = [head]
        if script:
            lines.append("script = %s" % self.res(script, "Script"))
        for k, v in (props or {}).items():
            lines.append("%s = %s" % (k, v))
        self.nodes.append("\n".join(lines) + "\n")

    def tex(self, name):
        path = name if name.startswith("res://") else "res://art/interiors/%s.png" % name
        return self.res(path, "Texture2D")

    def _prop(self, name, tex, x, y, mode, footprint=None, look=None, reach=None):
        props = {"position": V2(x, y), "texture": self.tex(tex), "mode": S(mode)}
        if footprint:
            props["footprint"] = V2(*footprint)
        if look:
            props["look_lines"] = SA(look)
        if reach:
            props["reach"] = "%g" % reach
        self.node(name, "Node2D", "res://scripts/interior/interior_prop.gd", props=props)

    def stand(self, name, tex, x, y, footprint=None, look=None, reach=None):
        self._prop(name, tex, x, y, "stand", footprint, look, reach)

    def wall(self, name, tex, x, y, look=None):
        self._prop(name, tex, x, y, "wall", None, look, 44 if look else None)

    def floor(self, name, tex, x, y):
        self._prop(name, tex, x, y, "floor")

    def keeper(self, name, x, y, data, reach=30):
        """The NPC standing in the room, and the node that makes it talkable from the room."""
        props = {"position": V2(x, y)}
        props.update(data)
        self.node(name, scene="res://scenes/world/npc.tscn", props=props)
        self.node(name + "InRoom", "Node2D", "res://scripts/interior/interior_npc.gd",
                  props={"position": V2(x, y), "npc_path": 'NodePath("../%s")' % name, "reach": "%g" % reach})

    def save(self):
        h = self.head
        root_script = self.res("res://scripts/interior/interior_room.gd", "Script")
        floor = self.tex(h["floor"])
        wall = self.tex(h["wall"])
        lines = ["[gd_scene load_steps=%d format=3]\n" % (len(self.ext) + 1)]
        lines += ['[ext_resource type="%s" path="%s" id="%s"]' % (k, p, i) for p, (i, k) in self.ext.items()]
        lines.append("")
        lines += ['[node name="%s" type="Node2D"]' % "".join(w.capitalize() for w in self.id.split("_")),
                  "script = %s" % root_script,
                  "interior_id = %s" % SN(self.id), "display_name = %s" % S(h["name"]),
                  "size = %s" % V2(*h["size"]), "floor_texture = %s" % floor, "wall_texture = %s" % wall,
                  "music = %s" % S(h["music"]), "ambient = %s" % C(*h["ambient"]), "exit_x = %g" % h["exit_x"]]
        if h["grade"] != "heap":
            lines.append("grade = %s" % SN(h["grade"]))
        lines.append("")
        lines += self.nodes
        open(os.path.join(OUT, self.id + ".tscn"), "w").write("\n".join(lines))


LINEAGE = "res://data/lineages/heapfolk.tres"
F = WALL


def rusty():
    r = Interior("rusty_shop", "Rusty's Scrap & Sundries", (224, 128), "floor_plate", "wall_corrugated", 112)
    lin = r.res(LINEAGE, "Resource")
    items = ", ".join(r.res("res://data/shop/%s.tres" % n, "Resource") for n in
                      ("rusty_cloak", "rusty_mask", "rusty_magnet", "rusty_repair", "rusty_reflex", "rusty_port"))
    shop_script = r.res("res://scripts/resources/shop_item.gd", "Script")
    r.wall("Window", "window", 152, 30, look=[
        "* Outside: the camp. Further out, the city's lights, pretending you can't see them."])
    r.wall("Poster", "poster", 200, 32, look=[
        "* A corp poster: THE SPIRE PROVIDES.", "* Someone has slashed it. Carefully. Twice."])
    r.stand("Shelf1", "shelf", 30, F + 10, (44, 8), look=[
        "* Tin cans, gears, a radio with no insides.", "* Every price tag just says ASK. You suspect the answer changes."])
    r.stand("Shelf2", "shelf_b", 80, F + 10, (44, 8), look=[
        "* A box of lightbulbs. Most of them are just glass and hope."])
    r.keeper("Rusty", 116, F + 34, {
        "npc_id": SN("rusty"), "display_name": S("Rusty"),
        "shop_items": "Array[%s]([%s])" % (shop_script, items),
        "shop_greeting": S("Bottlecaps or scrap, I take both. Bottlecaps only work here in the Heap, mind."),
        "prompt": S("Shop"), "lineage": lin, "pin_headwear": S("bandana"), "pin_goggles": S("single"), "pin_accessory": S("apron")},
        reach=44)
    r.stand("Counter", "counter", 112, F + 58, (84, 12), look=[
        "* The counter. A till, a scale, and a sign: NO HAGGLING. Under it, smaller: (some haggling)."])
    r.stand("Tyres", "res://art/props/tyres.png", 198, F + 36, (30, 8), look=[
        "* A stack of tyres. Rusty sells them one at a time.", "* Nobody has ever bought one."])
    r.stand("Crates", "crates", 24, F + 122, (34, 10), look=[
        "* Crates stamped with a logo nobody remembers.", "* One of them is ticking. You decide that's Rusty's business."])
    r.stand("Barrel", "res://art/props/barrel.png", 204, F + 114, (14, 6), look=[
        "* It smells like the Intake. You take a step back."])
    r.floor("Doormat", "doormat", 112, F + 120)
    r.save()


def dot():
    r = Interior("dot_house", "Dot's Map Room", (192, 120), "floor_planks", "wall_boards", 96)
    lin = r.res(LINEAGE, "Resource")
    shop_script = r.res("res://scripts/resources/shop_item.gd", "Script")
    r.wall("Window", "window", 28, 32, look=[
        "* The Spire: a thin dark line against the smog.", "* A note is pinned to the frame: DON'T MAP THAT."])
    r.wall("MapCamp", "map_a", 86, 28, look=[
        "* A map of the camp, drawn with care.", "* Your corner of it is labelled: ROBOT (TEMPORARY?)"])
    r.wall("MapFields", "map_b", 116, 26, look=[
        "* The Scrap Fields, all ridgelines and question marks.", "* In one corner, in very small letters: HERE BE COMPACTORS."])
    r.wall("MapBlank", "map_a", 150, 32, look=[
        "* This one is blank except for a circle drawn under the camp, and one word:", "* WHY."])
    r.stand("Desk", "desk", 52, F + 24, (66, 10), look=[
        "* Ink, quills, and a half-finished map of somewhere you haven't been yet."])
    r.keeper("Dot", 106, F + 26, {
        "npc_id": SN("dot"), "display_name": S("Dot"),
        "shop_items": "Array[%s]([%s])" % (shop_script, r.res("res://data/shop/dot_map.tres", "Resource")),
        "shop_greeting": S("Maps! Real ones. I walked every room myself. Mostly. 25 scrap and it's yours."),
        "prompt": S("Trade"),
        "idle_lines": SA(["I'm drawing every room in the Heap. When I'm done I'll sell the maps. To you, probably. You're the only one who leaves.",
                          "There's a blank spot on my map right under the camp. I hate blank spots."]),
        "lineage": lin, "age": S("teen"), "pin_headwear": S("beanie"), "pin_goggles": S("double"), "pin_accessory": S("lantern")})
    r.stand("Globe", "globe", 164, F + 22, (20, 8), look=[
        "* A globe made from a hubcap and wire. The continents are guesses.",
        "* Someone has drawn a little brass door in the middle of the ocean."])
    r.stand("Stool", "stool", 80, F + 38, (12, 4))
    r.stand("Papers1", "papers", 20, F + 96, (20, 6), look=[
        "* Surveys. Hundreds of them.", "* ROOM WIDTH: 9 PACES. ROOM WIDTH (AGAIN): 9 AND A HALF PACES. ROOM WIDTH: ARGH."])
    r.stand("Papers2", "papers", 172, F + 104, (20, 6))
    r.floor("Rug", "rug", 96, F + 70)
    r.floor("Doormat", "doormat", 96, F + 112)
    r.save()


def mags():
    r = Interior("mags_garage", "Mags' Garage", (240, 136), "floor_concrete", "wall_brick", 120)
    lin = r.res(LINEAGE, "Resource")
    r.wall("Pegboard", "pegboard", 56, 32, look=[
        "* Every tool has its outline painted behind it.", "* The outline for the big wrench is empty. Mags has drawn a sad face in it."])
    r.wall("Window", "window", 196, 32, look=[
        "* Through the grime: the crane, swinging slowly out over the Intake."])
    r.stand("Bench", "bench", 58, F + 22, (74, 10), look=[
        "* A motor, halfway stripped.", "* The bolts are lined up by size, then by how much Mags likes them."])
    r.keeper("Mags", 112, F + 30, {
        "npc_id": SN("mags"), "display_name": S("Mags"),
        "idle_lines": SA(["Name's Mags. I fix what the Heap breaks, which is everything.",
                          "That hatch by the tank? Old-world maintenance shaft. I've heard it hiss at night. Like steam. Nobody down here's got steam.",
                          "If you go poking under the camp, bring back anything brass. I'll know what it is. Probably."]),
        "lineage": lin, "pin_headwear": S("bandana"), "pin_goggles": S("raised"), "pin_accessory": S("belt")})
    r.stand("RobotFrame", "robot_frame", 148, F + 20, (20, 8), look=[
        "* A robot frame on a stand. One arm. No name.", "* Its eye is dark. You look at it for a while. It doesn't look back."])
    r.stand("Drum", "res://art/props/barrel.png", 226, F + 34, (14, 6), look=["* Oil, mostly. Some of it is moving."])
    r.stand("Engine", "engine", 184, F + 92, (32, 10), look=["* An engine block. Still warm. You don't ask."])
    r.stand("Tyres", "res://art/props/tyres.png", 220, F + 130, (30, 8))
    r.stand("Crates", "crates", 26, F + 130, (34, 10))
    r.floor("Doormat", "doormat", 120, F + 128)
    r.save()


KIN = "res://data/lineages/bellows_kin.tres"
UW_AMBIENT = (0.96, 0.9, 0.82)


def gauge_gear():
    """Gilda's instrument shop in Pipe Market: brass panelling, cases of gauges."""
    r = Interior("gauge_gear", "Gauge & Gear", (240, 128), "floor_tile", "wall_brass", 120, music="underworks", ambient=UW_AMBIENT, grade="underworks")
    lin = r.res(KIN, "Resource")
    shop_script = r.res("res://scripts/resources/shop_item.gd", "Script")
    items = ", ".join(r.res("res://data/shop/%s.tres" % n, "Resource") for n in ("gilda_monocle", "gilda_cell", "gilda_repair", "gilda_port"))
    r.wall("Timetable", "timetable", 44, 30, look=[
        "* A price list. Every item is priced in cogs, and then, smaller, in 'favours'.",
        "* The favours column is much longer."])
    r.wall("Window", "window", 196, 30, look=[
        "* Pipe Market through warped glass: lamplight, steam, a man arguing with a kettle."])
    r.stand("Case1", "gauge_case", 40, F + 30, (44, 10), look=[
        "* Gauges for pressure, for heat, for depth.", "* One is labelled MOOD. Its needle is at 'FINE'. It's always at 'FINE'."])
    r.keeper("Gilda", 128, F + 30, {
        "npc_id": SN("gilda"), "display_name": S("Gilda"),
        "shop_items": "Array[%s]([%s])" % (shop_script, items),
        "shop_greeting": S("Cogs, please. Scrap if you must. I don't haggle; I calibrate."),
        "prompt": S("Shop"), "lineage": lin, "pin_headwear": S("stovepipe"), "pin_goggles": S("monocle"), "pin_accessory": S("brass_arm")},
        reach=44)
    r.stand("Counter", "counter", 128, F + 54, (84, 12), look=[
        "* A brass counter, polished so hard you can see your eye in it.", "* Your eye looks worried. You decide that's the counter's fault."])
    r.stand("Case2", "gauge_case", 206, F + 96, (44, 10), look=[
        "* A case of salvaged parts, labelled by hand: TICKS, TOCKS, MISC. CLOCK."])
    r.stand("Crates", "crates", 24, F + 120, (34, 10))
    r.floor("Doormat", "doormat", 120, F + 120)
    r.save()


def kettle():
    """The Kettle: Pipe Market's tea house. Wick sits by the window."""
    r = Interior("kettle", "The Kettle", (256, 136), "floor_planks", "wall_tea", 128, music="underworks", ambient=UW_AMBIENT, grade="underworks")
    lin = r.res(KIN, "Resource")
    quest = r.res("res://data/quests/last_lamplighter.tres", "Resource")
    r.wall("Window", "window", 216, 30, look=[
        "* Far off, the Lamplighter's Gallery. From here it's just a dark smudge.", "* Wick has been watching it."])
    r.stand("Bar", "tea_bar", 72, F + 46, (90, 12), look=[
        "* The urn is the size of a boiler, because it used to be one.", "* It sings when it's ready. Nobody has told it to stop."])
    r.keeper("Tamsin", 96, F + 22, {
        "npc_id": SN("tamsin"), "display_name": S("Tamsin"),
        "idle_lines": SA(["Tea's on. It's always on. The urn doesn't have an off.",
                          "We used to get people from Line 4. Now it's just us and the steam.",
                          "Wick's been sitting by that window for years. If you're going near the Gallery, talk to him."]),
        "lineage": lin, "pin_headwear": S("bowler"), "pin_goggles": S("raised"), "pin_accessory": S("apron")}, reach=44)
    r.keeper("Wick", 190, F + 58, {
        "npc_id": SN("wick"), "display_name": S("Wick"), "quest": quest, "age": S("elder"),
        "idle_lines": SA(["I lit the lamps. Forty years."]),
        "lineage": lin, "pin_headwear": S("stovepipe"), "pin_goggles": S("monocle"), "pin_accessory": S("cane")})
    r.stand("Table", "stool", 176, F + 72, (12, 4))
    r.stand("Stool", "stool", 140, F + 92, (12, 4))
    r.floor("Rug", "rug", 128, F + 80)
    r.floor("Doormat", "doormat", 128, F + 128)
    r.save()


def depot():
    """Line 4 depot office: the post office and the mapmaker's desk."""
    r = Interior("tram_depot", "Line 4 Depot", (256, 128), "floor_tile", "wall_depot", 128, music="underworks", ambient=UW_AMBIENT, grade="underworks")
    lin = r.res(KIN, "Resource")
    quest = r.res("res://data/quests/letters_home.tres", "Resource")
    shop_script = r.res("res://scripts/resources/shop_item.gd", "Script")
    r.wall("Timetable", "timetable", 128, 30, look=[
        "* LINE 4: EVERY 20 MINUTES.", "* Someone has crossed out MINUTES and written YEARS."])
    r.wall("MapWall", "map_b", 214, 28, look=[
        "* A map of the tunnels in a careful hand. Half the lines are dotted: 'not walked yet'."])
    r.stand("Desk", "ticket_desk", 64, F + 22, (78, 10), look=[
        "* A ledger of every letter that ever came through. The last page is a list of ones that didn't."])
    r.keeper("Hale", 64, F + 4, {
        "npc_id": SN("hale"), "display_name": S("Postmistress Hale"), "quest": quest, "age": S("elder"),
        "idle_lines": SA(["Post office is closed. Has been for sixty years."]),
        "lineage": lin, "pin_headwear": S("bowler"), "pin_goggles": S("monocle"), "pin_accessory": S("none")}, reach=40)
    r.keeper("Quill", 200, F + 54, {
        "npc_id": SN("quill"), "display_name": S("Quill"),
        "shop_items": "Array[%s]([%s])" % (shop_script, r.res("res://data/shop/quill_map.tres", "Resource")),
        "shop_greeting": S("A map of the Underworks. Every vault I've walked. 30 scrap: I'm saving for boots."),
        "prompt": S("Trade"), "age": S("teen"),
        "idle_lines": SA(["Dot sends letters down the old pneumatic tube. She says your camp's map is better than mine. It is not."]),
        "lineage": lin, "pin_headwear": S("none"), "pin_goggles": S("double"), "pin_accessory": S("pack")})
    r.stand("Papers", "papers", 228, F + 100, (20, 6))
    r.stand("Crates", "crates", 30, F + 116, (34, 10), look=[
        "* Mail sacks. Empty. Hale folds them every morning."])
    r.floor("Doormat", "doormat", 128, F + 120)
    r.save()


if __name__ == "__main__":
    rusty()
    dot()
    mags()
    gauge_gear()
    kettle()
    depot()
    print("interiors written")
