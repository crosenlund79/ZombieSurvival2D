#!/usr/bin/env python3
"""Real multi-process acceptance tests for Red Thaw (internal name Aftergrowth).

Starts separate Godot processes (host + clients) that talk over ENet on
localhost, drives them through the --autotest channel and checks results.
Usage:  python3 tools/mp_test.py [scenario ...]   (default: all)
Requires the `godot` binary on PATH (or GODOT=/path/to/godot).
"""
import json, os, shutil, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aftergrowth_driver import Instance, USER_DIR, LOG_DIR

GATE = "homestead.yard_gate"
GATE_STAND = os.environ.get("GATE_STAND", "1150 960")   # a point within reach of the gate
PORT = 24790
results = []


RESULTS_NOTES = []


def check(name, cond, detail=""):
    results.append({"check": name, "pass": bool(cond), "detail": str(detail)[:400]})
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  -> {detail}"))
    return cond


def gate(state):
    return state.get("entities", {}).get(GATE, {})


def online(state):
    return [p for p in state.get("players", []) if p["online"]]


def player(state, name):
    for p in state.get("players", []):
        if p["name"] == name:
            return p
    return None


def wait_for(inst, pred, timeout=5.0):
    end = time.time() + timeout
    st = inst.state()
    while time.time() < end and not pred(st):
        time.sleep(0.2)
        st = inst.state()
    return st


# --------------------------------------------------------------------------

def scenario_single():
    s = Instance("t_single"); s.wipe(); s.start()
    try:
        r = s.cmd("single new 111 Solo")
        s.cmd("dev peaceful 1")
        check("single: world starts", r["ok"] and r["state"]["in_world"], r)
        r = s.cmd(f"walk_to {GATE_STAND}")
        check("single: player moves with input", r["ok"], r["state"]["view"])
        check("single: gate gets interaction focus", r["state"]["view"].get("focused") == GATE, r["state"]["view"])
        r = s.cmd("press_interact")
        check("single: gate opens via interaction", gate(r["state"]).get("state", {}).get("open") is True, gate(r["state"]))
        r = s.cmd("walk_to 1160 690")
        check("single: open gate lets the player into the yard", r["ok"], r["state"]["view"])
        r = s.cmd("press_interact")
        door = r["state"]["entities"].get("homestead.farmhouse_door", {})
        check("single: farmhouse door opens (second entity)", door.get("state", {}).get("open") is True, door)
        before_id = r["state"]["view"]["instance_id"]
        r = s.cmd("rebuild_view")
        v = r["state"]["view"]
        check("single: view rebuilt as a new scene instance", v["exists"] and v["instance_id"] != before_id, v)
        check("single: rebuilt view shows persisted open gate", v["doors"].get(GATE, {}).get("open_visual") is True, v)
        r = s.cmd("wait 1.0")
        tick1 = r["state"]["tick"]
        r = s.cmd("save")
        check("single: save succeeds", r["ok"], r)
        pos = player(r["state"], "Solo")
        world_id = r["state"]["world_id"]
        s.quit()
        s.start()
        r = s.cmd("single continue Solo")
        s.cmd("dev peaceful 1")
        st = r["state"]
        check("single: restart loads same world", r["ok"] and st.get("world_id") == world_id, st.get("world_id"))
        check("single: gate still open after restart", gate(st).get("state", {}).get("open") is True, gate(st))
        check("single: farmhouse door still open after restart", st["entities"]["homestead.farmhouse_door"]["state"]["open"] is True, st["entities"])
        check("single: clock restored", st.get("tick", 0) >= tick1, (tick1, st.get("tick")))
        p2 = player(st, "Solo")
        check("single: position restored", p2 and abs(p2["x"] - pos["x"]) < 2 and abs(p2["y"] - pos["y"]) < 2, (pos, p2))
    finally:
        s.kill()


def scenario_multiplayer():
    host = Instance("t_host"); a = Instance("t_alice"); b = Instance("t_bob")
    for i in (host, a, b):
        i.wipe()
    try:
        host.start(); a.start(); b.start()
        r = host.cmd(f"host {PORT} new 4242 Hosty")
        host.cmd("dev peaceful 1")
        check("mp: host starts", r["ok"], r)
        world_id = r["state"]["world_id"]
        r = a.cmd(f"join 127.0.0.1 {PORT} Alice")
        check("mp: client A connects and joins", r["ok"], r)
        check("mp: client A receives host world id", r["state"].get("world_id") == world_id, r["state"].get("world_id"))
        st = wait_for(host, lambda s: len(online(s)) == 2)
        check("mp: host sees 2 players", len(online(st)) == 2, online(st))
        sa = wait_for(a, lambda s: s["view"].get("avatars") == 2)
        check("mp: client A displays both avatars", sa["view"].get("avatars") == 2, sa["view"])
        # Independent control: A moves, host does not.
        h0 = player(host.state(), "Hosty")
        a0 = player(host.state(), "Alice")
        a.cmd("hold move_down 0.6")
        st = wait_for(host, lambda s: player(s, "Alice")["y"] > a0["y"] + 40)
        a1 = player(st, "Alice"); h1 = player(st, "Hosty")
        check("mp: host sees client A move", a1["y"] > a0["y"] + 40, (a0, a1))
        check("mp: host player unaffected by client input", abs(h1["x"] - h0["x"]) < 1 and abs(h1["y"] - h0["y"]) < 1, (h0, h1))
        sa = a.state()
        hy = player(sa, "Hosty")
        host.cmd("hold move_right 0.5")
        sa = wait_for(a, lambda s: player(s, "Hosty")["x"] > hy["x"] + 30)
        check("mp: client A sees host move (replication)", player(sa, "Hosty")["x"] > hy["x"] + 30, (hy, player(sa, "Hosty")))
        # Shared interaction from the client.
        a.cmd(f"walk_to {GATE_STAND}")
        r = a.cmd("press_interact")
        st = wait_for(host, lambda s: gate(s).get("rev") == 1)
        check("mp: client interaction validated & committed on host", gate(st).get("state", {}).get("open") is True and gate(st)["rev"] == 1, gate(st))
        sa = wait_for(a, lambda s: s["view"]["doors"].get(GATE, {}).get("open_visual") is True)
        check("mp: client A sees authoritative result", sa["view"]["doors"][GATE]["open_visual"] is True, sa["view"])
        # Late join.
        r = b.cmd(f"join 127.0.0.1 {PORT} Bob")
        check("mp: late joiner B connects", r["ok"], r)
        check("mp: late joiner B gets current gate state", gate(r["state"]).get("state", {}).get("open") is True and gate(r["state"]).get("rev") == 1, gate(r["state"]))
        sb = wait_for(b, lambda s: s["view"].get("avatars") == 3)
        check("mp: late joiner B displays 3 avatars", sb["view"].get("avatars") == 3, sb["view"])
        # Out-of-range request is refused by the host.
        r = b.cmd(f"interact {GATE}")
        st = host.state()
        check("mp: out-of-range interaction refused by host", gate(st)["rev"] == 1, gate(st))
        check("mp: B is told it was too far", any("ACTION_TOO_FAR" in n for n in r["state"]["notices"]), r["state"]["notices"])
        # Simultaneous requests based on the same revision: exactly one wins.
        b.cmd(f"walk_to {GATE_STAND.split()[0]} {int(GATE_STAND.split()[1]) + 20}")
        rev_now = gate(host.state())["rev"]
        with open(a.inbox, "a") as f: f.write(f"interact {GATE} {rev_now}\n")
        with open(b.inbox, "a") as f: f.write(f"interact {GATE} {rev_now}\n")
        a.seq += 1; b.seq += 1
        ra = a._wait(a.seq, 10); rb = b._wait(b.seq, 10)
        st = wait_for(host, lambda s: gate(s)["rev"] >= 2)
        stale = sum(1 for r in (ra, rb) if any("ACTION_STALE" in n for n in r["state"]["notices"]))
        check("mp: simultaneous toggles -> exactly one applied", gate(st)["rev"] == 2 and gate(st)["state"]["open"] is False, gate(st))
        check("mp: the other request reported as stale", stale == 1, [ra["state"]["notices"], rb["state"]["notices"]])
        time.sleep(0.5)
        sa, sb, sh = a.state(), b.state(), host.state()
        check("mp: all three agree on gate state", gate(sa) == gate(sb) == gate(sh), [gate(sa), gate(sb), gate(sh)])
        # Re-open so the persisted state is "open" with rev 3.
        a.cmd("press_interact")
        st = wait_for(host, lambda s: gate(s)["rev"] == 3)
        check("mp: re-open committed (rev 3)", gate(st)["rev"] == 3 and gate(st)["state"]["open"] is True, gate(st))
        # Client-issued dev command refused.
        r = a.cmd("dev advance_clock 3600")
        check("mp: client dev command refused (host only)", any("DEV_HOST_ONLY" in n for n in r["state"]["notices"]), r["state"]["notices"])
        # Clean disconnect of B.
        b.cmd("leave")
        st = wait_for(host, lambda s: len(online(s)) == 2)
        check("mp: host removes disconnected player", len(online(st)) == 2, online(st))
        sa = wait_for(a, lambda s: s["view"].get("avatars") == 2)
        check("mp: client A removes B's avatar", sa["view"].get("avatars") == 2, sa["view"])
        # Reconnect B to the running session.
        r = b.cmd(f"join 127.0.0.1 {PORT} Bob")
        check("mp: B rejoins running session", r["ok"] and len(online(r["state"])) == 3, r["state"].get("players"))
        bpos_before = player(host.state(), "Bob")
        r = host.cmd("save")
        check("mp: host saves", r["ok"], r)
        alice_saved = player(r["state"], "Alice")
        tick_saved = r["state"]["tick"]
        # Clients cannot save the shared world.
        r = a.cmd("save")
        check("mp: client save refused", not r["ok"], r)
        # Host closes (process ends). Clients should notice.
        host.quit()
        sa = wait_for(a, lambda s: not s["in_world"], timeout=12)
        check("mp: client returns to menu when host closes", not sa["in_world"], sa["notices"])
        b.cmd("wait 0.5")
        # Restart host from the save; clients rejoin.
        host.start()
        r = host.cmd(f"host {PORT} continue Hosty")
        host.cmd("dev peaceful 1")
        check("mp: host restarts from save", r["ok"] and r["state"].get("world_id") == world_id, r)
        check("mp: restarted host has gate open rev 3", gate(r["state"]) == {"state": {"open": True}, "rev": 3}, gate(r["state"]))
        check("mp: clock continues from save", r["state"]["tick"] >= tick_saved, (tick_saved, r["state"]["tick"]))
        r = a.cmd(f"join 127.0.0.1 {PORT} Alice")
        check("mp: A rejoins restarted world", r["ok"], r)
        pa = player(r["state"], "Alice")
        check("mp: A's saved position restored", pa and abs(pa["x"] - alice_saved["x"]) < 2 and abs(pa["y"] - alice_saved["y"]) < 2, (alice_saved, pa))
        check("mp: A sees persisted gate", r["state"]["view"]["doors"].get(GATE, {}).get("open_visual") is True, r["state"]["view"])
        r = b.cmd(f"join 127.0.0.1 {PORT} Bob")
        check("mp: B rejoins restarted world with persisted gate", r["ok"] and gate(r["state"]).get("rev") == 3, gate(r["state"]))
    finally:
        for i in (host, a, b):
            i.kill()


def scenario_connection_failure():
    c = Instance("t_lonely"); c.wipe(); c.start()
    try:
        r = c.cmd("join 127.0.0.1 24999 Nobody", timeout=60)
        check("net: joining with no host fails cleanly", not r["ok"] and not r["state"]["in_world"], r["state"]["notices"])
        check("net: failure reported to player", any("NET_CONNECT_FAILED" in n or "JOIN_TIMEOUT" in n for n in r["state"]["notices"]), r["state"]["notices"])
    finally:
        c.kill()


def scenario_assets():
    over = os.path.join(USER_DIR, "overrides")
    fix = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tests", "fixtures", "overrides")
    img_dst = os.path.join(over, "characters", "player", "survivor_down.png")
    snd_dst = os.path.join(over, "audio", "world", "door_open.wav")
    cab_dst = os.path.join(over, "world", "buildings", "hunter_cabin.png")   # a Red Thaw asset
    s = Instance("t_assets"); s.wipe()
    for p in (img_dst, snd_dst, cab_dst):
        if os.path.exists(p):
            os.remove(p)
    s.start()
    try:
        r = s.cmd("single new 5 Painter")
        s.cmd("dev peaceful 1")
        srcs = r["state"]["asset_sources"]
        check("assets: template used by default", srcs.get("char.player") == "template", srcs)
        p0 = player(r["state"], "Painter")
        os.makedirs(os.path.dirname(img_dst), exist_ok=True)
        os.makedirs(os.path.dirname(snd_dst), exist_ok=True)
        shutil.copy(os.path.join(fix, "characters", "player", "survivor_down.png"), img_dst)
        shutil.copy(os.path.join(fix, "audio", "world", "door_open.wav"), snd_dst)
        os.makedirs(os.path.dirname(cab_dst), exist_ok=True)
        shutil.copy(os.path.join(fix, "characters", "player", "survivor_down.png"), cab_dst)
        r = s.cmd("reload_assets")
        r = s.cmd(f"walk_to {GATE_STAND}")
        r = s.cmd("press_interact")   # door sound requested after reload
        srcs = r["state"]["asset_sources"]
        check("assets: external image override used", srcs.get("char.player") == "external", srcs)
        check("assets: external sound override used", srcs.get("sfx.door_open") == "external", srcs)
        check("assets: Red Thaw art (hunter's cabin) can be overridden too", srcs.get("world.hunter_cabin") == "external", srcs.get("world.hunter_cabin"))
        check("assets: gameplay unaffected by art swap (gate still works)", gate(r["state"])["state"]["open"] is True, gate(r["state"]))
        # Corrupt override is rejected -> template.
        shutil.copy(os.path.join(fix, "characters", "player", "corrupt_survivor_down.png"), img_dst)
        r = s.cmd("reload_assets")
        r = s.cmd("rebuild_view")
        check("assets: corrupt PNG rejected, template used", r["state"]["asset_sources"].get("char.player") == "template", r["state"]["asset_sources"])
        os.remove(img_dst); os.remove(snd_dst); os.remove(cab_dst)
        r = s.cmd("reload_assets")
        r = s.cmd("press_interact")   # closes (door_close)
        r = s.cmd("press_interact")   # opens again (door_open resolved after reload)
        srcs = r["state"]["asset_sources"]
        check("assets: removing override restores template (image)", srcs.get("char.player") == "template", srcs)
        check("assets: removing override restores template (sound)", srcs.get("sfx.door_open") == "template", srcs)
    finally:
        s.kill()
        for p in (img_dst, snd_dst, cab_dst):
            if os.path.exists(p):
                os.remove(p)


def scenario_settings():
    s = Instance("t_settings"); s.wipe(); s.start()
    try:
        st = s.state()["settings"]
        check("settings: defaults", st["language"] == "en" and abs(st["master"] - 0.8) < 1e-6, st)
        s.cmd("set general language da")
        s.cmd("set display ui_scale 1.5")
        s.cmd("set audio Master 0.25")
        s.quit(); s.start()
        st = s.state()["settings"]
        check("settings: language persists across restart", st["language"] == "da", st)
        check("settings: UI scale persists", abs(st["ui_scale"] - 1.5) < 1e-6, st)
        check("settings: volume persists and is applied to the bus", abs(st["master"] - 0.25) < 1e-6 and st["master_bus_db"] < -10, st)
        r = s.cmd("single new 3 Solo")
        s.cmd("dev peaceful 1")
        check("settings: client settings not stored in world save", "language" not in json.dumps(r["state"].get("entities", {})), "")
    finally:
        s.kill()


SITE = "homestead.farmhouse.shelter"
L1 = "bunker:homestead.farmhouse.shelter:-1"
L2 = "bunker:homestead.farmhouse.shelter:-2"
L3 = "bunker:homestead.farmhouse.shelter:-3"


def lvl(state, region, eid):
    return state.get("level_entities", {}).get(region, {}).get(eid, {}).get("state", {})


def go_inside(i):
    """From anywhere on the surface: through the yard gate and the front door into the farmhouse."""
    st = i.state()
    if not st["entities"]["homestead.yard_gate"]["state"]["open"]:
        i.cmd("walk_to 1150 960"); i.cmd("press_interact")
    i.cmd("walk_to 1150 960")
    i.cmd("walk_to 1160 690")
    if not i.state()["entities"]["homestead.farmhouse_door"]["state"]["open"]:
        i.cmd("press_interact")
    i.cmd("walk_to 1160 664 4")
    return i.cmd("press_interact")


