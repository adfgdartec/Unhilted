class_name MapData
extends RefCounted
## Where every room sits in its region, for the in-game map.
## origin = world position of the room's (0, 0); rect = the room's bounds
## (kept in sync with the scene; a test checks every entry against its scene).
## icons: "dock", "shop", "boss", "miniboss", "secret", "town", "exit"

const REGIONS := {
	&"heap": {
		"name": "The Heap",
		"rooms": {
			&"heap_01_pit": {"name": "Under the Heap", "origin": Vector2(0, 176), "rect": Rect2(0, 0, 1280, 720), "icons": []},
			&"heap_02_camp": {"name": "Scavenger Camp", "origin": Vector2(1280, 96), "rect": Rect2(0, -200, 1920, 560), "icons": ["town", "dock", "shop"]},
			&"heap_02b_undercamp": {"name": "The Hollow", "origin": Vector2(2640, 456), "rect": Rect2(0, 0, 800, 360), "icons": ["secret"]},
			&"heap_05_fields": {"name": "Scrap Fields", "origin": Vector2(3200, 0), "rect": Rect2(0, 0, 1600, 480), "icons": []},
			&"heap_09_giant": {"name": "Giant's Brow", "origin": Vector2(4800, 0), "rect": Rect2(0, 0, 640, 480), "icons": ["miniboss"]},
			&"heap_07_crane": {"name": "Crane Yard", "origin": Vector2(4380, -600), "rect": Rect2(0, 0, 720, 600), "icons": []},
			&"heap_08_conveyor": {"name": "Conveyor Hall", "origin": Vector2(5100, -600), "rect": Rect2(0, 0, 1280, 360), "icons": ["dock"]},
			&"heap_03_intake": {"name": "The Intake", "origin": Vector2(6380, -600), "rect": Rect2(0, 0, 640, 360), "icons": ["boss"]},
			&"heap_12_compactor": {"name": "Compactor Pit", "origin": Vector2(5300, -960), "rect": Rect2(0, 0, 640, 360), "icons": []},
			&"heap_10_sinkhole": {"name": "Sinkhole", "origin": Vector2(4000, 480), "rect": Rect2(0, 0, 400, 720), "icons": []},
			&"heap_04_seep": {"name": "Seep Tunnels", "origin": Vector2(1000, 900), "rect": Rect2(0, 0, 3000, 300), "icons": []},
			&"heap_11_tram": {"name": "Old Tram Stop", "origin": Vector2(400, 900), "rect": Rect2(0, 0, 600, 300), "icons": ["secret"]},
			&"heap_13_gate": {"name": "Underworks Gate", "origin": Vector2(3440, 496), "rect": Rect2(0, 0, 520, 360), "icons": ["exit"]},
		},
	},
	&"underworks": {
		"name": "The Underworks",
		"rooms": {
			&"uw_01_descent": {"name": "The Descent", "origin": Vector2(0, 0), "rect": Rect2(0, 0, 640, 480), "icons": ["exit"]},
			&"uw_02_market": {"name": "Pipe Market", "origin": Vector2(640, 40), "rect": Rect2(0, 0, 1600, 400), "icons": ["town", "dock", "shop"]},
			&"uw_12_tunnel": {"name": "Old Tram Tunnel", "origin": Vector2(1920, 480), "rect": Rect2(0, 0, 1280, 360), "icons": []},
			&"uw_03_row": {"name": "Bellows Row", "origin": Vector2(2240, 40), "rect": Rect2(0, 0, 1280, 400), "icons": []},
			&"uw_04_works": {"name": "Boiler Works", "origin": Vector2(3520, 0), "rect": Rect2(0, 0, 960, 480), "icons": []},
			&"uw_05_gearworks": {"name": "Gearworks", "origin": Vector2(4480, 0), "rect": Rect2(0, 0, 960, 480), "icons": ["dock"]},
			&"uw_06_gallery": {"name": "Lamplighter's Gallery", "origin": Vector2(5440, -200), "rect": Rect2(0, 0, 640, 360), "icons": ["miniboss"]},
			&"uw_07_falls": {"name": "Condensate Falls", "origin": Vector2(5440, 180), "rect": Rect2(0, 0, 640, 440), "icons": []},
			&"uw_13_cistern": {"name": "The Cistern", "origin": Vector2(4640, 540), "rect": Rect2(0, 0, 800, 400), "icons": []},
			&"uw_08_gauge": {"name": "Pressure Gauge Hall", "origin": Vector2(6080, 228), "rect": Rect2(0, 0, 1280, 400), "icons": []},
			&"uw_15_trials": {"name": "Steam Trials", "origin": Vector2(6700, -132), "rect": Rect2(0, 0, 640, 360), "icons": ["secret"]},
			&"uw_09_approach": {"name": "Governor's Approach", "origin": Vector2(7360, 228), "rect": Rect2(0, 0, 960, 400), "icons": ["dock"]},
			&"uw_10_governor": {"name": "The Pendulum", "origin": Vector2(8320, 260), "rect": Rect2(0, 0, 640, 360), "icons": ["boss"]},
			&"uw_11_galleries": {"name": "Swing Galleries", "origin": Vector2(8960, 228), "rect": Rect2(0, 0, 1280, 400), "icons": []},
			&"uw_14_loft": {"name": "Clockmaker's Loft", "origin": Vector2(10020, -132), "rect": Rect2(0, 0, 480, 360), "icons": ["secret"]},
		},
	},
}


static func region_of(room_id: StringName) -> StringName:
	for r in REGIONS:
		if REGIONS[r]["rooms"].has(room_id):
			return r
	return &""


## World-space rectangle a room covers on the region map.
static func world_rect(region: StringName, room_id: StringName) -> Rect2:
	var e: Dictionary = REGIONS[region]["rooms"][room_id]
	var r: Rect2 = e["rect"]
	return Rect2(e["origin"] + r.position, r.size)
