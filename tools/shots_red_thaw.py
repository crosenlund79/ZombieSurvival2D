#!/usr/bin/env python3
"""Rendered screenshots + runtime checks for iteration 010 (Red Thaw).
Needs a display (xvfb-run -a -s "-screen 0 1700x1000x24"). Usage:
  shots_red_thaw.py [opening] [cabin] [bunker] [settlement] [night] [hunt] [duo]
Writes JPEGs to docs/screenshots/iteration_010 (or $SHOTS_OUT) and prints
CHECK lines for what it observed (laughter heard, shadows seen, hunt, kit)."""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aftergrowth_driver import Instance, ROOT

OUT = os.environ.get("SHOTS_OUT") or os.path.join(ROOT, "docs", "screenshots", "iteration_010")
os.makedirs(OUT, exist_ok=True)
only = sys.argv[1:]
CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, bool(ok), detail))
    print(("CHECK PASS " if ok else "CHECK FAIL ") + name + (f" — {detail}" if detail else ""), flush=True)


def shot(i, name, settle=0.8):
    i.cmd(f"wait {settle}")
    png = f"{OUT}/{name}.png"
    i.cmd(f"screenshot {png}")
    try:
        from PIL import Image
        Image.open(png).convert("RGB").save(png[:-4] + ".jpg", quality=88)
        os.remove(png)
    except Exception as e:
        print("jpeg conversion failed", e)


def me(s):
    st = s.state()
    return next(p for p in st["players"] if p["id"] == st["local_player_id"]), st


def to_settlement(s):
    s.cmd("dev teleport 2300 1400"); s.cmd("walk_to 2350 1400 8"); s.cmd("interact homestead.road_east"); s.cmd("wait 1.5")


def new_world(name, seed, menu_shot=None):
    s = Instance(name, headless=False); s.wipe(); s.start()
    s.cmd("window 1600 900")
    if menu_shot:
        shot(s, menu_shot, 1.0)
    s.cmd(f"single new {seed} Wanderer"); s.cmd("tips off")
    return s


def opening():
    s = new_world("rt_open", 101, "r00_main_menu")
    try:
        p, st = me(s)
        check("new game starts by the burned shed", p["region"] == "homestead" and abs(p["x"] - 420) < 120 and abs(p["y"] - 1130) < 80,
              f"({p['x']:.0f}, {p['y']:.0f})")
        check("no zombies / Burnt Ones roam a new world", len(st.get("zombie_rows", [])) == 0 and not st.get("ambient", True))
        s.cmd("zoom 1.15")
        shot(s, "r01_opening_burned_shed", 1.2)
        s.cmd("interact homestead.starter_bag"); s.cmd("wait 0.8")
        p, st = me(s)
        check("starter bag gives water, crackers and a map", p["carried"].get("water_bottle") == 1 and p["carried"].get("crackers") == 1
              and "field_map" in p["gear"], f"{p['carried']} {p['gear']}")
        s.cmd("panel inventory on"); shot(s, "r02_starter_bag_inventory", 0.6); s.cmd("panel inventory off")
        s.cmd("interact homestead.starter_bag"); s.cmd("wait 0.6")
        p, _ = me(s)
        check("the bag cannot be emptied twice", p["carried"].get("water_bottle") == 1)
        s.cmd("dev thirst 30"); s.cmd("dev hunger 30")
        s.cmd("press_key drink"); s.cmd("wait 0.4"); s.cmd("eat"); s.cmd("wait 0.5")
        p, _ = me(s)
        check("water and crackers are consumed by the survival systems", p["hydration"] > 90 and p["hunger"] > 50 and not p["carried"].get("water_bottle"),
              f"water {p['hydration']:.0f} food {p['hunger']:.0f}")
        s.cmd("ui map on"); shot(s, "r03_field_map", 0.6); s.cmd("ui map off")
        s.cmd("walk_to 1150 960"); s.cmd("wait 0.3")
        p, _ = me(s)
        check("the cabin gate is reachable on foot from the shed", abs(p["x"] - 1150) < 30 and abs(p["y"] - 960) < 30, f"({p['x']:.0f}, {p['y']:.0f})")
        s.cmd("zoom 0.55"); shot(s, "r04_frozen_pine_woods", 1.0)
    finally:
        s.quit()


def cabin():
    s = new_world("rt_cabin", 102)
    try:
        s.cmd("walk_to 1150 960")
        if not s.state()["entities"]["homestead.yard_gate"]["state"]["open"]:
            s.cmd("press_interact")
        s.cmd("walk_to 1160 760"); s.cmd("zoom 1.0")
        shot(s, "r05_hunters_cabin", 1.0)
        s.cmd("walk_to 1160 690")
        if not s.state()["entities"]["homestead.farmhouse_door"]["state"]["open"]:
            s.cmd("interact homestead.farmhouse_door")
        s.cmd("walk_to 1160 664 4"); s.cmd("interact homestead.farmhouse_entry"); s.cmd("wait 1.0")
        p, _ = me(s)
        check("the cabin interior is entered through the door", p["region"] == "homestead.farmhouse", p["region"])
        shot(s, "r06_cabin_interior", 1.0)
    finally:
        s.quit()