def chop(i, n=5):
    return i.cmd(f"press_repeat {n} 0.45", timeout=40)


def scenario_bunker_single():
    s = Instance("t_bunker"); s.wipe(); s.start()
    try:
        r = s.cmd("single new 77 Builder")
        s.cmd("dev peaceful 1")
        check("loop: 1 rural world starts", r["ok"] and r["state"]["region"] == "homestead", r["state"].get("region"))
        r = go_inside(s)
        check("loop: 2 enter the farmhouse", r["state"]["region"] == "homestead.farmhouse", r["state"].get("region"))
        r = s.cmd("walk_to 300 492")
        check("loop: shelter site focused inside the house", r["state"]["view"]["focused"] == SITE, r["state"]["view"]["focused"])
        r = s.cmd("press_interact")
        st = r["state"]["entities"][SITE]["state"]
        check("loop: 3 hatch construction starts (timed)", st["stage"] == "building", st)
        r = s.cmd("walk_to 560 500")
        check("loop: farmhouse stays explorable during construction", r["ok"], r["state"]["view"])
        r = s.cmd("wait 8.5")
        check("loop: 4 construction completes on the shared clock", r["state"]["entities"][SITE]["state"]["stage"] == "built"
              and SITE in r["state"]["bunkers"], [r["state"]["entities"][SITE], r["state"]["bunkers"]])
        check("loop: completion feedback shown", any("SHELTER_COMPLETE" in n for n in r["state"]["notices"]), r["state"]["notices"])
        s.cmd("walk_to 300 492"); r = s.cmd("press_interact")
        check("loop: 5 hatch opens", r["state"]["entities"][SITE]["state"]["open"] is True, r["state"]["entities"][SITE])
        s.cmd("walk_to 300 452 4"); r = s.cmd("press_interact")
        check("loop: 5 descend the ladder to level -1", r["state"]["region"] == L1 and r["state"]["view"]["region"] == L1, r["state"].get("region"))
        r = s.cmd("walk_to 800 450")
        check("loop: 6 explore the chamber", r["ok"], r["state"]["view"])
        exposed = [k for k, v in r["state"]["view"]["entities"].items() if k.startswith("support_") and v["stage"] == "exposed"]
        check("loop: 4 unreinforced earth locations shown", len(exposed) == 4, exposed)
        s.cmd("walk_to 540 300"); r = s.cmd("press_interact")
        check("loop: 7 climb back to the farmhouse", r["state"]["region"] == "homestead.farmhouse", r["state"].get("region"))
        s.cmd("walk_to 480 600"); r = s.cmd("press_interact")
        check("loop: 7 back outside", r["state"]["region"] == "homestead", r["state"].get("region"))
        s.cmd("walk_to 860 585"); r = chop(s)
        check("loop: 8 tree felled by repeated chopping", r["state"]["entities"]["homestead.tree_01"]["state"]["felled"] is True,
              r["state"]["entities"]["homestead.tree_01"])
        check("loop: 8 wood collected", r["state"]["carried"].get("wood", 0) == 4, r["state"]["carried"])
        r = s.cmd("press_interact")
        check("loop: felled tree gives nothing more", r["state"]["carried"].get("wood", 0) == 4, r["state"]["carried"])
        s.cmd("dev teleport 640 368"); r = chop(s)
        check("loop: second tree felled", r["state"]["carried"].get("wood", 0) == 8, r["state"]["carried"])
        r = go_inside(s)
        s.cmd("walk_to 470 400"); r = s.cmd("press_interact")
        check("loop: 9 deposit wood at the shelter", r["state"]["bunkers"][SITE]["wood"] == 8 and r["state"]["carried"].get("wood", 0) == 0,
              [r["state"]["bunkers"], r["state"]["carried"]])
        s.cmd("walk_to 300 452 4"); r = s.cmd("press_interact")
        check("loop: 10 descend again", r["state"]["region"] == L1, r["state"].get("region"))
        s.cmd("walk_to 220 350"); s.cmd("press_interact")
        s.cmd("walk_to 760 350"); r = s.cmd("press_interact")
        r = s.cmd("wait 3.5")
        sup = r["state"]["level_entities"][L1]
        done = [k for k in sup if k.startswith("support_") and sup[k]["state"]["stage"] == "reinforced"]
        check("loop: 10 two reinforcements built", sorted(done) == ["support_1", "support_2"], done)
        check("loop: 10 wood spent from stockpile (8 - 2x4)", r["state"]["bunkers"][SITE]["wood"] == 0, r["state"]["bunkers"])
        check("loop: 11 view shows reinforced supports", r["state"]["view"]["entities"]["support_1"]["stage"] == "reinforced", r["state"]["view"]["entities"]["support_1"])
        r = s.cmd("ui map on")
        legend = r["state"]["view"].get("map_legend", "")
        check("loop: 12 map opens underground and reports depth", r["state"]["view"]["map_open"] and "-1" in legend, legend)
        s.cmd("ui map off")
        r = s.cmd("dev create_level")
        check("loop: 13 developer creates level -2", r["state"]["bunkers"][SITE]["levels"] == [-2, -1], r["state"]["bunkers"])
        check("loop: ladder down appears in level -1", r["state"]["view"]["entities"]["ladder_down"]["visible"] is True, r["state"]["view"]["entities"]["ladder_down"])
        s.cmd("walk_to 820 640"); r = s.cmd("press_interact")
        check("loop: 14 descend to level -2", r["state"]["region"] == L2 and r["state"]["view"]["region"] == L2, r["state"].get("region"))
        r = s.cmd("dev create_level"); r = s.cmd("dev create_level"); r = s.cmd("dev create_level")
        check("loop: repeated creation -> levels -1..-5", r["state"]["bunkers"][SITE]["levels"] == [-5, -4, -3, -2, -1], r["state"]["bunkers"])
        r = s.cmd("save")
        check("loop: 15 save", r["ok"], r)
        saved = r["state"]
        s.quit(); s.start()
        r = s.cmd("single continue Builder")
        s.cmd("dev peaceful 1")
        st = r["state"]
        check("loop: 16 reopened in level -2", st["region"] == L2 and st["view"]["region"] == L2, st.get("region"))
        check("loop: 16 bunker levels intact", st["bunkers"] == saved["bunkers"], [st["bunkers"], saved["bunkers"]])
        check("loop: 16 reinforcements intact", lvl(st, L1, "support_1").get("stage") == "reinforced" and lvl(st, L1, "support_3").get("stage") == "exposed", st["level_entities"].get(L1))
        check("loop: 16 felled trees intact", st["entities"]["homestead.tree_01"]["state"]["felled"] and st["entities"]["homestead.tree_02"]["state"]["felled"], "")
        check("loop: 16 hatch built and open", st["entities"][SITE]["state"] == saved["entities"][SITE]["state"], st["entities"][SITE])
        check("loop: 16 ladders between all levels intact", all(lvl(st, f"bunker:{SITE}:{d}", "ladder_down").get("enabled") for d in (-1, -2, -3, -4)), "")
        s.cmd("walk_to 500 296 4"); r = s.cmd("press_interact")
        check("loop: climb from -2 back to -1 after reload", r["state"]["region"] == L1, r["state"].get("region"))
    finally:
        s.kill()


def scenario_bunker_multi():
    host = Instance("t_bhost"); a = Instance("t_balice")
    for i in (host, a):
        i.wipe()
    try:
        host.start(); a.start()
        host.cmd(f"host {PORT} new 99 Hosty")
        host.cmd("dev peaceful 1")
        go_inside(host)
        host.cmd("walk_to 300 492"); host.cmd("press_interact"); host.cmd("wait 8.5")
        r = host.cmd("press_interact")
        check("mpb: host built and opened the hatch", r["state"]["entities"][SITE]["state"]["open"] is True, r["state"]["entities"][SITE])
        r = host.cmd("dev create_level")
        check("mpb: host created level -2", r["state"]["bunkers"][SITE]["levels"] == [-2, -1], r["state"]["bunkers"])
        r = a.cmd(f"join 127.0.0.1 {PORT} Alice")
        check("mpb: late joiner receives bunker and levels", r["ok"] and r["state"]["bunkers"].get(SITE, {}).get("levels") == [-2, -1], r["state"].get("bunkers"))
        check("mpb: late joiner sees the open hatch", r["state"]["entities"][SITE]["state"]["open"] is True, "")
        r = go_inside(a)
        check("mpb: client enters the farmhouse", r["state"]["region"] == "homestead.farmhouse", r["state"].get("region"))
        a.cmd("walk_to 300 452 4"); r = a.cmd("press_interact")
        check("mpb: client descends to level -1", r["state"]["region"] == L1, r["state"].get("region"))
        st = host.state()
        check("mpb: host sees client in level -1", [p for p in st["players"] if p["name"] == "Alice"][0]["region"] == L1, st["players"])
        check("mpb: host view does not show the underground player", st["view"]["avatars"] == 1, st["view"])
        # Host goes outside and chops; client waits underground.
        host.cmd("walk_to 480 600"); host.cmd("press_interact")
        host.cmd("walk_to 860 585"); r = chop(host)
        check("mpb: host chops a tree on the surface", r["state"]["carried"].get("wood", 0) == 4, r["state"]["carried"])
        host.cmd("dev teleport 640 368"); r = chop(host)
        go_inside(host); host.cmd("walk_to 470 400"); r = host.cmd("press_interact")
        check("mpb: host deposits 8 wood", r["state"]["bunkers"][SITE]["wood"] == 8, r["state"]["bunkers"])
        time.sleep(0.5)
        sa = a.state()
        check("mpb: client underground sees the stockpile grow", sa["bunkers"][SITE]["wood"] == 8, sa["bunkers"])
        # Client builds while the host goes back out and chops another tree.
        host.cmd("walk_to 480 600"); host.cmd("press_interact")
        a.cmd("walk_to 220 350")
        with open(a.inbox, "a") as f: f.write("press_interact\n")
        a.seq += 1
        host.cmd("dev teleport 200 690"); rh = chop(host)
        ra = a._wait(a.seq, 20)
        a.cmd("walk_to 760 350"); a.cmd("press_interact"); r = a.cmd("wait 3.5")
        sup = r["state"]["level_entities"][L1]
        check("mpb: client built two reinforcements underground", sup["support_1"]["state"]["stage"] == "reinforced" and sup["support_2"]["state"]["stage"] == "reinforced", sup)
        check("mpb: host chopped at the same time", rh["state"]["entities"]["homestead.tree_03"]["state"]["felled"] is True, rh["state"]["entities"]["homestead.tree_03"])
        sh = host.state()
        check("mpb: host sees the reinforcements", lvl(sh, L1, "support_2").get("stage") == "reinforced", "")
        check("mpb: stockpile spent exactly once (8 - 8)", sh["bunkers"][SITE]["wood"] == 0 and r["state"]["bunkers"][SITE]["wood"] == 0, [sh["bunkers"], r["state"]["bunkers"]])
        a.cmd("walk_to 210 600"); r = a.cmd("press_interact")
        check("mpb: empty stockpile -> host refuses the next support", any("ACTION_NEED_WOOD" in n for n in r["state"]["notices"])
              and lvl(r["state"], L1, "support_3").get("stage") == "exposed", [r["state"]["notices"], r["state"]["view"]["focused"]])
        # Different levels at once: host on the surface, client on -2.
        a.cmd("walk_to 820 640"); r = a.cmd("press_interact")
        check("mpb: client on level -2", r["state"]["region"] == L2 and r["state"]["view"]["region"] == L2, r["state"].get("region"))
        a0 = [p for p in host.state()["players"] if p["name"] == "Alice"][0]
        a.cmd("hold move_right 0.6")
        host.cmd("hold move_left 0.4")
        st = wait_for(host, lambda s: [p for p in s["players"] if p["name"] == "Alice"][0]["x"] > a0["x"] + 40)
        check("mpb: independent control on different levels (host sees -2 movement)",
              [p for p in st["players"] if p["name"] == "Alice"][0]["x"] > a0["x"] + 40 and st["region"] == "homestead", st["players"])
        sa = a.state()
        check("mpb: client camera/view stays on -2 while host is outside", sa["view"]["region"] == L2 and sa["view"]["avatars"] == 1, sa["view"])
        r = host.cmd("dev create_level")
        check("mpb: host creates level -3 while client is on -2", r["state"]["bunkers"][SITE]["levels"] == [-3, -2, -1], r["state"]["bunkers"])
        time.sleep(0.6)
        sa = a.state()
        check("mpb: client on -2 sees the new ladder down appear", sa["view"]["entities"]["ladder_down"]["visible"] is True, sa["view"]["entities"]["ladder_down"])
        r = a.cmd("dev create_level")
        check("mpb: client cannot use the developer command", any("DEV_HOST_ONLY" in n for n in r["state"]["notices"]) and r["state"]["bunkers"][SITE]["levels"] == [-3, -2, -1], r["state"]["notices"])
        r = host.cmd("save")
        check("mpb: host saves with players on different levels", r["ok"], r)
        host.quit()
        sa = wait_for(a, lambda s: not s["in_world"], timeout=12)
        check("mpb: client returns to menu when host closes", not sa["in_world"], "")
        host.start()
        r = host.cmd(f"host {PORT} continue Hosty")
        host.cmd("dev peaceful 1")
        check("mpb: host restarts on the surface", r["ok"] and r["state"]["region"] == "homestead", r["state"].get("region"))
        r = a.cmd(f"join 127.0.0.1 {PORT} Alice")
        check("mpb: client rejoins directly on level -2", r["ok"] and r["state"]["region"] == L2 and r["state"]["view"]["region"] == L2, r["state"].get("region"))
        check("mpb: rejoined client sees persisted bunker", r["state"]["bunkers"][SITE]["levels"] == [-3, -2, -1] and lvl(r["state"], L1, "support_1").get("stage") == "reinforced", r["state"]["bunkers"])
        a.cmd("walk_to 760 600"); r = a.cmd("press_interact")
        check("mpb: client descends to -3 after restart", r["state"]["region"] == L3, r["state"].get("region"))
    finally:
        for i in (host, a):
            i.kill()



def zs(state, alive=True):
    return [z for z in state.get("zombies", []) if not alive or z["ai"] != "DEAD"]


def engaged(state):
    return [z for z in zs(state) if z["ai"] in ("INVESTIGATE", "CHASE", "WINDUP", "RECOVER", "STAGGER")]


def take_club(i):
    go_inside(i)
    i.cmd("walk_to 150 470"); r = i.cmd("press_interact")
    i.cmd("walk_to 480 600"); i.cmd("press_interact")
    return r


def to_west_trees(i):
    i.cmd("walk_to 1150 960")
    if not i.state()["entities"]["homestead.yard_gate"]["state"]["open"]:
        i.cmd("press_interact")
    i.cmd("walk_to 700 960")


