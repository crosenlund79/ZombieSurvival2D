#!/usr/bin/env python3
"""Real multi-process acceptance tests for Aftergrowth.

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
        with open(a.inbox, "a") as f: f.write(f"interact {GATE}\n")
        with open(b.inbox, "a") as f: f.write(f"interact {GATE}\n")
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
    s = Instance("t_assets"); s.wipe()
    for p in (img_dst, snd_dst):
        if os.path.exists(p):
            os.remove(p)
    s.start()
    try:
        r = s.cmd("single new 5 Painter")
        srcs = r["state"]["asset_sources"]
        check("assets: template used by default", srcs.get("char.player") == "template", srcs)
        p0 = player(r["state"], "Painter")
        os.makedirs(os.path.dirname(img_dst), exist_ok=True)
        os.makedirs(os.path.dirname(snd_dst), exist_ok=True)
        shutil.copy(os.path.join(fix, "characters", "player", "survivor_down.png"), img_dst)
        shutil.copy(os.path.join(fix, "audio", "world", "door_open.wav"), snd_dst)
        r = s.cmd("reload_assets")
        r = s.cmd(f"walk_to {GATE_STAND}")
        r = s.cmd("press_interact")   # door sound requested after reload
        srcs = r["state"]["asset_sources"]
        check("assets: external image override used", srcs.get("char.player") == "external", srcs)
        check("assets: external sound override used", srcs.get("sfx.door_open") == "external", srcs)
        check("assets: gameplay unaffected by art swap (gate still works)", gate(r["state"])["state"]["open"] is True, gate(r["state"]))
        # Corrupt override is rejected -> template.
        shutil.copy(os.path.join(fix, "characters", "player", "corrupt_survivor_down.png"), img_dst)
        r = s.cmd("reload_assets")
        r = s.cmd("rebuild_view")
        check("assets: corrupt PNG rejected, template used", r["state"]["asset_sources"].get("char.player") == "template", r["state"]["asset_sources"])
        os.remove(img_dst); os.remove(snd_dst)
        r = s.cmd("reload_assets")
        r = s.cmd("press_interact")   # closes (door_close)
        r = s.cmd("press_interact")   # opens again (door_open resolved after reload)
        srcs = r["state"]["asset_sources"]
        check("assets: removing override restores template (image)", srcs.get("char.player") == "template", srcs)
        check("assets: removing override restores template (sound)", srcs.get("sfx.door_open") == "template", srcs)
    finally:
        s.kill()
        for p in (img_dst, snd_dst):
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
        check("mpb: host restarts on the surface", r["ok"] and r["state"]["region"] == "homestead", r["state"].get("region"))
        r = a.cmd(f"join 127.0.0.1 {PORT} Alice")
        check("mpb: client rejoins directly on level -2", r["ok"] and r["state"]["region"] == L2 and r["state"]["view"]["region"] == L2, r["state"].get("region"))
        check("mpb: rejoined client sees persisted bunker", r["state"]["bunkers"][SITE]["levels"] == [-3, -2, -1] and lvl(r["state"], L1, "support_1").get("stage") == "reinforced", r["state"]["bunkers"])
        a.cmd("walk_to 760 600"); r = a.cmd("press_interact")
        check("mpb: client descends to -3 after restart", r["state"]["region"] == L3, r["state"].get("region"))
    finally:
        for i in (host, a):
            i.kill()


SCENARIOS = {"settings": scenario_settings, "bunker_single": scenario_bunker_single, "bunker_multi": scenario_bunker_multi, "single": scenario_single, "multiplayer": scenario_multiplayer,
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
    with open(os.path.join(LOG_DIR, "mp_results.json"), "w") as f:
        json.dump(results, f, indent=1)
    failed = [r for r in results if not r["pass"]]
    print(f"\n{len(results) - len(failed)}/{len(results)} checks passed")
    sys.exit(1 if failed else 0)
