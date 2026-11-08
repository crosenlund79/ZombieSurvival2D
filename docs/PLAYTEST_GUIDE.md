# Red Thaw — Playtest Guide (iteration 014; earlier systems from 001–013)

This guide is for playing the game and reporting problems. Technical details are in
[`guides/TESTING_AND_LAUNCH.md`](guides/TESTING_AND_LAUNCH.md). Every number in the game is a prototype
value, and the [design decision register](DESIGN_DECISIONS.md) lists what is still EXPLORING.

## 1. Getting started (Windows)

1. Install **Godot 4.7.2 (standard)**.
2. On GitHub, pick the branch **`iteration/013-scavengers-circuit`** and choose **Code → Download ZIP**.
3. Extract the ZIP, open Godot, choose **Import**, select `project.godot`, then **Import & Edit**. Press **F5**.
4. In the main menu:
   - **Single Player → New World** is the normal game. You wake by a burned shed with only a small bag.
   - **Single Player → Developer Test World** is a prepared world: a dug shelter, a running generator,
     a workbench, a planter, materials, tools and the survivor already at home. Use it to look at
     specific systems quickly. It is **not** a replacement for testing the normal game.

Two pieces of on-screen help:
- A small tip card explains each major mechanic the first time it matters. You can turn tips off in
  the guide.
- **H** opens the survival guide. It lists every topic and a progress checklist.

## 2. Controls