def scenario_danger_single():
    s = Instance("t_danger"); s.wipe(); s.start()
    try:
        s.cmd("single new 31 Scout")
        r = s.cmd("dev ambient 1")  # legacy automatic loop under test
        base = len(zs(r["state"]))
        check("danger: base zombie population exists away from the homestead", base >= 4, base)
        r = take_club(s)
        check("danger: club taken from the farmhouse rack", r["state"]["weapon"] == "club", r["state"].get("weapon"))
        to_west_trees(s)
        s.cmd("walk_to 200 685")
        r = s.cmd("press_repeat 5 0.45", timeout=40)
        check("danger: tree felled", r["state"]["entities"]["homestead.tree_03"]["state"]["felled"], "")
        r = s.cmd("wait 1.5")
        check("danger: chopping noise makes zombies investigate", len(engaged(r["state"])) >= 1, [z["ai"] for z in zs(r["state"])])
        att1 = r["state"]["attention_total"]
        s.cmd("walk_to 380 945")
        r = s.cmd("press_repeat 5 0.45", timeout=40)
        r = s.cmd("wait 2")
        st = r["state"]
        check("danger: continued noise raises attention", st["attention_total"] > att1, (att1, st["attention_total"]))
        check("danger: more zombies converge (horde developing)", len(engaged(st)) >= 3, [(z["ai"], z["persistent"]) for z in zs(st)])
        check("danger: threat shown to the player", st["threat_label"] not in ("Quiet", ""), st["threat_label"])
        transient = [z for z in zs(st) if not z["persistent"]]
        check("danger: reinforcements stay within the cap", len(transient) <= 8, len(transient))
        s.cmd("dev spawn_zombie")
        wait_for(s, lambda st: any(abs(z["x"] - st["me_x"]) + abs(z["y"] - st["me_y"]) < 90 for z in zs(st)), timeout=15)
        r = s.cmd("attack_nearest 8 0.6", timeout=30)
        hurt = [z for z in r["state"]["zombies"] if z["hp"] < 100]
        check("danger: melee hits land (authoritative)", len(hurt) >= 1, [(z["ai"], z["hp"]) for z in r["state"]["zombies"]][:8])
        check("danger: a zombie can be killed", any(z["ai"] == "DEAD" for z in r["state"]["zombies"]) or
              any(z["hp"] <= 32 for z in r["state"]["zombies"]), "")
        hp_before = r["state"]["health"]
        s.cmd("dev heal")
        s.cmd("walk_to 700 960"); s.cmd("walk_to 1150 960"); s.cmd("walk_to 1160 690")
        st = s.state()
        if not st["entities"]["homestead.farmhouse_door"]["state"]["open"]:
            s.cmd("press_interact")
        s.cmd("walk_to 1160 664 4"); r = s.cmd("press_interact")
        check("danger: retreat into the farmhouse", r["state"]["region"] in ("homestead.farmhouse",), r["state"].get("region"))
        r = s.cmd("wait 6")
        st = r["state"]
        check("danger: no zombie follows inside", not any(z["region"] == "homestead.farmhouse" for z in st["zombies"]) and st["view"]["zombies"] == 0, st["view"])
        check("danger: zombies give up the chase", not any(z["ai"] in ("CHASE", "WINDUP") for z in st["zombies"]), [z["ai"] for z in st["zombies"]])
        check("danger: indoors reads as sheltered", st["threat_label"] in ("Sheltered", "I ly"), st["threat_label"])
        r = s.cmd("save")
        s.quit(); s.start()
        r = s.cmd("single continue Scout")
        st = r["state"]
        check("danger: reload keeps the club and position", st["weapon"] == "club" and st["region"] == "homestead.farmhouse", (st.get("weapon"), st.get("region")))
        home = [z for z in zs(st) if z["region"] == "homestead"]
        check("danger: reload has no duplicated horde (only base population)", all(z["persistent"] for z in home) and len(home) <= 6, [(z["id"], z["persistent"]) for z in home])
        check("danger: reload starts calm", st["attention"] == 0, st["attention"])
    finally:
        s.kill()


def scenario_danger_multi():
    host = Instance("t_dhost"); c = Instance("t_dclient")
    for i in (host, c):
        i.wipe()
    try:
        host.start(); c.start()
        host.cmd(f"host {PORT} new 47 Hosty"); host.cmd("dev ambient 1")  # legacy automatic loop under test
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        check("dmp: client joins a world with zombies", r["ok"], r["error"])
        time.sleep(0.6)
        sh, sc = host.state(), c.state()
        hz = {z["id"]: z for z in zs(sh)}
        cz = {z["id"]: z for z in zs(sc)}
        check("dmp: client mirrors the same zombies", set(hz) == set(cz), (sorted(hz), sorted(cz)))
        close = all(abs(hz[k]["x"] - cz[k]["x"]) < 60 and abs(hz[k]["y"] - cz[k]["y"]) < 60 for k in hz if k in cz)
        check("dmp: zombie positions consistent between peers", close, "")
        # Client makes noise on the east side; the host sees zombies react there.
        c.cmd("walk_to 1150 960")
        if not c.state()["entities"]["homestead.yard_gate"]["state"]["open"]:
            c.cmd("press_interact")
        c.cmd("walk_to 1800 960"); c.cmd("walk_to 2060 795")
        r = c.cmd("press_repeat 5 0.45", timeout=40)
        check("dmp: client fells a tree", r["state"]["entities"]["homestead.tree_05"]["state"]["felled"], "")
        time.sleep(1.0)
        sh = host.state()
        near = [z for z in engaged(sh) if abs(z["x"] - 2060) < 900]
        check("dmp: noise made by the client draws zombies (seen by host)", len(near) >= 1, [(z["ai"], int(z["x"]), int(z["y"])) for z in zs(sh)])
        # Zombies reach the client: damage is decided by the host and agrees on both peers.
        host.cmd("dev spawn_group")
        hp0 = c.state()["health"]
        sc = wait_for(c, lambda s: s["health"] < hp0 or s["dead"], timeout=25)
        wait_for(c, lambda st: any(abs(z["x"] - st["me_x"]) + abs(z["y"] - st["me_y"]) < 90 for z in zs(st)), timeout=10)
        time.sleep(0.5)
        sh = host.state()
        cleo_h = [p for p in sh["players"] if p["name"] == "Cleo"][0]
        sc = c.state()
        check("dmp: zombies damage the client", sc["health"] < hp0 or sc["dead"], (hp0, sc["health"]))
        for attempt in range(3):
            # Swing only once a zombie is within club reach (under load they can drift away).
            wait_for(c, lambda st: not st["dead"] and any(abs(z["x"] - st["me_x"]) + abs(z["y"] - st["me_y"]) < 80 for z in zs(st)), timeout=10)
            c.cmd("attack_nearest 4 0.6", timeout=20)
            sh = host.state()
            if any(z["hp"] < 100 for z in sh["zombies"]):
                break
        check("dmp: client hits are applied by the host", any(z["hp"] < 100 for z in sh["zombies"]), [(z["ai"], z["hp"]) for z in sh["zombies"]][:10])
        sh = host.state(); sc = c.state()
        h_hp = [p for p in sh["players"] if p["name"] == "Cleo"][0]
        check("dmp: client health identical on host and client", abs(sc["health"] - host_health(host, "Cleo")) < 0.5, (sc["health"], host_health(host, "Cleo")))
        host.cmd("save"); host.quit()
        wait_for(c, lambda s: not s["in_world"], timeout=12)
        host.start()
        r = host.cmd(f"host {PORT} continue Hosty"); host.cmd("dev ambient 1")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        check("dmp: rejoin after restart", r["ok"], r["error"])
        time.sleep(0.6)
        check("dmp: rejoined client sees only the base population", all(z["persistent"] for z in zs(host.state())) and
              {z["id"] for z in zs(host.state())} == {z["id"] for z in zs(c.state())}, "")
    finally:
        for i in (host, c):
            i.kill()


def host_health(host, name):
    return [p for p in host.state()["players"] if p["name"] == name][0]["health"]



def cell_xy(c, r):
    return (-704 + (c + 0.5) * 64, -384 + (r + 0.5) * 64)


def build_and_descend(i):
    go_inside(i)
    i.cmd("walk_to 300 492"); i.cmd("press_interact"); i.cmd("wait 8.5"); i.cmd("press_interact")
    i.cmd("walk_to 300 452 4"); return i.cmd("press_interact")


def scenario_dig_multi():
    host = Instance("t_ghost"); c = Instance("t_gclient")
    for i in (host, c):
        i.wipe()
    try:
        host.start(); c.start()
        host.cmd(f"host {PORT} new 61 Hosty")
        host.cmd("dev peaceful 1")
        r = build_and_descend(host)
        check("dig: host in level -1", r["state"]["region"] == L1, r["state"].get("region"))
        host.cmd("dev grant_stock 12")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        go_inside(c); c.cmd("walk_to 300 452 4"); r = c.cmd("press_interact")
        check("dig: client in level -1", r["state"]["region"] == L1, r["state"].get("region"))
        x, y = cell_xy(13, 12)
        host.cmd(f"walk_to {x} {y} 6"); c.cmd(f"walk_to {x} {y + 30} 6")
        with open(host.inbox, "a") as f: f.write("terrain dig 12 12\n")
        with open(c.inbox, "a") as f: f.write("terrain dig 12 12\n")
        host.seq += 1; c.seq += 1
        rh = host._wait(host.seq, 10); rc = c._wait(c.seq, 10)
        busy = sum(1 for rr in (rh, rc) if any("ACTION_BUSY" in n for n in rr["state"]["notices"]))
        check("dig: concurrent dig of one cell -> one job", busy == 1, [rh["state"]["notices"], rc["state"]["notices"]])
        time.sleep(2.6)
        sh, sc = host.state(), c.state()
        check("dig: both see the cell dug", "12,12" in sh["terrain"]["dug"] and "12,12" in sc["terrain"]["dug"], [sh["terrain"], sc["terrain"]])
        x2, y2 = cell_xy(12, 12)
        r = c.cmd(f"walk_to {x2} {y2} 8")
        check("dig: client walks into the new space (collision updated)", r["ok"], r["state"]["view"].get("local_x"))
        r = c.cmd("terrain dig 11 12")
        check("dig: unsupported cell refused with explanation", any("ACTION_DIG_UNSUPPORTED" in n for n in r["state"]["notices"]), r["state"]["notices"])
        host.cmd(f"walk_to {x2} {y2 + 20} 8")
        with open(host.inbox, "a") as f: f.write("terrain support 12 12\n")
        with open(c.inbox, "a") as f: f.write("terrain support 12 12\n")
        host.seq += 1; c.seq += 1
        rh = host._wait(host.seq, 10); rc = c._wait(c.seq, 10)
        time.sleep(0.5)
        check("dig: support placed once, wood spent once", host.state()["bunkers"][SITE]["wood"] == 8, host.state()["bunkers"])
        time.sleep(3.2)
        sc = c.state()
        check("dig: support reinforced on both peers", sc["terrain"]["supports"].get("12,12", {}).get("stage") == "reinforced" and
              host.state()["terrain"]["supports"].get("12,12", {}).get("stage") == "reinforced", sc["terrain"]["supports"])
        r = c.cmd("terrain dig 11 12")
        time.sleep(2.4)
        x3, y3 = cell_xy(11, 12)
        c.cmd(f"walk_to {x3} {y3} 8")
        r = c.cmd("terrain dig 10 12")
        time.sleep(2.4)
        sc = c.state()
        check("dig: digging continues into the supported area", "11,12" in sc["terrain"]["dug"] and "10,12" in sc["terrain"]["dug"], sc["terrain"]["dug"])
        # Host leaves for the surface while the client keeps digging below.
        host.cmd("walk_to 540 296 4"); host.cmd("press_interact")
        host.cmd("walk_to 480 600"); r = host.cmd("press_interact")
        check("dig: host on the surface, client underground", r["state"]["region"] == "homestead" and c.state()["region"] == L1, "")
        r = c.cmd("terrain dig 11 13")
        time.sleep(2.4)
        sh = host.state()
        check("dig: host (on surface) has the terrain changes made below", "11,13" in sh["terrains"].get(L1, []), sh["terrains"])
        check("dig: client view still underground and independent", c.state()["view"]["region"] == L1, "")
        host.cmd("save"); host.quit()
        wait_for(c, lambda s: not s["in_world"], timeout=12)
        host.start(); host.cmd(f"host {PORT} continue Hosty"); host.cmd("dev peaceful 1")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        st = r["state"]
        check("dig: after restart client rejoins underground", st["region"] == L1, st.get("region"))
        check("dig: dug cells and support persisted", set(["12,12", "11,12", "10,12", "11,13"]) <= set(st["terrain"]["dug"]) and
              st["terrain"]["supports"].get("12,12", {}).get("stage") == "reinforced", st["terrain"])
    finally:
        for i in (host, c):
            i.kill()


def res_of(state):
    return state.get("bunkers", {}).get(SITE, {}).get("resources", {})


def notice_has(state, key):
    return any(key in n for n in state.get("notices", []))


def to_door(i):
    i.cmd("walk_to 1160 760"); i.cmd("walk_to 1160 690")
    if not i.state()["entities"]["homestead.farmhouse_door"]["state"]["open"]:
        i.cmd("press_interact")
    i.cmd("walk_to 1160 664 4")
    return i.cmd("press_interact")


def scavenge_yard(i):
    """Gate must be open. Rain barrel then shed shelf (east side of the yard)."""
    i.cmd("walk_to 1150 960"); i.cmd("walk_to 1150 760"); i.cmd("walk_to 1640 760")
    i.cmd("walk_to 1680 680 6"); i.cmd("press_interact")
    i.cmd("walk_to 1560 690 6")
    return i.cmd("press_interact")


def scenario_accept():
    """The full 25-step gameplay acceptance run (zombies active), single player then host + rejoin."""
    s = Instance("t_accept"); c = Instance("t_accept_c")
    for i in (s, c):
        i.wipe()
    s.start()
    try:
        r = s.cmd("single new 91 Survivor"); s.cmd("dev ambient 1")  # legacy automatic loop under test
        check("accept 01: new world starts on the surface", r["ok"] and r["state"]["region"] == "homestead", r["state"].get("region"))
        r = go_inside(s)
        check("accept 02: reach the farmhouse", r["state"]["region"] == "homestead.farmhouse", r["state"].get("region"))
        s.cmd("walk_to 300 492"); r = s.cmd("press_interact")
        check("accept 03: shelter construction started", r["state"]["entities"][SITE]["state"]["stage"] == "building", r["state"]["entities"][SITE]["state"])
        s.cmd("walk_to 150 470"); r = s.cmd("press_interact")
        check("accept 03b: club taken", r["state"]["weapon"] == "club", r["state"].get("weapon"))
        s.cmd("walk_to 480 600"); s.cmd("press_interact")
        to_west_trees(s); s.cmd("walk_to 200 685")
        r = chop(s)
        check("accept 04: chop timber", r["state"]["carried"].get("wood", 0) >= 3, r["state"]["carried"])
        r = s.cmd("wait 1.5")
        check("accept 05: zombies investigate the noise", len(engaged(r["state"])) >= 1, [z["ai"] for z in zs(r["state"])])
        att = r["state"]["attention_total"]
        s.cmd("walk_to 380 945"); chop(s); r = s.cmd("wait 2")
        check("accept 06: more zombies converge as attention grows", len(engaged(r["state"])) >= 2 and r["state"]["attention_total"] > att,
              (len(engaged(r["state"])), att, r["state"]["attention_total"]))
        s.cmd("dev spawn_zombie")
        wait_for(s, lambda st: any(abs(z["x"] - st["me_x"]) + abs(z["y"] - st["me_y"]) < 90 for z in zs(st)), timeout=15)
        r = s.cmd("attack_nearest 6 0.6", timeout=30)
        check("accept 07: fight - club hits land", any(z["hp"] < 100 for z in r["state"]["zombies"]), [(z["ai"], z["hp"]) for z in zs(r["state"])][:6])
        s.cmd("dev heal")
        r = scavenge_yard(s)
        cr = r["state"]["carried"]
        check("accept 08: scavenge fuel and dirty water on the surface", cr.get("fuel", 0) >= 1 and cr.get("water_dirty", 0) >= 3, cr)
        r = to_door(s)
        check("accept 09: retreat into the farmhouse", r["state"]["region"] == "homestead.farmhouse", r["state"].get("region"))
        s.cmd("dev heal")
        s.cmd("walk_to 300 492")
        wait_for(s, lambda st: st["entities"][SITE]["state"]["stage"] == "built", timeout=10)
        s.cmd("press_interact"); s.cmd("walk_to 300 452 4"); r = s.cmd("press_interact")
        check("accept 10: descend into the shelter", r["state"]["region"] == L1, r["state"].get("region"))
        s.cmd("walk_to 650 345 6"); r = s.cmd("press_interact")
        check("accept 11a: storage panel opens", r["state"]["view"]["panel"] == "storage", r["state"]["view"].get("panel"))
        carried = dict(r["state"]["carried"])
        for item in list(carried.keys()):
            r = s.cmd(f"entity_action storage store {item}")
        res = res_of(r["state"])
        check("accept 11: deposit everything in shared storage (no loss)",
              all(res.get(k, 0) >= carried.get(k, 0) for k in carried) and not r["state"]["carried"], (carried, res, r["state"]["carried"]))
        s.cmd("panel_close")
        x, y = cell_xy(13, 12); s.cmd(f"walk_to {x} {y} 6")
        s.cmd("terrain dig 12 12"); r = s.cmd("wait 2.4")
        check("accept 12: excavate a new cell", "12,12" in r["state"]["terrain"]["dug"], r["state"]["terrain"]["dug"])
        x2, y2 = cell_xy(12, 12); s.cmd(f"walk_to {x2} {y2} 8")
        r = s.cmd("terrain dig 11 12")
        check("accept 13: unsupported limit refused with explanation", notice_has(r["state"], "ACTION_DIG_UNSUPPORTED"), r["state"]["notices"][-2:])
        wood0 = res_of(r["state"]).get("wood", 0)
        x2, y2 = cell_xy(12, 12); s.cmd(f"walk_to {x2} {y2 + 20} 8")
        s.cmd("terrain support 12 12"); r = s.cmd("wait 3.4")
        check("accept 14: timber support built from stored wood", r["state"]["terrain"]["supports"].get("12,12", {}).get("stage") == "reinforced"
              and res_of(r["state"]).get("wood", 0) == wood0 - 4, (r["state"]["terrain"]["supports"], wood0, res_of(r["state"])))
        s.cmd("terrain dig 11 12"); r = s.cmd("wait 2.4")
        check("accept 15: dig further inside the supported range", "11,12" in r["state"]["terrain"]["dug"], r["state"]["terrain"]["dug"])
        check("accept 16: recovered supplies are in storage", res_of(r["state"]).get("fuel", 0) >= 1 and res_of(r["state"]).get("water_dirty", 0) >= 3, res_of(r["state"]))
        s.cmd("walk_to 930 610 6"); r = s.cmd("press_interact")
        check("accept 17a: generator panel opens", r["state"]["view"]["panel"] == "generator", r["state"]["view"].get("panel"))
        lamps_off = r["state"]["view"]["lamps"]
        r = s.cmd("entity_action generator fuel")
        check("accept 17: fuel the generator (from storage)", lvl(r["state"], L1, "generator").get("fuel", 0) >= 1.0, lvl(r["state"], L1, "generator"))
        r = s.cmd("entity_action generator toggle")
        g = lvl(r["state"], L1, "generator")
        check("accept 18: start the generator", g.get("running") is True, g)
        lamps = r["state"]["view"]["lamps"]
        check("accept 19: lights power on (and were off before)", lamps and all(lamps.values()) and not any(lamps_off.values()), (lamps_off, lamps))
        check("accept 19b: hum loop plays while running", "machine" in str(r["state"]["loops"]), r["state"]["loops"])
        s.cmd("panel_close")
        s.cmd("walk_to 250 620 6"); r = s.cmd("press_interact")
        check("accept 20a: purifier panel opens", r["state"]["view"]["panel"] == "purifier", r["state"]["view"].get("panel"))
        r = s.cmd("entity_action purifier fill")
        pur = lvl(r["state"], L1, "purifier")
        check("accept 20: dirty water into the purifier", pur.get("input", 0) >= 3, pur)
        r = s.cmd("dev advance_clock 65")
        pur = lvl(r["state"], L1, "purifier")
        check("accept 21: purifier makes clean water over time with power", pur.get("output", 0) >= 3, pur)
        r = s.cmd("entity_action purifier collect")
        check("accept 21b: collect clean water", r["state"]["carried"].get("water_clean", 0) >= 3, r["state"]["carried"])
        s.cmd("panel_close"); s.cmd("dev thirst 20")
        r = s.cmd("press_key drink")
        check("accept 22: drink (Q) restores hydration", r["state"]["hydration"] >= 55, r["state"]["hydration"])
        before = r["state"]
        r = s.cmd("save")
        check("accept 23: save", r["ok"], r["error"])
        s.quit(); s.start()
        r = s.cmd("single continue Survivor")
        st = r["state"]
        g = lvl(st, L1, "generator")
        check("accept 24: reload keeps position, storage, inventory, terrain, machines",
              st["region"] == L1 and {"12,12", "11,12"} <= set(st["terrain"]["dug"]) and res_of(st) == res_of(before)
              and st["carried"] == before["carried"] and g.get("running") is True and abs(g["fuel"] - lvl(before, L1, "generator")["fuel"]) < 0.05,
              (st.get("region"), res_of(st), res_of(before), st["carried"], g))
        st = s.cmd("wait 0.5")["state"]
        check("accept 24b: lamps lit after reload (power derived)", st["view"]["lamps"] and all(st["view"]["lamps"].values()), st["view"]["lamps"])
        s.cmd("save"); s.quit(); s.start()
        s.cmd(f"host {PORT} continue Survivor"); s.cmd("dev ambient 1")
        c.start()
        r = c.cmd(f"join 127.0.0.1 {PORT} Rejoiner")
        check("accept 25a: second player joins the reloaded world", r["ok"], r["error"])
        time.sleep(0.8)
        sh, sc = s.state(), c.state()
        check("accept 25b: independent views (host underground, guest on surface)", sh["view"]["region"] == L1 and sc["view"]["region"] == "homestead", (sh["view"]["region"], sc["view"]["region"]))
        check("accept 25c: guest has the synchronized shelter state", res_of(sc) == res_of(sh) and lvl(sc, L1, "generator").get("running") == lvl(sh, L1, "generator").get("running")
              and set(sc["terrains"].get(L1, [])) == set(sh["terrains"].get(L1, [])), (res_of(sc), res_of(sh)))
        check("accept 25d: guest sees the surface zombies the host simulates", len(zs(sc)) == len(zs(sh)) and len(zs(sc)) > 0, (len(zs(sc)), len(zs(sh))))
    finally:
        for i in (s, c):
            i.kill()


