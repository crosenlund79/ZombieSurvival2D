"""Iteration 015: the world's geography — where every outdoor region sits.

One world coordinate system (px). A region's "map.offset" is its top-left corner
in it; regions whose rectangles touch are connected along the shared edge
(WorldGeo, in game). The main east-west road runs at world y = 1395 from the
Pine Woods to Port Halden; the Greyhollow pass climbs north from Corran Junction.

  Pine Woods ─ Service station ─ Birchwater Road ─ Ashgrove ─ Corran Forest ─ Corran Junction
                                                                                     │
                                                                   Greyhollow Pass (north) ─ Greyhollow
  Corran Junction ─ Stillwater Road ─ Stillwater ─ Halden Coast ─ Port Halden

Drive times at the station wagon's top speed (430 px/s), along the roads:
Ashgrove → Junction ≈ 40 s, Junction → Greyhollow ≈ 35 s, Junction → Stillwater
≈ 35 s, Stillwater → Port Halden ≈ 35 s, the cabin → Port Halden ≈ 3½ min.
"""
ROAD_Y = 1395

# region id -> (offset x, offset y, width, height)
REGIONS = {
    "homestead": (0, 0, 2400, 1700),
    "service_station": (2400, 685, 2200, 1400),
    "wild.birchwater": (4600, -1100, 8000, 5000),
    "town": (12600, 385, 3200, 2000),
    "wild.corran_forest": (15800, -1900, 14000, 6600),
    "junction": (29800, 295, 3200, 2200),
    "wild.greyhollow_pass": (29800, -11705, 4000, 12000),
    "greyhollow": (30000, -13905, 3000, 2200),
    "wild.stillwater_road": (33000, 295, 12000, 6000),
    "stillwater": (45000, 195, 3600, 2400),
    "wild.halden_coast": (48600, -1500, 12000, 6000),
    "harbor": (60600, 495, 3600, 2600),
}


def offset(rid):
    x, y, _w, _h = REGIONS[rid]
    return [x, y]


def local(rid, wx, wy):
    """A world point in a region's local coordinates."""
    x, y, _w, _h = REGIONS[rid]
    return (wx - x, wy - y)


def check():
    """No two regions overlap (touching edges are connections)."""
    items = list(REGIONS.items())
    for i, (a, (ax, ay, aw, ah)) in enumerate(items):
        for b, (bx, by, bw, bh) in items[i + 1:]:
            if ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah:
                raise SystemExit(f"regions overlap: {a} and {b}")
    return True
