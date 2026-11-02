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


SCENARIOS = {"settings": scenario_settings, "single": scenario_single, "multiplayer": scenario_multiplayer,
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