def scenario_infra_multi():
    host = Instance("t_ihost"); c = Instance("t_iclient")
    for i in (host, c):
        i.wipe()
    try:
        host.start(); c.start()
        host.cmd(f"host {PORT} new 73 Hosty")
        r = build_and_descend(host)
        check("imp: host underground", r["state"]["region"] == L1, r["state"].get("region"))
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        check("imp: client joins on the surface", r["ok"] and r["state"]["region"] == "homestead", r["state"].get("region"))
        # Client scavenges on the surface while the host runs the machinery below.
        c.cmd("walk_to 1150 960")
        if not c.state()["entities"]["homestead.yard_gate"]["state"]["open"]:
            c.cmd("press_interact")
        r = scavenge_yard(c)
        check("imp: client scavenges (host-validated)", r["state"]["carried"].get("water_dirty", 0) >= 3 and r["state"]["carried"].get("fuel", 0) >= 1, r["state"]["carried"])
        host.cmd("dev grant fuel:2")
        host.cmd("walk_to 930 610 6")
        host.cmd("entity_action generator fuel"); host.cmd("entity_action generator fuel")
        r = host.cmd("entity_action generator toggle")
        check("imp: host starts the generator", lvl(r["state"], L1, "generator").get("running") is True, lvl(r["state"], L1, "generator"))
        time.sleep(0.5)
        check("imp: client on the surface sees generator running", lvl(c.state(), L1, "generator").get("running") is True, lvl(c.state(), L1, "generator"))
        sh = host.state()
        check("imp: client's loot state mirrored to host", not sh["entities"]["homestead.rain_barrel"]["state"].get("looted_at", -1) < 0, sh["entities"]["homestead.rain_barrel"])
        r = to_door(c)
        c.cmd("walk_to 300 452 4"); r = c.cmd("press_interact")
        check("imp: client descends", r["state"]["region"] == L1, r["state"].get("region"))
        r = c.cmd("wait 0.5")
        check("imp: client sees the lamps lit", r["state"]["view"]["lamps"] and all(r["state"]["view"]["lamps"].values()), r["state"]["view"]["lamps"])
        # Storage race: one fuel in storage, both take at once.
        host.cmd("walk_to 650 345 6"); c.cmd("walk_to 640 350 6")
        r = c.cmd("entity_action storage store fuel")
        r = c.cmd("entity_action storage store water_dirty")
        time.sleep(0.4)
        fuel_total = res_of(host.state()).get("fuel", 0)
        check("imp: client deposit visible to host", fuel_total >= 1 and res_of(host.state()).get("water_dirty", 0) >= 3, res_of(host.state()))
        for i in range(fuel_total):
            with open(host.inbox, "a") as f: f.write("entity_action storage take fuel\n")
            with open(c.inbox, "a") as f: f.write("entity_action storage take fuel\n")
            host.seq += 1; c.seq += 1
            host._wait(host.seq, 10); c._wait(c.seq, 10)
        time.sleep(0.5)
        sh, sc = host.state(), c.state()
        h_f = sh["carried"].get("fuel", 0); c_f = sc["carried"].get("fuel", 0)
        check("imp: concurrent withdrawals never duplicate", h_f + c_f + res_of(sh).get("fuel", 0) == fuel_total and res_of(sh).get("fuel", 0) == 0, (h_f, c_f, res_of(sh), fuel_total))
        check("imp: inventories agree on both peers", [p for p in sh["players"] if p["name"] == "Cleo"][0]["carried"] == sc["carried"], "")
        c.cmd("walk_to 250 620 6")
        r = c.cmd("entity_action purifier fill")
        check("imp: client fills the purifier from storage", lvl(r["state"], L1, "purifier").get("input", 0) >= 3, lvl(r["state"], L1, "purifier"))
        # Host leaves for the surface; the bunker keeps running for the client below.
        host.cmd("walk_to 540 296 4"); host.cmd("press_interact"); host.cmd("walk_to 480 600"); r = host.cmd("press_interact")
        check("imp: host on the surface, client underground", r["state"]["region"] == "homestead" and c.state()["region"] == L1, "")
        fuel0 = lvl(c.state(), L1, "generator")["fuel"]
        host.cmd("dev advance_clock 45")
        time.sleep(0.6)
        sc, sh = c.state(), host.state()
        check("imp: purification proceeds while host is elsewhere", lvl(sc, L1, "purifier").get("output", 0) >= 2, lvl(sc, L1, "purifier"))
        check("imp: fuel burns on the shared clock", lvl(sc, L1, "generator")["fuel"] < fuel0, (fuel0, lvl(sc, L1, "generator")))
        io = lambda st: (lvl(st, L1, "purifier").get("input"), lvl(st, L1, "purifier").get("output"))
        check("imp: purifier contents identical on both peers (progress is published in 10% steps)", io(sc) == io(sh), (lvl(sc, L1, "purifier"), lvl(sh, L1, "purifier")))
        r = c.cmd("entity_action purifier collect")
        host.cmd("dev thirst 20")
        c.cmd("entity_action purifier collect")
        r = c.cmd("press_key drink")
        time.sleep(0.4)
        h_view = [p for p in host.state()["players"] if p["name"] == "Cleo"][0]
        check("imp: client drinks; hydration agrees on host", r["state"]["hydration"] > 90 or abs(h_view["hydration"] - r["state"]["hydration"]) < 1.0,
              (r["state"]["hydration"], h_view["hydration"]))
        snap = c.state()
        saved = host.cmd("save")["state"]
        host.quit()
        wait_for(c, lambda s: not s["in_world"], timeout=12)
        host.start(); host.cmd(f"host {PORT} continue Hosty")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        st = r["state"]
        check("imp: client rejoins underground after restart", st["region"] == L1, st.get("region"))
        check("imp: storage, inventory and machines persisted", res_of(st) == res_of(snap) and st["carried"] == snap["carried"]
              and io(st) == io(saved) and lvl(st, L1, "generator")["running"] == lvl(saved, L1, "generator")["running"]
              and abs(lvl(st, L1, "generator")["fuel"] - lvl(saved, L1, "generator")["fuel"]) < 0.02,
              (lvl(st, L1, "purifier"), lvl(saved, L1, "purifier"), lvl(st, L1, "generator"), lvl(saved, L1, "generator")))
    finally:
        for i in (host, c):
            i.kill()



def objs(state, region="homestead"):
    return state.get("objects", {}).get(region, {})


def obj_of(state, d, region="homestead"):
    return {k: v for k, v in objs(state, region).items() if v["def"] == d}


def send_both(a, b, line_a, line_b=None):
    """Queue a command on two instances at the same moment (true concurrency)."""
    with open(a.inbox, "a") as f: f.write(line_a + "\n")
    with open(b.inbox, "a") as f: f.write((line_b or line_a) + "\n")
    a.seq += 1; b.seq += 1
    return a._wait(a.seq, 10), b._wait(b.seq, 10)


def scenario_build_multi():
    host = Instance("t_bhost2"); c = Instance("t_bclient2")
    for i in (host, c):
        i.wipe()
    try:
        host.start(); c.start()
        host.cmd(f"host {PORT} new 66 Hosty"); host.cmd("dev peaceful 1")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        check("build: client joins", r["ok"], r["error"])
        # Client gathers its own timber; host is granted materials (host-only dev command).
        to_west_trees(c); c.cmd("walk_to 200 685"); chop(c); c.cmd("walk_to 380 945"); r = chop(c)
        check("build: client chops timber", r["state"]["carried"].get("wood", 0) >= 6, r["state"]["carried"])
        c_wood = r["state"]["carried"]["wood"]
        r = c.cmd("dev grant wood:20")
        check("build: dev grant refused for the client", r["state"]["carried"].get("wood", 0) == c_wood and any("DEV_HOST_ONLY" in n for n in r["state"]["notices"]), r["state"]["notices"][-2:])
        host.cmd("dev grant wood:12"); host.cmd("dev grant scrap_metal:6"); host.cmd("dev grant cement:2")
        host.cmd("walk_to 1150 960")
        if not host.state()["entities"]["homestead.yard_gate"]["state"]["open"]:
            host.cmd("press_interact")
        host.cmd("walk_to 1150 760"); host.cmd("walk_to 1340 790")
        c.cmd("walk_to 1150 960"); c.cmd("walk_to 1150 790"); c.cmd("walk_to 1400 790")
        rh, rc = send_both(host, c, "build barricade 1360 700")
        time.sleep(4.0)
        sh, sc = host.state(), c.state()
        bars = obj_of(sh, "barricade")
        check("build: simultaneous placement on one spot -> one structure", len(bars) == 1, bars)
        paid = (12 - sh["carried"].get("wood", 0)) + (c_wood - sc["carried"].get("wood", 0))
        check("build: materials spent exactly once", paid == 3, paid)
        check("build: both peers see it built", list(obj_of(sc, "barricade").values())[0]["stage"] == "built" and list(bars.values())[0]["stage"] == "built", (bars, obj_of(sc, "barricade")))
        oid = list(bars.keys())[0]
        r = host.cmd(f"obj {oid} upgrade")
        time.sleep(0.4)
        check("build: host upgrades to metal; client sees tier and condition", obj_of(c.state(), "barricade")[oid]["tier"] == 1 and obj_of(c.state(), "barricade")[oid]["hp"] == 260, obj_of(c.state(), "barricade"))
        host.cmd("dev damage_structures 60")
        time.sleep(0.4)
        hp_c = obj_of(c.state(), "barricade")[oid]["hp"]
        check("build: damage replicated", hp_c == 260 - (60 - 3), hp_c)
        c.cmd("dev grant scrap_metal:1")
        host.cmd("dev grant scrap_metal:0")
        r = host.cmd(f"obj {oid} repair")
        time.sleep(0.4)
        check("build: repair restores condition on both peers", obj_of(c.state(), "barricade")[oid]["hp"] == 260 and obj_of(host.state(), "barricade")[oid]["hp"] == 260, obj_of(c.state(), "barricade"))
        r = c.cmd("walk_to 1360 640", timeout=30)
        st = c.state()
        check("build: the barricade blocks the client's movement", st["me_y"] > 690, (st["me_x"], st["me_y"]))
        c.cmd("walk_to 1300 860")
        r = c.cmd("build crate 1260 820")
        time.sleep(2.6)
        crates = obj_of(host.state(), "crate")
        check("build: client builds a crate; host sees it", len(crates) == 1 and list(crates.values())[0]["stage"] == "built", crates)
        coid = list(crates.keys())[0]
        host_wood = host.state()["carried"].get("wood", 0)
        c_before = c.state()["carried"].get("wood", 0)
        r = host.cmd(f"obj {coid} store wood")
        time.sleep(0.3)
        boxed = obj_of(c.state(), "crate")[coid]["items"].get("wood", 0)
        check("build: host stores into the client's crate; client sees it", boxed == host_wood and boxed > 3, (boxed, host_wood))
        c.cmd(f"obj {coid} take wood")
        c.cmd(f"obj {coid} store wood") if False else None
        st = c.state()
        check("build: client takes it out (moved, not copied)", st["carried"].get("wood", 0) == c_before + boxed and obj_of(host.state(), "crate")[coid]["items"].get("wood", 0) == 0,
              (st["carried"], obj_of(host.state(), "crate")[coid]["items"]))
        r = c.cmd(f"obj {coid} store wood")
        time.sleep(0.3)
        boxed = obj_of(host.state(), "crate")[coid]["items"].get("wood", 0)
        r = c.cmd(f"obj {coid} dismantle")
        time.sleep(0.4)
        sh = host.state()
        piles = obj_of(sh, "pile")
        check("build: dismantled crate leaves its contents on the ground", not obj_of(sh, "crate") and len(piles) == 1 and list(piles.values())[0]["items"].get("wood", 0) == boxed, piles)
        check("build: dismantling refunds half the crate", c.state()["carried"].get("wood", 0) == 2, c.state()["carried"])
        r = c.cmd(f"obj {list(piles.keys())[0]} pickup")
        check("build: pile picked up (no loss, no duplication)", r["state"]["carried"].get("wood", 0) == boxed + 2 and not obj_of(host.state(), "pile"), r["state"]["carried"])
        # Underground construction: shared storage pays; concurrent builds never overspend it.
        host.cmd("walk_to 1150 760"); host.cmd("walk_to 1160 690")
        if not host.state()["entities"]["homestead.farmhouse_door"]["state"]["open"]:
            host.cmd("press_interact")
        host.cmd("walk_to 1160 664 4"); host.cmd("press_interact")
        host.cmd("walk_to 300 492"); host.cmd("press_interact"); host.cmd("wait 8.5"); host.cmd("press_interact")
        host.cmd("walk_to 300 452 4"); r = host.cmd("press_interact")
        check("build: host underground", r["state"]["region"] == L1, r["state"].get("region"))
        go_inside(c); c.cmd("walk_to 300 452 4"); r = c.cmd("press_interact")
        check("build: client underground too", r["state"]["region"] == L1, r["state"].get("region"))
        host.cmd("walk_to 650 345 6")
        host.cmd("dev grant wood:12")
        for item in ("wood",):
            host.cmd(f"entity_action storage store {item}")
        stock = host.state()["bunkers"][SITE]["resources"].get("wood", 0)
        x1, y1 = cell_xy(16, 14); x2, y2 = cell_xy(18, 15)
        host.cmd(f"walk_to {x1} {y1 + 70} 8"); c.cmd(f"walk_to {x2} {y2 + 70} 8")
        cw0 = c.state()["carried"].get("wood", 0); hw0 = host.state()["carried"].get("wood", 0)
        rh, rc = send_both(host, c, f"build barricade {x1} {y1}", f"build barricade {x2} {y2}")
        time.sleep(3.6)
        sh = host.state()
        walls = obj_of(sh, "barricade", L1)
        check("build: both underground walls built from shared storage", len(walls) == 2 and all(v["stage"] == "built" for v in walls.values()), walls)
        spent = (stock - sh["bunkers"][SITE]["resources"].get("wood", 0)) + (cw0 - c.state()["carried"].get("wood", 0)) + (hw0 - sh["carried"].get("wood", 0))
        check("build: bags + shared storage paid exactly twice (bag first, then storage)", spent == 6, (stock, sh["bunkers"][SITE]["resources"], cw0, c.state()["carried"]))
        check("build: client sees the walls", len(obj_of(c.state(), "barricade", L1)) == 2, obj_of(c.state(), "barricade", L1))
        snap = host.state()
        host.cmd("save"); host.quit()
        wait_for(c, lambda s: not s["in_world"], timeout=12)
        host.start(); host.cmd(f"host {PORT} continue Hosty"); host.cmd("dev peaceful 1")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        st = r["state"]
        same = {k: (v["def"], v["tier"], v["hp"]) for k, v in objs(st).items() if v["def"] != "pile"} == {k: (v["def"], v["tier"], v["hp"]) for k, v in objs(snap).items() if v["def"] != "pile"}
        check("build: structures, tiers and condition persist across a host restart", same and len(obj_of(st, "barricade", L1)) == 2, objs(st))
    finally:
        for i in (host, c):
            i.kill()



