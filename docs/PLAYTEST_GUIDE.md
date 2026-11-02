# Aftergrowth — Playtest Guide (iterations 006–009 vertical slice)

This guide is for playing the game and reporting problems. Technical details are in
[`guides/TESTING_AND_LAUNCH.md`](guides/TESTING_AND_LAUNCH.md). Every number in the game is a prototype
value, and the [design decision register](DESIGN_DECISIONS.md) lists what is still EXPLORING.

## 1. Getting started (Windows)

1. Install **Godot 4.7.2 (standard)**.
2. On GitHub, pick the branch **`iteration/006-world-worth-surviving`** and choose **Code → Download ZIP**.
3. Extract the ZIP, open Godot, choose **Import**, select `project.godot`, then **Import & Edit**. Press **F5**.
4. In the main menu:
   - **Single Player → New World** is the normal game. You start with an undeveloped shelter site and no
     supplies.
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
| Q / X | Drink clean water / eat |
| M | Map |
| N | Settlement overview |
| H | Survival guide |
| Esc | Menu. The world keeps running |
| F5 | Save (host) |
| F3 | Developer overlay |
| F12 | Screenshot |

## 3. What to try

**Survival and combat.**
- Take the club in the farmhouse.
- Zombies wander the map edges. They raise their arms (red) before they hit.
- At 0 health you wake up in the farmhouse and keep your items.
- Zombies never enter buildings or the bunker.
- Watch three bars: Health, Water and Food.
  - Below 25 water or food you stop regenerating health.
  - At 0 you slowly lose health, but never below a floor.

**Noise and hordes.**
- Chopping, salvaging, building, sprinting and fighting are loud, and zombies go to where they heard the
  noise.
- Keep making noise in one place and more zombies come.
- The top-left line shows how disturbed the area is (calm → overrun). It fades if you stay quiet.
- Lots of noise near home, including digging and machinery heard through the hatch, eventually
  draws a **horde to the homestead**. You get a warning first.

**Gathering and crafting.**
- Fell trees for wood.
- Search places for supplies: the car, the shed, the tractor and the rain barrel on the farm; the pantry
  and linen chest inside. Searched places refill over time.
- Build a **workbench** (B). It makes:
  - tools: hatchet (chops faster), machete (hits harder)
  - a padded jacket (zombie hits hurt less)
  - parts: timber frames, spike kits, grow lights
  - bandages
- It also repairs worn tools.

**Underground expansion.**
- Dig the shelter under the farmhouse and climb down.
- Aim at earth walls and press E to dig.
- Far from the first room you need a **timber support** (B → support).
- You can place walls, crates, planters and benches on dug floor. The game refuses anything that would
  wall off part of the bunker.

**Construction and defences.**
- The yard is fenced on three sides; the north side has gaps.
- Build **barricades** in the gaps and upgrade them from wood to metal to concrete.
- Add **spike traps** where zombies will walk. A **reinforced door** lets people through a barricade line.
- Damaged structures show a bar. Press R to repair, and refused actions say why.
- Upgrade the **hatch to steel** to keep bunker noise in.

**Power, water and food.**
- Fuel and start the generator: the lights and purifier work, and so do the planter's grow lights.
- Pour dirty water into the purifier to get clean water.
- A **rain collector** (outdoors) fills with dirty water, faster when it rains.
- A **hydroponic planter** grows potatoes from clean water while the power is on.

**Exploration and discoveries.**
- Walk **east along the road** from the homestead to reach the **service station**. It has fuel, food,
  cloth, cement, scrap metal and electrical parts, plus resident zombies.
- The workshop's **tool locker** holds a tuned carburetor and a workshop manual. Neither respawns:
  - Fit the carburetor to the generator to halve its fuel use.
  - Read the manual to learn the felling axe.
- The map (M) shows places once you have found them.

**Survivor management.**
- Someone is hiding at the service station. Talk to her and bring what she needs.
- She walks to your shelter and lives there.
- Give her a job by talking to her or in the settlement overview (N):
  - the **water** job tends the purifier
  - the **farm** job tends the planters
- She only uses what is in storage and the machines you built. If she can't work, she says why.
- The settlement feeds her once a day from storage.

**Day, night and weather.**
- Days last 24 minutes. Nights are dark, so carry yourself carefully; zombies see less at night, but more
  of them roam.
- Rain hides your noise.

## 4. Two players

- **Hosting:** one player chooses **Host Game**.
- **Joining:**
  - Same computer: **Join Game** with address `127.0.0.1`, port 24680, and a different player name.
  - Over the network: use the host's LAN address.
- Players can be in completely different places (homestead, farmhouse, bunker levels, service station).
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
| World | save, advance the clock 1 h, set the time to night or day, rain on/off, rebuild the view, screenshot |
| Threat | zombies on/off, spawn a zombie or a group, make noise, raise home heat, **start a horde** |
| Player | hurt, heal, make thirsty, make hungry |
| Materials | timber to storage, fuel + dirty water, a construction kit (metal, cement, parts) |
| Structures | damage all structures here, repair all |
| Bunker | create an underground test level |
| Survivor | recruit the survivor to the shelter, assign her water or farm work |
| Diagnostics | **write problem report** |

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

- All art and sound are generated placeholders. Zombie design is deferred.
- **This build has not been run on Windows.** Windows acceptance is pending: it was tested on Linux
  only, and no exported Windows build exists.
- Movement collision is checked on each player's own computer. The host checks speed and reach.
- There is one point of interest, one survivor with two jobs, one weather type (rain) and one defence
  event type.
- Inventory is text-based (no item icons).