| Key | Action |
|---|---|
| WASD / arrows | Move; **Shift** sprints, which is noisy |
| E | Use what the prompt shows |
| R | Repair a damaged structure, or upgrade the hatch |
| F / left mouse | Swing what you hold |
| B | Build menu. Left click or E places; right click or Esc cancels |
| I / Tab | Inventory |
| Q / X | Drink (clean water or the large bottle) / eat |
| M | Map (or Read the field map in the inventory) |
| N | Settlement overview |
| K | Skills (Scavenging level, XP, search speed) |
| R (at the car) | Open the trunk |
| H | Survival guide |
| Esc | Menu. The world keeps running |
| F5 | Save (host) |
| F3 | Developer overlay |
| F12 | Screenshot |
| G | Engine on / off (in the driver's seat) |
| E (in a car) | Get out (stop first) · **R** beside the car opens the trunk |
| L | Flashlight on / off (when you carry one) |
| W / S (bunker, side view) | Climb ladders and timber scaffolding; with W/S held, E digs the ceiling / floor |
| F7 | Developer: bunker view side / top-down (comparison) |

## 3. What to try (Red Thaw)

**The opening.** Start a **New World**. You wake on the forest floor by a burned shed. Press **E** on the
bag beside you: it holds a large bottle of water, a pack of crackers and a map. Drink with **Q**, eat with
**X**, and open the map with **M** (or **Read** it in the inventory, **I**). Nothing explains itself.

**Find the cabin.** The map shows a hunter's cabin in the clearing to the east. Open the gate, enter the
cabin, and do what the farmhouse used to offer: mark and dig a shelter beneath it, climb down, dig and
reinforce, build, store, and run the generator, purifier and planter. All survival and bunker systems are
unchanged.

**The settlement.** Follow the road east (the right edge of the map) to the abandoned settlement. You
might hear something by day near the houses, and you might not. Nothing will be there. Someone is hiding
in the collapsed house on the left: speak to her softly with **E**. She may come to your shelter if you
bring her what she asks for. Search the houses, the shop and the workshop for supplies.

**Night.** Stay out after dark (F3 → *Night*) and watch the gaps between the houses, the road and the
trees. Sightings are brief and rare, and they are not fights.

**The Burnt Ones.** Nothing hunts you on its own in this build, because what starts a hunt is not decided
yet. F3 → **Start a Burnt One hunt (on me)** sends one after you. Check that:
- it arrives from out of sight and finds you
- it attacks (it draws back before it strikes) and you can fight it
- it loses you and picks up your trail again
- it never follows you into the cabin or the bunker
- it gives up after about 4 minutes

**Multiplayer.** A second player who joins wakes by the same bag and gets their own kit. Players can be
in different places: one in the bunker, one in the settlement.

## 3b. What to try (The World Awakens, iteration 011)

**Listen.** Make noise near a Burnt One (F3 → hunt, or chop a tree): it stops, turns and listens, and a
loud enough noise makes it screech. A few others nearby come to look. Watch them crouch, drop to all
fours and crawl, with sudden bursts. Look for tracks and blood in the snow behind them.

**Cold and weather.** The Warmth bar falls outside, faster at night and in a blizzard; a coat helps, the
cabin and bunker warm you up. Weather changes on its own (F3 or `dev weather <kind>` to force one):
fog, snow, heavy rain, blizzards, thunderstorms with lightning.

**Sleep.** Use the bed in the cabin (or a bedroll) in the evening. Alone you sleep at once. With a second
player outside, you only get a thought; with both inside, a "Ready to sleep?" vote decides.

**The station wagon.** It is parked at the abandoned settlement, key in the ignition. **E** to get in,
**G** to start, **W/S/A/D** to drive, **E** to get out (stop first). **R** beside it opens the trunk. Drive
off the east end of the road to reach **Ashgrove**; the west end leads back home. A second player can ride
along. At night, turn on the headlights by starting the engine.

**Ashgrove.** Search the grocery, pharmacy, hardware store, clothing store and garage (some spots were
emptied long ago). Force the hardware case for a flashlight. Enter the house on Main Street: its cellar
is a second base with storage and a bedroll, upgradeable like the cabin's.

**The map (M).** Your region is outlined in red; roads to places you have not found are marked; the car is
shown. At night the map darkens.

**Wildlife.** Wolves roam the snow east of the cabin, a bear south of the settlement. They watch you and
back away; they never attack.

**Flashlight.** Take one from the cabin table and press **L** at night.

**Custom graphics.** Settings → Assets → **Use custom graphics** switches your replacement pictures off
and on instantly, without touching your files.

## 3c. What to try (Shadows & Depth, iteration 012)

**Shapes in the dark.** Start a Burnt One hunt (F3) and look at them by day, with your flashlight, in a car's
headlights and in a lightning flash: you see dark human shapes — tall, hunched, heavy, limping — never faces or
clothes. They crouch, crawl and scramble as before.

**Red specks.** Burnt Ones that linger near warmth (the cabin, an idling car) thaw: a few small red drops may
mark where they stood. On a calm day you can notice them and choose another way; fog, blowing snow, falling snow
and rain hide or erase them. Their screeches are harder to hear in bad weather.

**The bunker from the side.** Climb down the hatch: the shelter is now a cross-section — earth layers, rooms,
floorboards, ceiling beams, the ladder up the shaft. Walk with A/D; climb ladders and timber supports with W/S.
Face a wall (or hold W/S for ceiling/floor) and press E to dig; place a timber support where the earth is too
unstable, then climb it to reach a ledge. Build with B — the object goes on the floor of the column you point at.
Storage, generator, purifier, lamps, the workbench and the bedroll all work. Try the Ashgrove cellar too. Press
**F7** to compare with the original top-down bunker.

## 3e. What to try (The Five Settlements, iteration 014)

**Inside is side view now.** Walk into the cabin, any shop or house: you see the building as a cross-section,
with floors, ceilings, windows and furniture. Walk left and right with A/D; at stairs hold **W** / **S** to go up
or down. Outside is still top-down. Watch a build's progress bar: it sits right above the thing being built.

**The road east.** Leave Ashgrove by its east road (the roadblock has been pushed aside) on foot or by car:
- **Corran Junction**, the crossroads: machine shop, warehouse, power & water building, a fuel depot.
- North to **Greyhollow**, the mining town. Go into **the mine** (Adit No. 3) with a light: down the ladder shaft
  to the haulage drift, down the winze to the deep workings. Two passages have collapsed.
- East to **Stillwater**, the larger town: market, outfitters, clinic, police station, apartments — and the
  **Civic Hall**, from the boiler room to the attic by three flights of stairs.
- Further east to **Port Halden**, the frozen harbour: piers, the cannery, the harbour master's office — and
  icebergs drifting in the open channels.
The map (**M**) fills in as you arrive.

**A quiet house.** One ordinary-looking house in Stillwater is not empty. Make enough noise in it and you will
find out. Running is an option — they will follow you out of the door.

**Guns.** Rare. If you find a handgun: equip it (**I**), load it with **T** (it needs the matching rounds), aim with
the mouse and fire with the attack button. Every shot is heard from far away. Gun oil keeps it working.

**Everything has a use, or a story.** 175 items, each with an icon and a tooltip (hover in the inventory). Stacks
share slots (30 rounds in one), a backpack adds 10 slots, and clothes layer for warmth: hat, scarf, gloves,
boots, thermal underwear, coat. Heat packs, a thermal blanket or a portable stove warm you; glow sticks and
flares light the dark for a while. Every building holds what you would expect there — and some hold nothing.

**Time controls (single player, F3 → World).** Pause, 1×, 2×, 5×, 10×. Not available in a hosted game.

## 3d. What to try (The Scavenger's Circuit, iteration 013)

**The circuit.** Prepare at the cabin, drive the station wagon east through the station to Ashgrove, explore,
scavenge, carry the finds back in the trunk and improve the shelter. Then do it again.

**Inside Ashgrove.** Every shop on Main Street can be entered at its door: the grocery, pharmacy, hardware
store, clothing store and the garage — plus two houses (open the door first) and the house with the cellar.
Shops have backrooms that daylight never reaches; take the flashlight (**L**). Inside it is sheltered but cold,
and the wind is muffled.

**Searching.** Walk up to shelves, cupboards, drawers, lockers, crates, tool chests, fridges and medicine
cabinets and press **E**. A bar fills over a few seconds; press **E** again or walk away to stop. When it is done
you see what was really inside and can take one thing or everything. Each place has its own kind of finds
(food in the grocery, bandages in the pharmacy, wood, fasteners and parts in the hardware store, fabric in the
clothing store, scrap, fuel and parts in the garage, a little of everything in the houses). Some containers were
already emptied by someone else. Nothing refills — not when you leave, not after a restart. Searching makes
noise, and rummaging through crates and lockers can be heard on the street.

**Scavenging skill.** Every container you search for the first time teaches you a little (**K** shows your
level). At level 1 an ordinary search takes 5 s; the first levels speed it up noticeably, later ones less; at
the top level it takes under 2 s, never instantly. Re-opening an emptied container teaches nothing.

**Trunk.** At the car press **R**: load everything (what you hold stays in your hands) or unload everything, or
move single items. The trunk holds 12. In the shelter, the storage panel has **Store everything you carry**.

**Wood stove.** Bring a stovepipe (the hardware store and the garage each have one), scrap metal and cement to the
shelter (or the Ashgrove cellar) and build a **Wood stove** (B). Once lit it glows, and you warm up much
faster on that level. It works in the side view and the top-down view.

**Developer menu (F3).** Commands are grouped in World / Player / Progression. Progression has the skill XP
multiplier (0–25×, quick 1/5/10/25×, reset to 1×), +XP, set level and reset Scavenging. Only the host can use
it; it is not saved (back to 1× after loading) and is not available in release builds.

## 3x. The World Reborn (iteration 015) — what to try

1. **Travel.** Leave Ashgrove east on foot or by car: the road runs through the Corran Forest to Corran Junction.
   Walk off any edge of an outdoor area and you continue in the next one. Open the map (M): Tab switches world /
   local, the mouse wheel zooms, drag to pan; unexplored land is under fog.
2. **Cabins.** Leave the road on the tracks: isolated cabins (some locked, some enterable) are found by exploring.
3. **Scavenging.** Press E on a shelf: the grid beside it fills slot by slot; click a revealed item to take it;
   E again (or Stop) pauses, and it resumes where it stopped.
4. **Locks.** A locked container or door opens the lock panel. With a key: Use key. With a lockpick: aim with the
   mouse (or ← →), click / Space to turn. Watch the "how close" hint; a worn pick snaps.
5. **Threats.** Make noise outdoors (gunfire) and a horde may gather. At night, wolves hunt in packs — run, drive
   or fight. Bears warn first: back away. Hideouts: Stillwater quiet house, Port Halden cottage, Greyhollow row house.
6. **Factions.** Hearth Gate is on the Stillwater Road (fenced, gate in the north wall): talk to the trader,
   mechanic and elder (E). Do not fire a gun inside the fence where someone can see. The raider camp is east of the
   Greyhollow Pass road — they shoot on sight. The Lantern Circle's radio shack is under the Halden coast mast.
   J shows your standing, credit, law record and missions.

## 4. Two players

- **Hosting:** one player chooses **Host Game**.
- **Joining:**
  - Same computer: **Join Game** with address `127.0.0.1`, port 24680, and a different player name.
  - Over the network: use the host's LAN address.
- Players can be in completely different places (the pine woods, the cabin, bunker levels, the settlement).
- Things worth trying together:
  - one explores while the other builds
  - both use storage or the workbench at the same time
  - one runs the generator while the other uses the planter
  - one assigns the survivor while the other is away
  - one disconnects and rejoins
  - the host saves, quits and continues

## 5. Saving and restarting

Only the host saves: with F5, from the pause menu, automatically every 5 minutes, and when leaving or
closing the window. Saves live in `%APPDATA%\Aftergrowth\saves\`. Everything you change is meant to
survive a restart: dug tunnels, built and damaged structures, inventories, crafting in progress, machines,
crops, weather, discoveries and the survivor. Please report anything that comes back reset or doubled.

## 6. Developer commands (F3, host only)

| Group | Commands |
|---|---|
| World | save, advance the clock 1 h, set the time to night or day, snowfall on/off, rebuild the view, screenshot |
| Threat | **start a Burnt One hunt (on me)**, automatic threats on/off (the old loop), Burnt Ones on/off, spawn one or a group, make noise, raise home heat, start a cabin attack, AI labels |
| Player | hurt, heal, make thirsty, make hungry |
| Materials | timber to storage, fuel + dirty water, a construction kit (metal, cement, parts) |
| Structures | damage all structures here, repair all |
| Bunker | create an underground test level |
| Survivor | recruit the survivor to the shelter, assign her water or farm work |
| Iteration 015 | sight on/off, vignette; horde now, automatic hordes on/off; reset hideouts, go to hideout 1/2/3; test rifle in starter bag; go to the raider camp / Hearth Gate / radio shack; +20 standing, +50 credit, clear my law strikes |
| Diagnostics | **write problem report** (includes the hunt state). The overlay shows the hunt line: state, target, distance, time left |

Joining players cannot use these unless the host enables client dev commands in the settings file.

## 7. Reporting a problem

1. Press **F3 → Write problem report** right after it happens. This writes a text file with:
   - the build and commit
   - the world, clock and weather
   - where you are, what you hold and your needs
   - the nearby structures and the defence event state
   - the last 60 log lines
2. The file is saved in `%APPDATA%\Aftergrowth\reports\`, and the path is shown on screen.
3. Attach the file and say what you expected and what happened.
4. Full logs are in `%APPDATA%\Aftergrowth\logs\`.

## 8. Known limitations (worth knowing while testing)

- All art and sound are generated placeholders, ready to be replaced with your own drawings and recordings.
- Nothing starts a Burnt One hunt on its own yet (developer trigger only). Laughter and night sightings are
  atmosphere only.
- **This build has not been run on Windows.** Windows acceptance is pending: it was tested on Linux
  only, and no exported Windows build exists.
- Movement collision is checked on each player's own computer. The host checks speed and reach.
- There is one settlement, one survivor with two jobs, and one weather type (snowfall, which has the old
  rain spell's effects).
- Inventory is text-based (no item icons).