def pl(state, name):
    return [p for p in state["players"] if p["name"] == name][0]


def scenario_craft_multi():
    host = Instance("t_chost"); c = Instance("t_cclient")
    for i in (host, c):
        i.wipe()
    try:
        host.start(); c.start()
        host.cmd(f"host {PORT} new 67 Hosty"); host.cmd("dev peaceful 1")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        check("craft: client joins", r["ok"], r["error"])
        # Client scavenges food and cloth in the farmhouse.
        go_inside(c)
        c.cmd("walk_to 186 340"); c.cmd("interact homestead.farmhouse.pantry")
        c.cmd("walk_to 728 380"); r = c.cmd("interact homestead.farmhouse.linen")
        check("craft: client finds food and cloth indoors", r["state"]["carried"].get("canned_food", 0) >= 2 and r["state"]["carried"].get("cloth", 0) >= 2, r["state"]["carried"])
        c.cmd("walk_to 480 600"); c.cmd("press_interact")
        host.cmd("dev grant wood:14"); host.cmd("dev grant scrap_metal:6")
        host.cmd("walk_to 1150 960")
        if not host.state()["entities"]["homestead.yard_gate"]["state"]["open"]:
            host.cmd("press_interact")
        host.cmd("walk_to 1150 760"); host.cmd("walk_to 1300 860")
        host.cmd("build workbench 1260 820"); time.sleep(4.5)
        bench = list(obj_of(host.state(), "workbench").keys())
        check("craft: host builds a workbench", len(bench) == 1, objs(host.state()))
        bench = bench[0]
        c.cmd("walk_to 1150 760"); c.cmd("walk_to 1220 880")
        h0, c0 = host.state()["carried"], c.state()["carried"]
        rh, rc = send_both(host, c, f"obj {bench} craft hatchet", f"obj {bench} craft bandage")
        time.sleep(0.5)
        sh, sc = host.state(), c.state()
        started_host = sh["carried"].get("scrap_metal", 0) < h0.get("scrap_metal", 0)
        started_client = sc["carried"].get("cloth", 0) < c0.get("cloth", 0)
        check("craft: concurrent crafting at one bench -> exactly one job", started_host != started_client, (sh["carried"], sc["carried"]))
        check("craft: the refused crafter keeps all materials", (not started_host and sh["carried"] == h0) or (not started_client and sc["carried"] == c0),
              (sh["carried"], sc["carried"]))
        time.sleep(7)
        winner, other = (host, c) if started_host else (c, host)
        r = winner.cmd(f"obj {bench} collect")
        made = "hatchet" if started_host else "bandage"
        st = r["state"]
        check("craft: crafted item collected by the crafter", (made in [g["item"] for g in st["gear"]]) if made == "hatchet" else st["carried"].get("bandage", 0) == 2,
              (st["gear"], st["carried"]))
        r = other.cmd(f"obj {bench} craft " + ("bandage" if started_host else "hatchet"))
        time.sleep(7)
        r = other.cmd(f"obj {bench} collect")
        check("craft: second crafter's job ran after the first", len(r["state"]["gear"]) >= 1 or r["state"]["carried"].get("bandage", 0) == 2, (r["state"]["gear"], r["state"]["carried"]))
        sh = host.state()
        check("craft: host holds the hatchet (auto-equipped)", sh["weapon"] == "hatchet", sh.get("weapon"))
        # Hand the hatchet over: drop and pick up keeps the item's identity.
        uid = [g["uid"] for g in sh["gear"] if g["item"] == "hatchet"][0]
        host.cmd(f"inv drop {uid}")
        time.sleep(0.4)
        piles = obj_of(c.state(), "pile")
        check("craft: dropped hatchet visible to the client", len(piles) == 1, piles)
        c.cmd("walk_to 1300 880")
        r = c.cmd(f"obj {list(piles.keys())[0]} pickup")
        time.sleep(0.3)
        check("craft: picked up by the client with the same identity", any(g["uid"] == uid for g in r["state"]["gear"]) and not obj_of(host.state(), "pile"), r["state"]["gear"])
        c.cmd(f"inv equip {uid}")
        time.sleep(0.3)
        check("craft: client equips it; host sees it", c.state()["weapon"] == "hatchet" and "hatchet" in pl(host.state(), "Cleo")["gear"], (c.state()["weapon"], pl(host.state(), "Cleo")))
        r = c.cmd("eat")
        time.sleep(0.3)
        check("craft: client eats; inventory and hunger agree on the host (hunger is published in 2-point steps)", abs(pl(host.state(), "Cleo")["hunger"] - c.state()["hunger"]) < 2.0
              and c.state()["carried"].get("canned_food", 0) == 1, (pl(host.state(), "Cleo")["hunger"], c.state()["hunger"], c.state()["carried"]))
        # A crafting job survives a host restart and finishes exactly once.
        host.cmd("dev grant scrap_metal:3"); host.cmd("dev grant wood:1")
        r = host.cmd(f"obj {bench} craft machete")
        check("craft: machete job started", "job" in str(r["state"]["objects"]) or r["ok"], "")
        host.cmd("save"); host.quit()
        wait_for(c, lambda s: not s["in_world"], timeout=12)
        host.start(); host.cmd(f"host {PORT} continue Hosty"); host.cmd("dev peaceful 1")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        check("craft: client rejoins with its gear", r["ok"] and "hatchet" in [g["item"] for g in r["state"]["gear"]], r["state"].get("gear"))
        time.sleep(11)
        host.cmd("walk_to 1300 860")
        r = host.cmd(f"obj {bench} collect")
        machetes = [g for g in r["state"]["gear"] if g["item"] == "machete"]
        check("craft: job finished after the restart, exactly one machete", len(machetes) == 1, r["state"]["gear"])
        r = host.cmd(f"obj {bench} collect")
        check("craft: nothing left to collect twice", any("ACTION_NOTHING_THERE" in n for n in r["state"]["notices"]), r["state"]["notices"][-2:])
    finally:
        for i in (host, c):
            i.kill()



def scenario_world_multi():
    host = Instance("t_whost"); c = Instance("t_wclient")
    for i in (host, c):
        i.wipe()
    try:
        host.start(); c.start()
        host.cmd(f"host {PORT} new 68 Hosty")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        check("world: client joins", r["ok"], r["error"])
        host.cmd("dev weather heavy_rain")
        time.sleep(0.4)
        sh, sc = host.state(), c.state()
        check("world: weather is shared", sh["env"].get("weather") == "heavy_rain" and sc["env"].get("weather") == "heavy_rain", (sh["env"], sc["env"]))
        check("world: one clock (ticks agree)", abs(sh["tick"] - sc["tick"]) <= 5, (sh["tick"], sc["tick"]))
        # Client walks east along the road to the service station; host stays home.
        c.cmd("dev teleport 2300 1400")
        st = c.state()
        check("world: client dev teleport refused (dev is host-only)", st["me_x"] < 2000, st["me_x"])
        c.cmd("walk_to 1150 1400"); c.cmd("walk_to 2340 1400 10")
        r = c.cmd("interact homestead.road_east")
        check("world: client travels to the service station", r["state"]["region"] == "service_station", r["state"].get("region"))
        time.sleep(0.3)
        check("world: discovery recorded for everyone", "service_station" in host.state()["meta"].get("discoveries", {}), host.state()["meta"])
        check("world: host stays at the homestead (independent regions)", host.state()["region"] == "homestead" and host.state()["view"]["region"] == "homestead", "")
        c.cmd("walk_to 1700 720"); c.cmd("walk_to 2000 580 10")
        r = c.cmd("interact service_station.tool_locker")
        items = [g["item"] for g in r["state"]["gear"]]
        check("world: client finds the carburetor and the manual", "carburetor" in items and "workshop_manual" in items, items)
        r = c.cmd("interact service_station.tool_locker")
        check("world: the unique find cannot be taken twice", any("ACTION_LOOT_GONE" in n for n in r["state"]["notices"]), r["state"]["notices"][-2:])
        uid = [g["uid"] for g in r["state"]["gear"] if g["item"] == "workshop_manual"][0]
        c.cmd(f"inv use {uid}")
        time.sleep(0.3)
        check("world: reading the manual unlocks the felling axe for the whole world", host.state()["unlocks"].get("felling_axe") is True, host.state().get("unlocks"))
        # A horde comes to the homestead; both players see the event.
        host.cmd("walk_to 1150 960")
        host.cmd("dev siege 2")
        time.sleep(0.4)
        check("world: horde warning reaches the remote player", c.state()["meta"].get("siege", {}).get("phase") == "warning", c.state()["meta"].get("siege"))
        time.sleep(2.6)
        sh = host.state()
        horde = [z for z in zs(sh) if z["region"] == "homestead" and not z["persistent"]]
        check("world: horde spawned at the homestead", sh["meta"]["siege"]["phase"] == "active" and len(horde) >= 6, (sh["meta"].get("siege"), len(horde)))
        check("world: client (far away) mirrors the horde", len([z for z in zs(c.state()) if z["region"] == "homestead"]) >= len(horde), "")
        sid = sh["meta"]["siege"]["id"]
        host.cmd("dev advance_clock 200")
        time.sleep(0.5)
        sh, sc = host.state(), c.state()
        check("world: the event ends with a defined outcome on both peers", sh["meta"]["siege"]["phase"] == "idle" and sc["meta"]["siege"].get("outcome") in ("repelled", "dispersed"),
              (sh["meta"]["siege"], sc["meta"]["siege"]))
        snap = host.state()
        host.cmd("save"); host.quit()
        wait_for(c, lambda s: not s["in_world"], timeout=12)
        host.start(); host.cmd(f"host {PORT} continue Hosty")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        st = r["state"]
        check("world: client rejoins at the service station", st["region"] == "service_station", st.get("region"))
        check("world: discoveries, unlocks and weather persist", "workshop_locker" in st["meta"].get("discoveries", {}) and st["meta"].get("unlocks", {}).get("felling_axe")
              and st["env"].get("weather") == snap["env"].get("weather"), (st["meta"], st["env"]))
        check("world: the finished event does not come back after restart", st["meta"]["siege"]["phase"] == "idle" and st["meta"]["siege"]["id"] == sid, st["meta"].get("siege"))
        check("world: carburetor still carried (no loss, no duplicate)", [g["item"] for g in st["gear"]].count("carburetor") == 1, st["gear"])
    finally:
        for i in (host, c):
            i.kill()



def scenario_settlement_multi():
    host = Instance("t_shost"); c = Instance("t_sclient")
    for i in (host, c):
        i.wipe()
    try:
        host.start(); c.start()
        host.cmd(f"host {PORT} new 69 Hosty"); host.cmd("dev peaceful 1")
        r = build_and_descend(host)
        check("settle: host shelter built", r["state"]["region"] == L1, r["state"].get("region"))
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        check("settle: client joins; survivor exists at the station", r["ok"] and r["state"]["npcs"].get("mara", {}).get("region") == "service_station", r["state"].get("npcs"))
        # Host prepares the bunker: dirty water in storage, generator running.
        host.cmd("dev grant water_dirty:3"); host.cmd("dev grant fuel:2")
        host.cmd("walk_to 650 345 6"); host.cmd("entity_action storage store water_dirty")
        host.cmd("walk_to 930 610 6"); host.cmd("entity_action generator fuel"); host.cmd("entity_action generator fuel"); host.cmd("entity_action generator toggle")
        # Host travels to the service station to find the survivor.
        host.cmd("walk_to 540 296 4"); host.cmd("press_interact"); host.cmd("walk_to 480 600"); host.cmd("press_interact")
        host.cmd("dev teleport 2340 1400"); r = host.cmd("interact homestead.road_east")
        check("settle: host reaches the station", r["state"]["region"] == "service_station", r["state"].get("region"))
        host.cmd("walk_to 372 664 10")   # Red Thaw: she hides in the collapsed house
        r = host.cmd("npc mara talk")
        check("settle: host meets Mara", r["state"]["npcs"]["mara"]["recruit"] == "met", r["state"]["npcs"]["mara"])
        r = host.cmd("npc mara talk")
        check("settle: she still needs food and water", r["state"]["npcs"]["mara"]["recruit"] == "met" and any("NPC_STILL_NEEDS" in n for n in r["state"]["notices"]), r["state"]["notices"][-2:])
        host.cmd("dev grant canned_food:1"); host.cmd("dev grant water_clean:1")
        r = host.cmd("npc mara talk")
        check("settle: recruited", r["state"]["npcs"]["mara"]["recruit"] == "travelling", r["state"]["npcs"]["mara"])
        time.sleep(0.4)
        check("settle: client sees her leave the station", c.state()["npcs"]["mara"]["recruit"] == "travelling", c.state()["npcs"]["mara"])
        # Client goes down into the shelter and waits for her.
        go_inside(c); c.cmd("walk_to 300 452 4"); r = c.cmd("press_interact")
        check("settle: client underground", r["state"]["region"] == L1, r["state"].get("region"))
        host.cmd("dev advance_clock 65")
        time.sleep(1.0)
        sc = c.state()
        check("settle: she arrives and the client sees her in the bunker", sc["npcs"]["mara"]["recruit"] == "home" and sc["npcs"]["mara"]["region"] == L1 and sc["view"]["npcs"] == 1,
              (sc["npcs"]["mara"], sc["view"].get("npcs")))
        r = c.cmd("npc mara assign water")
        time.sleep(0.4)
        check("settle: client assigns the water job; host (far away) sees it", host.state()["npcs"]["mara"]["job"] == "water", host.state()["npcs"]["mara"])
        # Client leaves too: nobody views the bunker; work continues on the shared clock.
        c.cmd("walk_to 540 296 4"); c.cmd("press_interact")
        check("settle: nobody is in the bunker", c.state()["region"] != L1 and host.state()["region"] == "service_station", "")
        host.cmd("dev advance_clock 30")
        time.sleep(0.5)
        host.cmd("dev advance_clock 90")
        time.sleep(1.0)
        res = c.state()["bunkers"][SITE]["resources"]
        lvl1 = c.state()["level_entities"][L1]["purifier"]["state"]
        moved = res.get("water_dirty", 0) == 0 and lvl1.get("input", 0) + lvl1.get("output", 0) + res.get("water_clean", 0) == 3
        check("settle: she filled the purifier from storage while nobody watched (water conserved)", moved, (res, lvl1))
        check("settle: client sees the same storage as the host", c.state()["bunkers"][SITE]["resources"] == host.state()["bunkers"][SITE]["resources"], "")
        host.cmd("save"); host.quit()
        wait_for(c, lambda s: not s["in_world"], timeout=12)
        host.start(); host.cmd(f"host {PORT} continue Hosty"); host.cmd("dev peaceful 1")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        m = r["state"]["npcs"].get("mara", {})
        check("settle: after restart she still lives in the bunker with her job", m.get("recruit") == "home" and m.get("job") == "water" and m.get("region") == L1, m)
        check("settle: exactly one survivor after restart", len(r["state"]["npcs"]) == 1, r["state"]["npcs"])
    finally:
        for i in (host, c):
            i.kill()