def bunker():
    s = Instance("rt_bunker", headless=False); s.wipe(); s.start()
    try:
        s.cmd("window 1600 900"); s.cmd("devworld Tester"); s.cmd("tips off")
        s.cmd("walk_to 1150 960")
        if not s.state()["entities"]["homestead.yard_gate"]["state"]["open"]:
            s.cmd("press_interact")
        s.cmd("walk_to 1160 760"); s.cmd("walk_to 1160 690")
        if not s.state()["entities"]["homestead.farmhouse_door"]["state"]["open"]:
            s.cmd("interact homestead.farmhouse_door")
        s.cmd("walk_to 1160 664 4"); s.cmd("interact homestead.farmhouse_entry")
        s.cmd("walk_to 300 452 4"); s.cmd("interact homestead.farmhouse.hatch_ladder"); s.cmd("wait 1.0")
        p, _ = me(s)
        check("the bunker beneath the cabin is reachable by ladder", p["region"].startswith("bunker"), p["region"])
        s.cmd("walk_to 600 520"); s.cmd("zoom 0.85")
        shot(s, "r07_bunker_beneath_cabin", 1.0)
    finally:
        s.quit()


def settlement():
    s = new_world("rt_settle", 103)
    try:
        to_settlement(s)
        p, _ = me(s)
        check("the road east leads to the abandoned settlement", p["region"] == "service_station", p["region"])
        s.cmd("dev teleport 1250 880"); s.cmd("zoom 0.65")
        shot(s, "r08_abandoned_settlement_day", 1.2)
        # daytime laughter: stay near the houses and listen (positional sound, never shown)
        t0 = time.time()
        heard = []
        spots = [(1250, 880), (1700, 900), (600, 700)]
        k = 0
        while time.time() - t0 < 200 and len(heard) < 2:
            s.cmd(f"dev teleport {spots[k % 3][0]} {spots[k % 3][1]}"); k += 1
            s.cmd("wait 12")
            heard = [o for o in s.state().get("omens", []) if o["kind"] == "laugh"]
        check("laughter is heard near settlement buildings by day (positional, intermittent)", len(heard) >= 1,
              "; ".join(f"{o['sound']} @{o['spot']} {o['distance']}px" for o in heard))
        st = s.state()
        check("no source is ever shown (no Burnt One spawned by the laughter)", len(st.get("zombie_rows", [])) == 0)
        # the frightened survivor
        s.cmd("dev teleport 372 664"); s.cmd("zoom 1.4"); s.cmd("wait 0.5")
        s.cmd("press_interact"); s.cmd("wait 0.8")
        shot(s, "r09_frightened_survivor", 0.2)
        s.cmd("ui map on"); shot(s, "r12_field_map_two_regions", 0.6); s.cmd("ui map off")
    finally:
        s.quit()


def night():
    s = new_world("rt_night", 104)
    try:
        to_settlement(s)
        s.cmd("dev time 22"); s.cmd("dev teleport 1200 880"); s.cmd("zoom 0.6"); s.cmd("wait 2")
        shot(s, "r10_settlement_night", 0.5)
        t0 = time.time()
        seen = None
        while time.time() - t0 < 420 and seen is None:
            s.cmd("wait 1.5")
            sh = [o for o in s.state().get("omens", []) if o["kind"] == "shadow"]
            if sh:
                seen = sh[-1]
                mx = (seen["from"][0] + seen["to"][0]) / 2
                my = (seen["from"][1] + seen["to"][1]) / 2
                s.cmd(f"dev teleport {mx:.0f} {my + 330:.0f}"); s.cmd("zoom 0.9")
                shot(s, "r11_night_silhouette", 0.9)
        check("a brief human silhouette is seen at night", seen is not None, str(seen))
        st = s.state()
        check("the silhouette is not an encounter (no Burnt One spawned)", len(st.get("zombie_rows", [])) == 0)
    finally:
        s.quit()