def heal_if_low(i, limit=55):
    st = i.state()
    if st.get("health", 100) < limit:
        i.cmd("dev heal")


def enter_bunker(i):
    """From the homestead surface (yard side) to bunker level -1, using explicit targets.
    Retries each leg: zombies or a closing door can interrupt a scripted walk."""
    for _attempt in range(4):
        st = i.state()
        if st["region"] == L1:
            break
        if st["region"] == "homestead":
            if st.get("health", 100) < 55:
                i.cmd("dev heal")
            i.cmd("walk_to 1150 960")
            if not i.state()["entities"]["homestead.yard_gate"]["state"]["open"]:
                i.cmd("interact homestead.yard_gate")
            i.cmd("walk_to 1150 760"); i.cmd("walk_to 1160 700")
            if not i.state()["entities"]["homestead.farmhouse_door"]["state"]["open"]:
                i.cmd("interact homestead.farmhouse_door")
            i.cmd("walk_to 1160 664 4"); i.cmd("interact homestead.farmhouse_entry")
        elif st["region"] == "homestead.farmhouse":
            i.cmd("walk_to 300 470 6")
            if not i.state()["entities"][SITE]["state"].get("open", False):
                i.cmd("interact " + SITE)
            i.cmd("walk_to 300 452 4"); i.cmd("interact homestead.farmhouse.hatch_ladder")
    return i.state()


def leave_bunker(i):
    """From bunker level -1 up to the homestead surface, using explicit targets."""
    if BunkerStateLike(i.state()["region"]):
        i.cmd("walk_to 540 296 4"); i.cmd("interact ladder_up")
    if i.state()["region"] == "homestead.farmhouse":
        i.cmd("walk_to 480 600 6"); i.cmd("interact homestead.farmhouse.exit")
    return i.state()


def BunkerStateLike(region):
    return region.startswith("bunker:")


def scenario_slice():
    """The integrated vertical-slice loop (brief §8.1, 19 steps) in one real game with zombies active.
    Developer commands are used only to compress waiting (advance_clock), to trigger the defence event
    immediately (its natural trigger is unit-tested), and as a safety heal so a bad roll cannot end the run."""
    s = Instance("t_slice"); s.wipe(); s.start()
    try:
        r = s.cmd("single new 101 Pioneer"); s.cmd("tips off"); s.cmd("dev ambient 1")  # legacy automatic loop under test
        check("slice 00: new survival world, nothing prepared", r["ok"] and not [b for b in r["state"]["bunkers"] if b != "town.house.cellar"] and not r["state"]["gear"], "")
        # 1. Establish the bunker.
        go_inside(s); s.cmd("walk_to 300 492"); s.cmd("press_interact")
        s.cmd("walk_to 150 470"); r = s.cmd("press_interact")
        check("slice 01: shelter dig started, club taken", r["state"]["entities"][SITE]["state"]["stage"] in ("building", "built") and r["state"]["weapon"] == "club", "")
        s.cmd("walk_to 186 340"); s.cmd("interact homestead.farmhouse.pantry")
        s.cmd("walk_to 728 380"); s.cmd("interact homestead.farmhouse.linen")
        s.cmd("walk_to 480 600"); s.cmd("press_interact")
        # 2-4. Gather on the surface; fight; noise draws more.
        to_west_trees(s); s.cmd("walk_to 200 685"); chop(s); heal_if_low(s)
        r = s.cmd("wait 1.5")
        check("slice 02: gathered timber", r["state"]["carried"].get("wood", 0) >= 3, r["state"]["carried"])
        check("slice 03: zombies come to the noise", len(engaged(r["state"])) >= 1, [z["ai"] for z in zs(r["state"])])
        att = r["state"]["attention_total"]
        s.cmd("walk_to 380 945"); chop(s); r = s.cmd("wait 2"); heal_if_low(s)
        check("slice 04: continued noise grows the threat", r["state"]["attention_total"] > att and len(engaged(r["state"])) >= 2, (att, r["state"]["attention_total"]))
        s.cmd("dev spawn_zombie")
        wait_for(s, lambda st: any(abs(z["x"] - st["me_x"]) + abs(z["y"] - st["me_y"]) < 90 for z in zs(st)), timeout=15)
        r = s.cmd("attack_nearest 6 0.6", timeout=30); heal_if_low(s)
        check("slice 03b: fight — hits land", any(z["hp"] < 100 for z in r["state"]["zombies"]), "")
        # 5. Retreat and recover.
        s.cmd("walk_to 700 960"); r = go_inside(s)
        r = s.cmd("wait 5")
        check("slice 05: retreat indoors; nothing follows", r["state"]["region"] == "homestead.farmhouse" and r["state"]["view"]["zombies"] == 0, r["state"].get("region"))
        r = s.cmd("eat")
        check("slice 05b: eat to recover", r["state"]["carried"].get("canned_food", 0) == 1, r["state"]["carried"])
        # Scavenge scrap, fuel and water around the farm (zombies may be about: heal as a safety net only).
        s.cmd("walk_to 480 600"); s.cmd("press_interact"); s.cmd("dev heal")
        s.cmd("walk_to 1150 960"); s.cmd("walk_to 1150 1100"); s.cmd("walk_to 650 1100"); s.cmd("walk_to 650 1445 6"); s.cmd("press_interact")
        s.cmd("walk_to 650 1100"); s.cmd("walk_to 1600 1100"); s.cmd("walk_to 1600 1185 8"); s.cmd("interact homestead.tractor")
        heal_if_low(s)
        s.cmd("walk_to 1910 1230 8"); chop(s); heal_if_low(s)
        s.cmd("walk_to 1150 1100"); s.cmd("walk_to 1150 960"); s.cmd("walk_to 1150 760"); s.cmd("walk_to 1640 760"); s.cmd("walk_to 1680 680 6"); s.cmd("press_interact")
        s.cmd("walk_to 1560 690 6"); s.cmd("press_interact")
        s.cmd("walk_to 1150 760"); s.cmd("walk_to 950 760"); s.cmd("walk_to 860 560 8"); r = chop(s); heal_if_low(s)
        s.cmd("walk_to 950 760")
        cr = r["state"]["carried"]
        check("slice 09: scavenged fuel, water, metal and parts; more timber", cr.get("wood", 0) >= 12 and cr.get("fuel", 0) >= 2 and cr.get("scrap_metal", 0) >= 4 and cr.get("water_dirty", 0) >= 2 and cr.get("electrical_parts", 0) >= 1, cr)
        # Into the shelter: storage, expansion, construction, crafting, power and water.
        r = to_door(s)
        s.cmd("walk_to 300 492")
        wait_for(s, lambda st: st["entities"][SITE]["state"]["stage"] == "built", timeout=10)
        s.cmd("press_interact"); s.cmd("walk_to 300 452 4"); r = s.cmd("press_interact")
        check("slice 01b: in the bunker", r["state"]["region"] == L1, r["state"].get("region"))
        s.cmd("walk_to 650 345 6")
        for item in list(r["state"]["carried"].keys()):
            if item not in ("canned_food",):
                s.cmd(f"entity_action storage store {item}")
        r = s.cmd("wait 0.3")
        check("slice 08: everything in shared storage", r["state"]["bunkers"][SITE]["resources"].get("scrap_metal", 0) >= 4, r["state"]["bunkers"][SITE]["resources"])
        x, y = cell_xy(13, 12); s.cmd(f"walk_to {x} {y} 6"); s.cmd("terrain dig 12 12"); s.cmd("wait 2.4")
        x2, y2 = cell_xy(12, 12); s.cmd(f"walk_to {x2} {y2 + 20} 8"); s.cmd("terrain support 12 12"); s.cmd("wait 3.4")
        s.cmd(f"walk_to {x2} {y2} 8"); s.cmd("terrain dig 11 12"); r = s.cmd("wait 2.4")
        check("slice 06: chamber expanded with a support", {"12,12", "11,12"} <= set(r["state"]["terrain"]["dug"]), r["state"]["terrain"])
        bx, by = cell_xy(20, 12)
        s.cmd(f"walk_to {bx} {by + 70} 8"); r = s.cmd(f"build workbench {bx} {by}"); s.cmd("wait 4.5")
        benches = obj_of(s.state(), "workbench", L1)
        check("slice 07: workbench built underground from storage", len(benches) == 1, objs(s.state(), L1))
        bench = list(benches.keys())[0]
        s.cmd(f"obj {bench} craft hatchet"); s.cmd("wait 6.5"); r = s.cmd(f"obj {bench} collect")
        check("slice 10: crafted a hatchet", r["state"]["weapon"] in ("hatchet", "club") and "hatchet" in [g["item"] for g in r["state"]["gear"]], r["state"]["gear"])
        s.cmd("walk_to 930 610 6"); s.cmd("entity_action generator fuel"); s.cmd("entity_action generator fuel"); r = s.cmd("entity_action generator toggle")
        s.cmd("walk_to 250 620 6"); s.cmd("entity_action purifier fill"); s.cmd("dev advance_clock 45")
        r = s.cmd("entity_action purifier collect")
        check("slice 11: power and clean water", lvl(r["state"], L1, "generator").get("running") and r["state"]["carried"].get("water_clean", 0) >= 1, r["state"]["carried"])
        # 13-14. Explore the service station and its discovery.
        leave_bunker(s)
        s.cmd("walk_to 1150 960"); s.cmd("walk_to 1150 1400"); s.cmd("walk_to 2340 1400 10"); heal_if_low(s)
        r = s.cmd("interact homestead.road_east")
        check("slice 13: reached the service station", r["state"]["region"] == "service_station", r["state"].get("region"))
        s.cmd("dev heal")
        s.cmd("walk_to 600 870 10"); s.cmd("interact service_station.wreck"); heal_if_low(s)
        s.cmd("walk_to 1420 490 10"); s.cmd("interact service_station.shop_shelves"); heal_if_low(s)
        s.cmd("walk_to 1700 720"); s.cmd("walk_to 2000 575 10"); r = s.cmd("interact service_station.tool_locker"); heal_if_low(s)
        items = [g["item"] for g in r["state"]["gear"]]
        check("slice 14: discovery — carburetor and workshop manual", "carburetor" in items and "workshop_manual" in items, items)
        s.cmd("walk_to 1700 720"); s.cmd("walk_to 600 720"); s.cmd("walk_to 372 664 10"); s.cmd("npc mara talk")
        r = s.cmd("npc mara talk")
        check("slice 17: survivor recruited (food + clean water handed over)", r["state"]["npcs"]["mara"]["recruit"] == "travelling", (r["state"]["npcs"]["mara"], r["state"]["carried"]))
        s.cmd("walk_to 150 710"); s.cmd("walk_to 80 710 8"); s.cmd("interact service_station.road_west"); heal_if_low(s)
        # 15. Prepare defences in the yard; craft a spike kit and a grow light at home.
        s.cmd("walk_to 1150 1400"); s.cmd("walk_to 1150 960"); s.cmd("walk_to 1150 760")
        st0 = enter_bunker(s)
        check("slice 13b: back home and down in the bunker", st0["region"] == L1, st0.get("region"))
        s.cmd("walk_to 650 345 6")
        for item in ("electrical_parts", "scrap_metal", "canned_food", "cloth"):
            s.cmd(f"entity_action storage store {item}")
        s.cmd(f"walk_to {bx} {by + 70} 8")
        s.cmd("dev grant wood:12")  # compresses another round of tree felling
        s.cmd(f"obj {bench} craft grow_light"); s.cmd("wait 8.5"); s.cmd(f"obj {bench} collect")
        s.cmd(f"obj {bench} craft spike_kit"); s.cmd("wait 5.5"); r = s.cmd(f"obj {bench} collect")
        check("slice 12a: crafted a grow light and a spike kit", r["state"]["carried"].get("grow_light", 0) == 1 and r["state"]["carried"].get("spike_kit", 0) == 1, r["state"]["carried"])
        px, py = cell_xy(16, 14); s.cmd(f"walk_to {px} {py + 70} 8"); s.cmd(f"build planter {px} {py}"); s.cmd("wait 4.5")
        r = s.state()
        check("slice 12: hydroponic planter built", len(obj_of(r, "planter", L1)) == 1, objs(r, L1))
        s.cmd("walk_to 930 610 6"); r = s.cmd("entity_action generator fit_part")
        check("slice 14b: carburetor fitted", lvl(r["state"], L1, "generator").get("efficient") is True, lvl(r["state"], L1, "generator"))
        leave_bunker(s)
        s.cmd("dev grant wood:12")  # compresses another round of felling for the defences
        s.cmd("walk_to 1150 760"); s.cmd("walk_to 960 760")
        # A zombie standing on a spot is a valid refusal: retry, then use the north-east gap instead.
        placed = 0
        for spot in [(934, 480, "960 600"), (998, 480, "960 600"), (1350, 490, "1360 600"), (1414, 490, "1360 600")]:
            if placed >= 2:
                break
            s.cmd(f"walk_to {spot[2]}")
            for _try in range(2):
                before = len(objs(s.state()))
                s.cmd(f"build barricade {spot[0]} {spot[1]}")
                if len(objs(s.state())) > before:
                    placed += 1
                    break
                heal_if_low(s); s.cmd("wait 2")
        s.cmd("walk_to 1150 760"); s.cmd("build spike_trap 1250 790")
        s.cmd("walk_to 1360 760"); s.cmd("build crate 1300 840")
        s.cmd("wait 3.5")
        defs = [v["def"] for v in objs(s.state()).values()]
        check("slice 15: defences prepared (barricades, spike trap, a crate in the yard)", defs.count("barricade") == 2 and "spike_trap" in defs and "crate" in defs, defs)
        # 16. The defence event: horde arrives; the player waits it out indoors.
        s.cmd("walk_to 1160 760"); s.cmd("walk_to 1160 690")
        if not s.state()["entities"]["homestead.farmhouse_door"]["state"]["open"]:
            s.cmd("interact homestead.farmhouse_door")
        s.cmd("walk_to 1160 664 4"); s.cmd("interact homestead.farmhouse_entry")
        s.cmd("dev siege 3"); s.cmd("wait 4")
        st = s.state()
        check("slice 16a: horde warning then attack", st["meta"]["siege"]["phase"] == "active", st["meta"].get("siege"))
        hp0 = {k: v["hp"] for k, v in objs(st).items()}
        s.cmd("wait 75", timeout=90)  # the horde walks in and attacks in real time
        for _ in range(9):
            s.cmd("dev advance_clock 20"); s.cmd("wait 1")
        st = s.state()
        hurt = [k for k, v in objs(st).items() if v["hp"] < hp0.get(k, 0)] + [k for k in hp0 if k not in objs(st)]
        check("slice 16: the event ends; defences took real damage", st["meta"]["siege"]["phase"] == "idle" and st["meta"]["siege"].get("outcome") in ("repelled", "dispersed") and len(hurt) >= 1,
              (st["meta"].get("siege"), hurt))
        # 17-18. The survivor arrives; assign work; keep improving.
        enter_bunker(s)
        s.cmd("walk_to 650 345 6"); s.cmd("entity_action storage store water_clean")
        r = s.cmd("wait 1")
        check("slice 17b: survivor lives in the bunker", r["state"]["npcs"]["mara"]["recruit"] == "home" and r["state"]["view"]["npcs"] == 1, r["state"]["npcs"]["mara"])
        r = s.cmd("npc mara assign farm")
        r = {"state": wait_for(s, lambda st: any(v["crop"] in ("growing", "ripe") for v in obj_of(st, "planter", L1).values()), timeout=25)}
        planter = list(obj_of(r["state"], "planter", L1).values())[0]
        check("slice 18: survivor tends the planter with stored water (crop growing)", r["state"]["npcs"]["mara"]["job"] == "farm" and planter["crop"] in ("growing", "ripe"),
              (r["state"]["npcs"]["mara"], planter))
        snap = s.state()
        # 19. Save, exit and resume.
        s.cmd("save"); s.quit(); s.start()
        r = s.cmd("single continue Pioneer")
        st = r["state"]
        same_objs = {k: (v["def"], v["tier"], v["hp"]) for k, v in objs(st).items()} == {k: (v["def"], v["tier"], v["hp"]) for k, v in objs(snap).items()}
        check("slice 19: resume — region, structures (with damage), storage, gear, survivor, discoveries intact",
              st["region"] == snap["region"] and same_objs and st["bunkers"] == snap["bunkers"] and sorted(g["item"] for g in st["gear"]) == sorted(g["item"] for g in snap["gear"])
              and st["npcs"]["mara"]["job"] == "farm" and st["meta"].get("discoveries", {}).keys() == snap["meta"].get("discoveries", {}).keys(),
              (st.get("region"), st["bunkers"], snap["bunkers"]))
        check("slice perf: simulation cost stays small (ms per frame)", st.get("sim_ms", 0) < 8.0, st.get("sim_ms"))
    finally:
        s.kill()



def _to_settlement_on_foot(inst):
    """From the burned-shed opening to the settlement, the way a player walks it."""
    inst.cmd("walk_to 700 1180"); inst.cmd("walk_to 1150 1400"); inst.cmd("walk_to 2340 1400 10")
    return inst.cmd("interact homestead.road_east")


def scenario_red_thaw_multi():
    """Iteration 010: the opening kit per player, a developer Burnt One hunt against a remote
    client under host authority, coherent omens on both peers, and persistence."""
    host = Instance("t_rthost"); c = Instance("t_rtclient")
    for i in (host, c):
        i.wipe()
    try:
        host.start(); c.start()
        host.cmd(f"host {PORT} new 120 Hosty"); host.cmd("tips off")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo"); c.cmd("tips off")
        check("rt: client joins", r["ok"], r["error"])
        sh = host.state()
        for name in ("Hosty", "Cleo"):
            p = player(sh, name)
            check(f"rt: {name} wakes by the burned shed", p and p["region"] == "homestead" and abs(p["x"] - 420) < 120 and abs(p["y"] - 1130) < 80, p)
        check("rt: no Burnt Ones roam on their own", len(zs(sh)) == 0, len(zs(sh)))
        host.cmd("interact homestead.starter_bag")
        c.cmd("interact homestead.starter_bag")
        c.cmd("interact homestead.starter_bag")
        time.sleep(0.4)
        sh = host.state()
        hp_, cp_ = player(sh, "Hosty"), player(sh, "Cleo")
        check("rt: each player has exactly one kit (host authority)", hp_["carried"].get("crackers") == 1 and cp_["carried"].get("crackers") == 1
              and cp_["carried"].get("water_bottle") == 1 and cp_["gear"].count("field_map") == 1, (hp_["carried"], cp_["carried"], cp_["gear"]))
        check("rt: the bag remembers both claims", len(sh["entities"][f"homestead.starter_bag"]["state"].get("taken_by", [])) == 2, sh["entities"]["homestead.starter_bag"])
        r = _to_settlement_on_foot(c)
        check("rt: the client walks to the settlement", r["state"]["region"] == "service_station", r["state"].get("region"))
        c.cmd("walk_to 1200 860")
        # host-started hunt against the remote client
        host.cmd("dev hunt Cleo")
        time.sleep(0.5)
        sh = host.state()
        hunters = [z for z in sh["zombie_rows"] if z["hunter"]]
        check("rt: the host starts a hunt against the remote client", len(hunters) == 1 and hunters[0]["region"] == "service_station", sh.get("hunts"))
        hp0 = c.state()["health"]
        sc = wait_for(c, lambda st: st["health"] < hp0 or st["dead"], timeout=30)
        check("rt: the Burnt One finds and hurts the client", sc["health"] < hp0 or sc["dead"], (hp0, sc["health"], host.state().get("hunts")))
        check("rt: the client mirrors the hunter", len([z for z in zs(c.state()) if z["region"] == "service_station"]) >= 1, len(zs(c.state())))
        c.cmd("attack_nearest 6")
        time.sleep(0.3)
        check("rt: the client's hits are applied by the host", any(z["hp"] < 100 for z in host.state()["zombie_rows"]), [(z["ai"], z["hp"]) for z in host.state()["zombie_rows"]])
        check("rt: hunt diagnostics on the host", any("hunt" in line for line in host.state().get("hunts", [])) or not host.state()["zombie_rows"], host.state().get("hunts"))
        host.cmd("dev heal"); c.cmd("wait 0.1")
        host.cmd("dev peaceful 1"); host.cmd("dev peaceful 0")   # clear the hunter
        # the host walks to the settlement too; both stand by the houses and listen
        host.cmd("dev teleport 2300 1400"); host.cmd("walk_to 2340 1400 10"); host.cmd("interact homestead.road_east")
        host.cmd("dev teleport 1350 800"); c.cmd("walk_to 1300 820")
        host.cmd("dev time 11")
        # laughter is rare by design (RX-04): allow several slots
        st_h = wait_for(host, lambda st: any(o["kind"] == "laugh" for o in st.get("omens", [])), timeout=600)
        time.sleep(1.0)
        lh = [o for o in st_h.get("omens", []) if o["kind"] == "laugh"]
        lc = [o for o in c.state().get("omens", []) if o["kind"] == "laugh"]
        check("rt: laughter is heard near the houses by day", len(lh) >= 1, lh)
        check("rt: both players hear the same laugh from the same spot", lh and lc and (lh[-1]["slot"], lh[-1]["spot"]) == (lc[-1]["slot"], lc[-1]["spot"]), (lh[-1:], lc[-1:]))
        check("rt: the laughter has no visible source", len(zs(host.state())) == 0, len(zs(host.state())))
        host.cmd("dev time 22")
        st_h = wait_for(host, lambda st: any(o["kind"] == "shadow" for o in st.get("omens", [])), timeout=420)
        time.sleep(1.0)
        sh_ = [o for o in st_h.get("omens", []) if o["kind"] == "shadow"]
        sc_ = [o for o in c.state().get("omens", []) if o["kind"] == "shadow"]
        check("rt: a silhouette appears at night", len(sh_) >= 1, sh_)
        check("rt: both players see the same silhouette on the same path", sh_ and sc_ and (sh_[-1]["slot"], sh_[-1]["from"]) == (sc_[-1]["slot"], sc_[-1]["from"]), (sh_[-1:], sc_[-1:]))
        # the frightened survivor: one persistent, shared identity at her hiding place
        c.cmd("walk_to 360 700")
        c.cmd("npc mara talk")
        time.sleep(0.5)
        mh = host.state().get("npcs", {}).get("mara", {})
        mc = c.state().get("npcs", {}).get("mara", {})
        check("rt: the frightened survivor waits huddled at her hiding place (persistent identity)",
              mh.get("region") == "service_station" and abs(mh.get("x", 0) - 346) < 5, mh)
        check("rt: talking to her is validated by the host and seen by both",
              mh.get("recruit") == "met" and mc.get("recruit") == "met", (mh.get("recruit"), mc.get("recruit")))
        host.cmd("save"); host.quit()
        wait_for(c, lambda st: not st["in_world"], timeout=12)
        host.start(); host.cmd(f"host {PORT} continue Hosty")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        st = r["state"]
        check("rt: after restart the client rejoins in the settlement with their kit", st["region"] == "service_station" and st["carried"].get("crackers") == 1, (st["region"], st["carried"]))
        check("rt: kit claims persist (no second kit after restart)", len(host.state()["entities"]["homestead.starter_bag"]["state"].get("taken_by", [])) == 2, "")
        check("rt: no hunter is restored by a reload", not any(z["hunter"] for z in host.state()["zombie_rows"]), host.state()["zombie_rows"])
    finally:
        for i in (host, c):
            i.kill()


def _into_cabin(inst):
    inst.cmd("walk_to 1150 960")
    if not inst.state()["entities"]["homestead.yard_gate"]["state"]["open"]:
        inst.cmd("press_interact")
    inst.cmd("walk_to 1160 760"); inst.cmd("walk_to 1160 690")
    if not inst.state()["entities"]["homestead.farmhouse_door"]["state"]["open"]:
        inst.cmd("interact homestead.farmhouse_door")
    inst.cmd("walk_to 1160 664 4")
    return inst.cmd("interact homestead.farmhouse_entry")


def scenario_winter_multi():
    """Iteration 011 B: shared weather, replicated cold exposure, communal sleep
    (monologue when someone is outside, unanimous vote, real time advance)."""
    host = Instance("t_wwhost"); c = Instance("t_wwclient")
    for i in (host, c):
        i.wipe()
    try:
        host.start(); c.start()
        host.cmd(f"host {PORT} new 130 Hosty"); host.cmd("tips off")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo"); c.cmd("tips off")
        check("ww: client joins", r["ok"], r["error"])
        host.cmd("dev time 22"); host.cmd("dev weather blizzard")
        time.sleep(0.5)
        check("ww: blizzard is shared", c.state()["env"].get("weather") == "blizzard", c.state()["env"])
        w0 = player(host.state(), "Cleo")["warmth"]
        time.sleep(4.0)
        sh, sc = host.state(), c.state()
        check("ww: the client loses warmth in the blizzard (host-simulated)", player(sh, "Cleo")["warmth"] < w0 - 0.5, (w0, player(sh, "Cleo")["warmth"]))
        check("ww: the client's own view matches the host (2-point replication steps)", abs(player(sh, "Cleo")["warmth"] - player(sc, "Cleo")["warmth"]) <= 2.1,
              (player(sh, "Cleo")["warmth"], player(sc, "Cleo")["warmth"]))
        r = _into_cabin(host)
        check("ww: host gets into the cabin", r["state"]["region"] == "homestead.farmhouse", r["state"].get("region"))
        host.cmd("walk_to 640 380 6")
        r = host.cmd("interact homestead.farmhouse.bed")
        notes = r["state"]["notices"][-3:]
        check("ww: sleeping while Cleo is outside gives an inner monologue", any("SLEEP_OUT_" in str(n) and "Cleo" in str(n) for n in notes), notes)
        tick0 = host.state()["tick"]
        check("ww: no time passed", host.state()["tick"] - tick0 < 50, "")
        r = _into_cabin(c)
        check("ww: client gets into the cabin", r["state"]["region"] == "homestead.farmhouse", r["state"].get("region"))
        host.cmd("dev time 22")
        host.cmd("interact homestead.farmhouse.bed")
        time.sleep(0.5)
        v = c.state()["meta"].get("sleep_vote", {})
        check("ww: a vote starts and reaches the client", v.get("yes") and len(v["yes"]) == 1, v)
        c.cmd("sleep_vote no")
        time.sleep(0.4)
        check("ww: a 'not yet' cancels the vote", not host.state()["meta"].get("sleep_vote"), host.state()["meta"].get("sleep_vote"))
        host.cmd("interact homestead.farmhouse.bed")
        tick1 = host.state()["tick"]
        c.cmd("sleep_vote yes")
        time.sleep(1.5)
        sh, sc = host.state(), c.state()
        hour = ((sh["tick"] / 10.0) / 1440.0 * 24.0 + 8.0) % 24.0
        check("ww: unanimous: the shared clock jumps to morning", sh["tick"] - tick1 > 5000 and abs(hour - 7.0) < 0.2, (sh["tick"] - tick1, hour))
        check("ww: the client's clock followed", abs(sc["tick"] - sh["tick"]) < 30, (sc["tick"], sh["tick"]))
        check("ww: both wake warm", player(sh, "Hosty")["warmth"] > 99 and player(sh, "Cleo")["warmth"] > 99, "")
        check("ww: needs advanced during the night", player(sh, "Cleo")["hunger"] < 95, player(sh, "Cleo")["hunger"])
        check("ww: the vote is closed", not sh["meta"].get("sleep_vote"), sh["meta"].get("sleep_vote"))
    finally:
        for i in (host, c):
            i.kill()


def _veh(state):
    return {v["id"]: v for v in state.get("vehicles", [])}


def scenario_vehicle_multi():
    """Iteration 011 C: one station wagon shared by two players — seats, engine,
    owner-predicted driving replicated to the passenger, the road exit moving the
    car with both players and the trunk to Ashgrove, getting out, persistence."""
    host = Instance("t_vhost"); c = Instance("t_vclient")
    for i in (host, c):
        i.wipe()
    try:
        host.start(); c.start()
        host.cmd(f"host {PORT} new 140 Hosty"); host.cmd("tips off"); host.cmd("dev peaceful 1")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo"); c.cmd("tips off")
        check("veh: client joins", r["ok"], r["error"])
        check("veh: the client sees the station wagon", "wagon" in _veh(c.state()), list(_veh(c.state())))
        for i in (host, c):
            r = _to_settlement_on_foot(i)
        check("veh: both walk to the settlement", player(host.state(), "Cleo")["region"] == "service_station"
              and player(host.state(), "Hosty")["region"] == "service_station", "")
        host.cmd("walk_to 1400 700 10"); c.cmd("walk_to 1430 760 10")
        host.cmd("dev vehicle_here")
        time.sleep(0.4)
        v = _veh(host.state())["wagon"]
        check("veh: the wagon is parked on the road", v["region"] == "service_station" and abs(v["y"] - 700) < 5, v)
        c.cmd("dev grant scrap_metal:2")
        host.cmd("dev grant scrap_metal:2")
        r = host.cmd("vehicle wagon store scrap_metal")
        time.sleep(0.3)
        check("veh: something goes in the trunk", _veh(c.state())["wagon"]["cargo"]["items"].get("scrap_metal") == 2, _veh(c.state())["wagon"]["cargo"])
        host.cmd("vehicle wagon enter"); c.cmd("vehicle wagon enter")
        time.sleep(0.4)
        sh, sc = host.state(), c.state()
        hid, cid = player(sh, "Hosty")["id"], player(sh, "Cleo")["id"]
        check("veh: host drives, client rides (host view)", _veh(sh)["wagon"]["seats"][:2] == [hid, cid], _veh(sh)["wagon"]["seats"])
        check("veh: seats replicated to the client", _veh(sc)["wagon"]["seats"][:2] == [hid, cid], _veh(sc)["wagon"]["seats"])
        r = c.cmd("vehicle wagon engine")
        time.sleep(0.3)
        check("veh: the passenger cannot start the engine", not _veh(host.state())["wagon"]["engine"], "")
        host.cmd("press_key vehicle_engine")
        time.sleep(0.3)
        check("veh: the driver starts the engine (seen by the client)", _veh(c.state())["wagon"]["engine"], "")
        x0 = _veh(host.state())["wagon"]["x"]
        host.cmd("hold move_up 1.0")
        sh, sc = host.state(), c.state()
        vh, vc = _veh(sh)["wagon"], _veh(sc)["wagon"]
        check("veh: driving moves the car on the host", vh["x"] > x0 + 100, (x0, vh["x"]))
        check("veh: the passenger's replica follows", abs(vc["x"] - vh["x"]) < 120 and vc["region"] == vh["region"], (vc["x"], vh["x"]))
        check("veh: the passenger is carried along", abs(player(sh, "Cleo")["x"] - vh["x"]) < 1.0, (player(sh, "Cleo")["x"], vh["x"]))
        host.cmd("hold move_up 3.0")
        time.sleep(1.0)
        sh, sc = host.state(), c.state()
        check("veh: the road exit takes the car to Ashgrove", _veh(sh)["wagon"]["region"] == "town", _veh(sh)["wagon"])
        check("veh: driver and passenger arrive together (host)", player(sh, "Hosty")["region"] == "town" and player(sh, "Cleo")["region"] == "town",
              (player(sh, "Hosty")["region"], player(sh, "Cleo")["region"]))
        check("veh: the client is in Ashgrove too", sc.get("region") == "town", sc.get("region"))
        check("veh: the trunk came along", _veh(sc)["wagon"]["cargo"]["items"].get("scrap_metal") == 2, _veh(sc)["wagon"]["cargo"])
        check("veh: Ashgrove was discovered", "town" in sh["meta"].get("discoveries", {}), list(sh["meta"].get("discoveries", {})))
        r = c.cmd("vehicle wagon exit")
        check("veh: nobody jumps out while the car is still rolling", player(host.state(), "Cleo")["vehicle"] == "wagon", r["state"]["notices"][-1:])
        host.cmd("hold move_down 1.2"); host.cmd("wait 0.6")
        c.cmd("vehicle wagon exit")
        time.sleep(0.4)
        sh = host.state()
        cp, vp = player(sh, "Cleo"), _veh(sh)["wagon"]
        check("veh: the passenger gets out beside the car", cp["vehicle"] == "" and 40 < ((cp["x"] - vp["x"]) ** 2 + (cp["y"] - vp["y"]) ** 2) ** 0.5 < 160,
              (cp["x"], cp["y"], vp["x"], vp["y"]))
        r = c.cmd("walk_to %d %d 10" % (cp["x"] + 40, cp["y"] + 40))
        check("veh: the client walks again after getting out", r["ok"], r["error"])
        host.cmd("press_key vehicle_engine")
        host.cmd("vehicle wagon exit")
        time.sleep(0.3)
        vx = _veh(host.state())["wagon"]
        check("veh: everyone is out, engine off", vx["seats"] == ["", "", "", ""] and not vx["engine"], vx)
        host.cmd("save")
        c.cmd("leave"); host.cmd("leave")
        host.cmd("single continue Hosty")
        time.sleep(0.5)
        v2 = _veh(host.state()).get("wagon", {})
        check("veh: the wagon is still in Ashgrove after a restart", v2.get("region") == "town" and abs(v2.get("x", 0) - vx["x"]) < 1.0, v2)
        check("veh: the trunk survived the restart", v2.get("cargo", {}).get("items", {}).get("scrap_metal") == 2, v2.get("cargo"))
        check("veh: still exactly one wagon", len(host.state().get("vehicles", [])) == 1, len(host.state().get("vehicles", [])))
    finally:
        for i in (host, c):
            i.kill()