def hunt():
    s = new_world("rt_hunt", 105)
    try:
        s.cmd("dev teleport 1150 1060"); s.cmd("zoom 0.8")
        s.cmd("dev hunt"); s.cmd("wait 0.5")
        st = s.state()
        rows = [z for z in st.get("zombie_rows", []) if z["hunter"]]
        check("developer hunt spawns one hunting Burnt One out of sight", len(rows) == 1, str(st.get("hunts")))
        hp0 = me(s)[0]["health"]
        t0 = time.time()
        shot_done = False
        while time.time() - t0 < 30:
            s.cmd("wait 1")
            st = s.state()
            z = [z for z in st["zombie_rows"] if z["hunter"]]
            if z and not shot_done:
                p = me(s)[0]
                if ((z[0]["x"] - p["x"]) ** 2 + (z[0]["y"] - p["y"]) ** 2) ** 0.5 < 260:
                    shot(s, "r13_burnt_one_hunting", 0.1)
                    shot_done = True
            if me(s)[0]["health"] < hp0:
                break
        check("the Burnt One pursues and attacks", me(s)[0]["health"] < hp0, f"health {me(s)[0]['health']:.0f}")
        # fight back with bare hands; record the hunter's health as the host sees it
        lowest = 100.0
        for i in range(8):
            st = s.state()
            z = [z for z in st["zombie_rows"] if z["hunter"] or z["ai"] == "DEAD"]
            if z:
                lowest = min(lowest, min(q["hp"] for q in z))
            live = [q for q in z if q["ai"] != "DEAD"]
            if not live or me(s)[0]["dead"]:
                break
            s.cmd(f"walk_to {live[0]['x']:.0f} {live[0]['y']:.0f} 45"); s.cmd("attack_nearest 3")
        st = s.state()
        for q in st["zombie_rows"]:
            lowest = min(lowest, q["hp"])
        check("combat works against it (host applies the player's hits)", lowest < 100, f"lowest health seen {lowest:.0f}")
        # protected boundary: start a new hunt, retreat into the cabin
        s.cmd("dev heal"); s.cmd("wait 6")
        s.cmd("dev teleport 1150 1060"); s.cmd("dev hunt"); s.cmd("wait 0.3")
        s.cmd("walk_to 1150 960")
        if not s.state()["entities"]["homestead.yard_gate"]["state"]["open"]:
            s.cmd("press_interact")
        s.cmd("walk_to 1160 760"); s.cmd("walk_to 1160 690")
        if not s.state()["entities"]["homestead.farmhouse_door"]["state"]["open"]:
            s.cmd("interact homestead.farmhouse_door")
        s.cmd("walk_to 1160 664 4"); s.cmd("interact homestead.farmhouse_entry"); s.cmd("wait 6")
        st = s.state()
        p = me(s)[0]
        check("inside the cabin the hunter never follows", p["region"] == "homestead.farmhouse"
              and all(z["region"] == "homestead" for z in st["zombie_rows"]), p["region"])
        s.cmd("dev hunt"); s.cmd("wait 0.3")
        # save, quit, reload: hunters are transient, the kit claim persists
        s.cmd("save"); s.cmd("wait 1")
        s.cmd("leave"); s.cmd("wait 1")
        s.cmd("single last Wanderer"); s.cmd("wait 2")
        st = s.state()
        check("after save + reload no hunter is restored and the player is still in the cabin",
              not any(z["hunter"] for z in st.get("zombie_rows", [])) and me(s)[0]["region"] == "homestead.farmhouse",
              me(s)[0]["region"])
    finally:
        s.quit()


def duo():
    h = Instance("rt_host", headless=False); c = Instance("rt_client", headless=False)
    for i in (h, c):
        i.wipe()
    try:
        h.start(); c.start()
        for i in (h, c):
            i.cmd("window 1100 650")
        h.cmd("host 47931 new 111 Hosty"); h.cmd("tips off")
        h.cmd("interact homestead.starter_bag")
        c.cmd("join 127.0.0.1 47931 Cleo"); c.cmd("tips off"); c.cmd("wait 1.5")
        c.cmd("interact homestead.starter_bag"); c.cmd("wait 1")
        hs, cs = h.state(), c.state()
        hp = next(p for p in hs["players"] if p["id"] == hs["local_player_id"])
        cp = next(p for p in hs["players"] if p["id"] == cs["local_player_id"])
        check("both players got exactly one personal kit (host view)", hp["carried"].get("crackers") == 1 and cp["carried"].get("crackers") == 1)
        c.cmd("interact homestead.starter_bag"); c.cmd("wait 1")
        hs = h.state()
        cp = next(p for p in hs["players"] if p["id"] == cs["local_player_id"])
        check("the client cannot take a second kit", cp["carried"].get("crackers") == 1)
        to_settlement(c)
        h.cmd("walk_to 1150 960"); h.cmd("zoom 0.8")
        c.cmd("walk_to 900 860"); c.cmd("zoom 0.7"); h.cmd("wait 2")
        shot(h, "r14_mp_host_at_cabin_woods", 0.5)
        shot(c, "r15_mp_client_in_settlement", 0.3)
        c.cmd("ui map on"); shot(c, "r16_mp_client_map", 0.5); c.cmd("ui map off")
    finally:
        for i in (h, c):
            i.quit()


for name, fn in (("opening", opening), ("cabin", cabin), ("bunker", bunker), ("settlement", settlement),
                 ("night", night), ("hunt", hunt), ("duo", duo)):
    if not only or name in only:
        print("==", name, flush=True)
        try:
            fn()
        except Exception as e:
            check(f"{name}: ran without harness error", False, repr(e))
failed = [c for c in CHECKS if not c[1]]
print(f"\n{len(CHECKS) - len(failed)}/{len(CHECKS)} runtime checks passed")