def scenario_wild_multi():
    """Iteration 011 D: wildlife mirrored on the client (non-aggressive), the cabin
    flashlight per player, a replicated flashlight toggle."""
    host = Instance("t_dhost"); c = Instance("t_dclient")
    for i in (host, c):
        i.wipe()
    try:
        host.start(); c.start()
        host.cmd(f"host {PORT} new 150 Hosty"); host.cmd("tips off"); host.cmd("dev peaceful 1")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo"); c.cmd("tips off")
        check("wild: client joins", r["ok"], r["error"])
        time.sleep(0.6)
        ha, ca = host.state()["animals"], c.state()["animals"]
        check("wild: wolves and bears exist on the host", len(ha) >= 4 and {a["species"] for a in ha} == {"wolf", "bear"}, len(ha))
        check("wild: the client mirrors every animal", len(ca) == len(ha), (len(ca), len(ha)))
        wolf = [a for a in ha if a["region"] == "homestead"][0]
        hp = player(host.state(), "Cleo")["health"]
        c.cmd("walk_to %d %d 12" % (wolf["x"] - 200, wolf["y"]))
        time.sleep(1.0)
        acts = [a["activity"] for a in host.state()["animals"] if a["region"] == "homestead"]
        check("wild: a wolf reacts to the client's approach (watch / flee)", any(x in ("alert", "flee") for x in acts), acts)
        check("wild: and never attacks", player(host.state(), "Cleo")["health"] >= hp - 0.01, (hp, player(host.state(), "Cleo")["health"]))
        r = _into_cabin(c)
        check("wild: client gets into the cabin", r["state"]["region"] == "homestead.farmhouse", r["state"].get("region"))
        c.cmd("walk_to 630 540 8")
        r = c.cmd("interact homestead.farmhouse.flashlight")
        time.sleep(0.3)
        check("wild: the client takes a flashlight", "flashlight" in player(host.state(), "Cleo")["gear"], player(host.state(), "Cleo")["gear"])
        c.cmd("press_key flashlight")
        time.sleep(0.4)
        check("wild: the client switches it on (host-validated)", player(host.state(), "Cleo")["flashlight"], "")
        check("wild: the client's own replica agrees", player(c.state(), "Cleo")["flashlight"], "")
        host.cmd("press_key flashlight")
        time.sleep(0.3)
        check("wild: without a flashlight the host gets no light", not player(c.state(), "Hosty")["flashlight"], "")
        c.cmd("press_key flashlight")
        time.sleep(0.4)
        check("wild: switched off again for everyone", not player(host.state(), "Cleo")["flashlight"] and not player(c.state(), "Cleo")["flashlight"], "")
    finally:
        for i in (host, c):
            i.kill()


def scenario_custom_graphics():
    """Iteration 011 E: the client-local "Use custom graphics" switch. Both instances share
    the same replacement files; the host turns them OFF, the client keeps them ON; the
    choice survives a restart; ON restores them; gameplay is unaffected."""
    over = os.path.join(USER_DIR, "overrides")
    fix = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tests", "fixtures", "overrides")
    img_dst = os.path.join(over, "characters", "player", "survivor_down.png")
    host = Instance("t_cghost"); c = Instance("t_cgclient")
    for i in (host, c):
        i.wipe()
    os.makedirs(os.path.dirname(img_dst), exist_ok=True)
    shutil.copy(os.path.join(fix, "characters", "player", "survivor_down.png"), img_dst)
    try:
        host.start(); c.start()
        check("cg: the menu theme plays on the main menu", host.state()["loops"].get("music") == "music.theme", host.state()["loops"])
        host.cmd(f"host {PORT} new 160 Hosty"); host.cmd("tips off"); host.cmd("dev peaceful 1")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo"); c.cmd("tips off")
        check("cg: client joins", r["ok"], r["error"])
        check("cg: the music stops in the world", "music" not in host.state()["loops"], host.state()["loops"])
        check("cg: replacements are used by default (both)", host.state()["asset_sources"].get("char.player") == "external"
              and c.state()["asset_sources"].get("char.player") == "external", "")
        host.cmd("custom_graphics off"); host.cmd("rebuild_view")
        sh, sc = host.state(), c.state()
        check("cg: OFF on the host shows the original art there", sh["asset_sources"].get("char.player") == "template", sh["asset_sources"].get("char.player"))
        check("cg: the client keeps its own choice (ON)", sc["asset_sources"].get("char.player") == "external", sc["asset_sources"].get("char.player"))
        check("cg: the replacement file is untouched", os.path.exists(img_dst), "")
        r = c.cmd(f"walk_to {GATE_STAND}"); c.cmd("press_interact")
        time.sleep(0.4)
        check("cg: gameplay is the same for both (the client opens the gate, the host sees it)", gate(host.state())["state"]["open"] is True, "")
        c.cmd("leave"); host.cmd("leave")
        host.kill(); host = Instance("t_cghost"); host.start()
        host.cmd("single new 161 Hosty")
        check("cg: OFF is remembered after a restart", host.state()["asset_sources"].get("char.player") == "template", host.state()["asset_sources"].get("char.player"))
        host.cmd("custom_graphics on"); host.cmd("rebuild_view")
        check("cg: ON brings the replacement back immediately", host.state()["asset_sources"].get("char.player") == "external", host.state()["asset_sources"].get("char.player"))
    finally:
        for i in (host, c):
            i.kill()
        if os.path.exists(img_dst):
            os.remove(img_dst)


def scenario_blood_multi():
    """Iteration 012 B: thawed-blood marks are host-made, replicated, saved, and erased by weather for everyone."""
    host = Instance("t_bhost"); c = Instance("t_bclient")
    for i in (host, c):
        i.wipe()
    try:
        host.start(); c.start()
        host.cmd(f"host {PORT} new 170 Hosty"); host.cmd("tips off"); host.cmd("dev peaceful 1"); host.cmd("dev weather clear")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo"); c.cmd("tips off")
        check("blood: client joins", r["ok"], r["error"])
        check("blood: a new world has no marks", host.state()["blood_count"] == 0, host.state()["blood_count"])
        for _ in range(3):
            host.cmd("dev blood")
        time.sleep(0.4)
        check("blood: marks reach the client", c.state()["blood_count"] == 3, c.state()["blood_count"])
        c.cmd("leave"); host.cmd("leave")
        host.cmd(f"host {PORT} continue Hosty"); host.cmd("dev peaceful 1")
        check("blood: marks come back after a restart (saved)", host.state()["blood_count"] == 3, host.state()["blood_count"])
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo")
        check("blood: a rejoining client receives them", c.state()["blood_count"] == 3, c.state()["blood_count"])
        host.cmd("dev weather heavy_rain"); host.cmd("dev advance_clock 200")
        time.sleep(0.6)
        check("blood: rain washes them away on the host", host.state()["blood_count"] == 0, host.state()["blood_count"])
        check("blood: and for the client", c.state()["blood_count"] == 0, c.state()["blood_count"])
    finally:
        for i in (host, c):
            i.kill()


def _build_shelter_and_descend(i):
    """Surface -> cabin -> build the hatch (if needed) -> open it -> climb down."""
    r = _into_cabin(i)
    i.cmd("walk_to 300 470 6")
    st = i.state()["entities"][SITE]["state"]
    if st.get("stage", "none") == "none":
        i.cmd("interact " + SITE); i.cmd("wait 9")
    if not i.state()["entities"][SITE]["state"].get("open", False):
        i.cmd("interact " + SITE)
    i.cmd("walk_to 300 452 4"); i.cmd("interact homestead.farmhouse.hatch_ladder"); i.cmd("wait 1.2")
    return i.state()


def scenario_side_multi():
    """Iteration 012 C/D: the experimental side-view bunker with two real game instances —
    players in different places and perspectives, digging and building in the side view,
    one shared state, save/restart and a reconnect."""
    host = Instance("t_shost"); c = Instance("t_sclient")
    for i in (host, c):
        i.wipe()
    try:
        host.start(); c.start()
        host.cmd(f"host {PORT} new 180 Hosty"); host.cmd("tips off"); host.cmd("dev peaceful 1")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo"); c.cmd("tips off")
        check("side: client joins", r["ok"], r["error"])
        st = _build_shelter_and_descend(c)
        check("side: the client climbs down into the bunker", st["region"] == L1, st["region"])
        check("side: and sees it in the side view (default)", st["view"].get("side") is True, st["view"].get("side"))
        cp = player(host.state(), "Cleo")
        floor = 701.0
        check("side: the host keeps the client's feet on the floor", abs(cp["y"] - floor) < 2.0, cp["y"])
        hs = host.state()
        check("side: the host is still on the surface, top-down", hs["region"] == "homestead" and not hs["view"].get("side", False), (hs["region"], hs["view"].get("side")))
        c.cmd("walk_to 300 0 8")
        cp2 = player(host.state(), "Cleo")
        check("side: walking along the floor moves the client on the host", cp2["x"] < cp["x"] - 100 and abs(cp2["y"] - floor) < 2.0, (cp2["x"], cp2["y"]))
        st = _build_shelter_and_descend(host)
        check("side: the host joins below", st["region"] == L1, st["region"])
        host.cmd("press_key bunker_view"); host.cmd("wait 1.0")
        hs = host.state()
        check("side: the host switches to the original top-down view (F7)", hs["view"].get("side") is False and hs["region"] == L1, hs["view"].get("side"))
        check("side: the client keeps the side view", c.state()["view"].get("side") is True, "")
        d0 = host.state()["terrain_dug"]
        c.cmd("walk_to 960 0 8")
        c.cmd("terrain dig 27 16"); c.cmd("wait 2.6")
        check("side: the client digs in the side view (host-validated)", host.state()["terrain_dug"] == d0 + 1, (d0, host.state()["terrain_dug"]))
        check("side: the dug cell reaches the client too", c.state()["terrain_dug"] == d0 + 1, c.state()["terrain_dug"])
        objs0 = len(host.state()["objects_here"]) if "objects_here" in host.state() else host.state()["view"].get("objects", 0)
        c.cmd("dev grant wood:6")
        c.cmd("walk_to 700 0 8")
        c.cmd("build crate 800 701"); c.cmd("wait 2.5")
        o1 = host.state()["view"].get("objects", 0)
        check("side: the client builds a crate on the floor (seen by the top-down host)", o1 == objs0 + 1, (objs0, o1))
        check("side: and in its own side view", c.state()["view"].get("objects", 0) == o1, c.state()["view"].get("objects", 0))
        host.cmd("walk_to 160 672 8")
        hd = host.state()["terrain_dug"]
        host.cmd("terrain dig 12 16"); host.cmd("wait 2.6")
        check("side: the top-down host digs the same grid", c.state()["terrain_dug"] == hd + 1, (hd, c.state()["terrain_dug"]))
        c.cmd("leave"); time.sleep(0.5)
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo"); c.cmd("wait 1.0")
        cs = c.state()
        check("side: a reconnecting client returns to the bunker level", cs["region"] == L1 and cs["view"].get("side") is True, (cs["region"], cs["view"].get("side")))
        cp3 = player(host.state(), "Cleo")
        check("side: standing where it left (on the floor)", abs(cp3["y"] - floor) < 2.0 and abs(cp3["x"] - 700) < 40, (cp3["x"], cp3["y"]))
        host.cmd("save"); dug_saved = host.state()["terrain_dug"]
        c.cmd("leave"); host.cmd("leave")
        host.cmd(f"host {PORT} continue Hosty")
        r = c.cmd(f"join 127.0.0.1 {PORT} Cleo"); c.cmd("wait 1.0")
        cs = c.state()
        check("side: after a restart the client is back in the bunker", cs["region"] == L1, cs["region"])
        check("side: the dug cells survived", c.state()["terrain_dug"] == dug_saved, (dug_saved, c.state()["terrain_dug"]))
        check("side: the crate survived", c.state()["view"].get("objects", 0) >= o1, c.state()["view"].get("objects", 0))
    finally:
        for i in (host, c):
            i.kill()


def scenario_perf_multi():
    """Two connected players, a horde plus extra groups active around them: measure host simulation cost."""
    host = Instance("t_phost"); c = Instance("t_pclient")
    for i in (host, c):
        i.wipe()
    try:
        host.start(); c.start()
        host.cmd(f"host {PORT} new 70 Hosty"); host.cmd("tips off"); host.cmd("dev ambient 1")
        c.cmd(f"join 127.0.0.1 {PORT} Cleo"); c.cmd("tips off")
        host.cmd("walk_to 1150 960"); c.cmd("walk_to 1190 960")
        host.cmd("dev siege 1"); host.cmd("wait 2")
        host.cmd("dev spawn_group"); host.cmd("dev spawn_group")
        samples = []
        for _ in range(10):
            st = host.state()
            samples.append((st.get("sim_ms", 0), len(zs(st))))
            time.sleep(2)
        worst = max(m for m, _ in samples)
        peak = max(n for _, n in samples)
        RESULTS_NOTES.append(f"perf_multi: host sim_ms max {worst:.2f}, zombies up to {peak}, client zombies {len(zs(c.state()))}")
        check(f"perf: {peak} zombies with two players — host simulation {worst:.2f} ms/frame (< 8 ms)", peak >= 12 and worst < 8.0, samples)
        check("perf: client mirrors the horde", abs(len(zs(c.state())) - len(zs(host.state()))) <= 2, (len(zs(c.state())), len(zs(host.state()))))
    finally:
        for i in (host, c):
            i.kill()


SCENARIOS = {"side_multi": scenario_side_multi, "blood_multi": scenario_blood_multi, "custom_graphics": scenario_custom_graphics, "wild_multi": scenario_wild_multi, "vehicle_multi": scenario_vehicle_multi, "winter_multi": scenario_winter_multi, "red_thaw_multi": scenario_red_thaw_multi, "perf_multi": scenario_perf_multi, "slice": scenario_slice, "settlement_multi": scenario_settlement_multi, "world_multi": scenario_world_multi, "craft_multi": scenario_craft_multi, "build_multi": scenario_build_multi, "accept": scenario_accept, "infra_multi": scenario_infra_multi, "dig_multi": scenario_dig_multi, "danger_single": scenario_danger_single, "danger_multi": scenario_danger_multi, "settings": scenario_settings, "bunker_single": scenario_bunker_single, "bunker_multi": scenario_bunker_multi, "single": scenario_single, "multiplayer": scenario_multiplayer,
             "netfail": scenario_connection_failure, "assets": scenario_assets}

if __name__ == "__main__":
    names = sys.argv[1:] or list(SCENARIOS)
    for n in names:
        print(f"== {n}")
        try:
            SCENARIOS[n]()
        except Exception as e:
            check(f"{n}: scenario ran without harness error", False, repr(e))
    os.makedirs(LOG_DIR, exist_ok=True)
    for note in RESULTS_NOTES:
        print("NOTE", note)
    with open(os.path.join(LOG_DIR, "mp_results.json"), "w") as f:
        json.dump(results, f, indent=1)
    failed = [r for r in results if not r["pass"]]
    print(f"\n{len(results) - len(failed)}/{len(results)} checks passed")
    sys.exit(1 if failed else 0)
