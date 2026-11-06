#!/usr/bin/env python3
"""The complete Red Thaw item catalogue (iteration 014, The Five Settlements).

One row per carryable item: stable id, category, English and Danish name and
description, weight (kg), stack limit (units per carrying slot), mechanics
(nutrition, hydration, healing, warmth, insulation, equipment slot, melee or
firearm numbers, ammunition, fuel, crafting use) and an icon spec.

Items that appear under several headings share ONE id (the hammer, crowbar,
shovel and hatchet are tools and weapons; the thermos is a container and a
frozen-world item; batteries are electronics and household goods; heat packs and
hand warmers, flares and emergency flares are the same objects). Existing items
keep their ids and mechanics (canned_food is the canned beans, wood is the
firewood too, fuel is the gasoline, padded_jacket is the jacket, field_map is the
paper map, water_bottle is bottled water, club is the wooden club …).

Writes content/items.json (merged: existing mechanics are kept), the EN/DA item
strings in locale/strings.json, and is read by tools/art/gen_item_icons.py.
Items with no implemented function are honest about it: valuables, junk or
crafting materials. Usage: python3 tools/build_catalogue.py
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (id, cat, EN name, DA name, EN desc, DA desc, weight kg, stack limit, mechanics, icon (shape, colour, accent))
C = []


def item(i, cat, en, da, den, dda, wt, stack, mech=None, icon=("box", "#7A6A55", "#C9C1AE")):
    C.append((i, cat, en, da, den, dda, wt, stack, mech or {}, icon))


# ------------------------------------------------------------------ food
item("canned_food", "food", "Canned beans", "Dåsebønner", "Beans in tomato sauce. Filling. Needs no cooking.", "Bønner i tomatsauce. Mættende. Skal ikke tilberedes.", 0.45, 1, {"use": "eat", "food": 40}, ("can", "#8A5A3A", "#C9A86A"))
item("canned_soup", "food", "Canned soup", "Dåsesuppe", "Thin, salty, warm if you can heat it. Some water too.", "Tynd og salt suppe. Lidt væske med.", 0.45, 1, {"use": "eat", "food": 30, "hydration": 12}, ("can", "#7E3A2C", "#D8C79A"))
item("canned_meat", "food", "Canned meat", "Dåsekød", "Corned beef. Dense and fatty.", "Corned beef. Kompakt og fedt.", 0.4, 1, {"use": "eat", "food": 45}, ("can", "#6E4A3A", "#B58A6A"))
item("crackers", "food", "Pack of crackers", "Pakke kiks", "Dry crackers. Light to carry.", "Tørre kiks. Lette at bære.", 0.2, 1, {"use": "eat", "food": 25}, ("pack", "#C9A86A", "#8A6A3A"))
item("chocolate", "food", "Chocolate", "Chokolade", "A bar of dark chocolate. A small comfort.", "En plade mørk chokolade. En lille trøst.", 0.1, 3, {"use": "eat", "food": 15, "warmth": 3}, ("bar", "#4E2E22", "#B5543A"))
item("energy_bar", "food", "Energy bar", "Energibar", "Oats and syrup, pressed.", "Havre og sirup, presset.", 0.08, 4, {"use": "eat", "food": 20}, ("bar", "#8A7A3A", "#D9C38A"))
item("jerky", "food", "Jerky", "Tørret kød", "Dried, salted strips of meat. Keeps forever.", "Tørrede, saltede kødstrimler. Holder evigt.", 0.15, 3, {"use": "eat", "food": 25, "hydration": -4}, ("pack", "#6E3A2A", "#B58A6A"))
item("fresh_meat", "food", "Fresh meat", "Frisk kød", "Frozen solid out here. Edible, barely.", "Frosset fast herude. Spiselig, lige akkurat.", 0.6, 1, {"use": "eat", "food": 35, "health": -3}, ("meat", "#9A3A32", "#D9A8A0"))
item("vegetables", "food", "Vegetables", "Grøntsager", "A tin of mixed vegetables.", "En dåse blandede grøntsager.", 0.4, 1, {"use": "eat", "food": 20, "hydration": 5}, ("can", "#4F6A3A", "#B5C27A"))
item("spoiled_food", "food", "Spoiled food", "Fordærvet mad", "It smells wrong. Eating it will make you ill.", "Den lugter forkert. Den gør dig syg.", 0.3, 2, {"use": "eat", "food": 10, "health": -12}, ("can", "#5A5A3A", "#7A7A4A"))
item("frozen_food", "food", "Frozen food", "Frossen mad", "A frozen ready meal, hard as stone.", "En frossen færdigret, hård som sten.", 0.5, 1, {"use": "eat", "food": 30, "warmth": -4}, ("box", "#7E9AA8", "#E6E8E4"))
item("potato", "food", "Potato", "Kartoffel", "Grown under lamps in the shelter.", "Dyrket under lamper i beskyttelsesrummet.", 0.2, 3, {}, ("meat", "#8A7A52", "#C9B88A"))

# ------------------------------------------------------------------ drinks
item("water_bottle", "drink", "Bottled water", "Flaskevand", "A large sealed bottle of water.", "En stor forseglet flaske vand.", 1.0, 1, {}, ("bottle", "#7EA6C2", "#E6E8E4"))
item("water_dirty", "drink", "Dirty water", "Beskidt vand", "Melted snow, grey with ash. Purify it first.", "Smeltet sne, grå af aske. Rens det først.", 1.0, 1, {}, ("bottle", "#6E6A5A", "#9A9A8A"))
item("water_clean", "drink", "Clean water", "Rent vand", "Filtered, safe to drink.", "Filtreret, sikkert at drikke.", 1.0, 1, {}, ("bottle", "#9AC2D8", "#E6E8E4"))
item("soda", "drink", "Soda", "Sodavand", "A can of something sweet and flat.", "En dåse noget sødt og fladt.", 0.35, 2, {"use": "drink", "hydration": 25, "food": 4}, ("can", "#B5543A", "#E6E8E4"))
item("energy_drink", "drink", "Energy drink", "Energidrik", "Sugar, caffeine, and a buzzing heart.", "Sukker, koffein og et summende hjerte.", 0.35, 2, {"use": "drink", "hydration": 20, "food": 6}, ("can", "#3F6A3A", "#D9D24A"))
item("coffee", "drink", "Coffee", "Kaffe", "A jar of instant coffee. Warms the hands.", "Et glas pulverkaffe. Varmer hænderne.", 0.3, 2, {"use": "drink", "hydration": 10, "warmth": 8}, ("jar", "#4E3426", "#C9A86A"))
item("alcohol", "drink", "Alcohol", "Alkohol", "A bottle of strong spirits. Feels warm — it isn't.", "En flaske stærk spiritus. Føles varm — er det ikke.", 0.8, 1, {"use": "drink", "hydration": -6, "warmth": 6}, ("bottle", "#8A6A2A", "#D9C38A"))

# ------------------------------------------------------------------ medical
item("bandage", "medical", "Bandage", "Forbinding", "Stops the bleeding.", "Stopper blødningen.", 0.05, 5, {}, ("roll", "#E6E1D2", "#B5543A"))
item("rags", "medical", "Rags", "Klude", "Torn cloth. A poor dressing.", "Revet stof. En dårlig forbinding.", 0.05, 5, {"use": "heal", "heal": 10}, ("cloth", "#8A8070", "#6A6050"))
item("first_aid_kit", "medical", "First-aid kit", "Førstehjælpskasse", "A proper kit: dressings, tape, antiseptic.", "En rigtig kasse: forbindinger, tape, desinfektion.", 0.6, 1, {"use": "heal", "heal": 70}, ("kit", "#C9C1AE", "#B5543A"))
item("disinfectant", "medical", "Disinfectant", "Desinfektionsmiddel", "Stings. Keeps a wound clean.", "Svier. Holder et sår rent.", 0.3, 2, {"use": "heal", "heal": 15}, ("bottle", "#C9D8E2", "#4E8A6C"))
item("painkillers", "medical", "Painkillers", "Smertestillende", "A strip of pills. Dulls the pain.", "En blisterpakke. Dulmer smerten.", 0.03, 5, {"use": "heal", "heal": 20}, ("pills", "#E6E1D2", "#7E3A2C"))
item("antibiotics", "medical", "Antibiotics", "Antibiotika", "A course of tablets. Rare now.", "En kur tabletter. Sjældne nu.", 0.03, 5, {"use": "heal", "heal": 25}, ("pills", "#E6E1D2", "#3F6457"))
item("vitamins", "medical", "Vitamins", "Vitaminer", "Small tablets. A little better than nothing.", "Små tabletter. Lidt bedre end ingenting.", 0.05, 5, {"use": "heal", "heal": 5, "food": 3}, ("pills", "#D9C38A", "#8A6A2A"))
item("splint", "medical", "Splint", "Skinne", "Holds a limb straight.", "Holder et lem lige.", 0.3, 2, {"use": "heal", "heal": 25}, ("plank", "#9A7A55", "#E6E1D2"))
item("medical_syringe", "medical", "Medical syringe", "Medicinsk sprøjte", "A sealed emergency injection.", "En forseglet nødindsprøjtning.", 0.03, 3, {"use": "heal", "heal": 50}, ("syringe", "#C9D8E2", "#B5543A"))

# ------------------------------------------------------------------ fire & warmth
item("matches", "fire", "Matches", "Tændstikker", "A box of matches. Fire-making material.", "En æske tændstikker. Til at tænde ild.", 0.03, 10, {}, ("matchbox", "#B5543A", "#D9C38A"))
item("lighter", "fire", "Lighter", "Lighter", "A disposable lighter. Fire-making material.", "En engangslighter. Til at tænde ild.", 0.03, 5, {}, ("lighter", "#3F6457", "#C9C1AE"))
item("firestarter", "fire", "Firestarter", "Optændingsblok", "Wax cubes that burn long. Fire-making material.", "Voksterninger der brænder længe.", 0.1, 5, {}, ("cube", "#C9B88A", "#8A6A3A"))
item("tinder", "fire", "Tinder", "Tøndersvamp", "Dry bark and lint. Fire-making material.", "Tør bark og fnug. Til at tænde ild.", 0.05, 10, {}, ("cloth", "#9A8A62", "#6A5A3A"))
item("charcoal", "fire", "Charcoal", "Trækul", "Burns hot and clean. Fuel and crafting material.", "Brænder varmt og rent.", 0.5, 5, {}, ("lumps", "#2C2A28", "#5A5652"))
item("wood", "fire", "Wood (firewood)", "Træ (brænde)", "Split logs: fuel for stoves, timber for building.", "Kløvet træ: brændsel og byggemateriale.", 1.5, 1, {}, ("logs", "#7A5E40", "#4E3A26"))
item("hand_warmer", "fire", "Hand warmers", "Håndvarmere", "Shake the pouch; it heats for an hour.", "Ryst posen; den varmer en time.", 0.05, 5, {"use": "warm", "warmth": 25}, ("pouch", "#B5543A", "#E6E1D2"))

# ------------------------------------------------------------------ clothing (slots: body, head, hands, feet, legs, back, face)
item("padded_jacket", "clothing", "Jacket", "Jakke", "A padded jacket.", "En vatteret jakke.", 1.2, 1, {}, ("coat", "#5A6A58", "#3A4A38"))
item("winter_coat", "clothing", "Winter coat", "Vinterfrakke", "Long, down-filled. The best defence against the cold.", "Lang og dunfyldt. Det bedste værn mod kulden.", 2.0, 1, {}, ("coat", "#4E3A30", "#8A6A52"))
item("gloves", "clothing", "Gloves", "Handsker", "Work gloves.", "Arbejdshandsker.", 0.2, 1, {"stack": False, "slot": "hands", "insulation": 0.06, "durability": 120, "repair": {"cloth": 1}}, ("gloves", "#6A5A4A", "#3A2E24"))
item("hat", "clothing", "Hat", "Hue", "A knitted hat.", "En strikket hue.", 0.1, 1, {"stack": False, "slot": "head", "insulation": 0.08, "durability": 120, "repair": {"cloth": 1}}, ("hat", "#7E3A2C", "#C9C1AE"))
item("scarf", "clothing", "Scarf", "Halstørklæde", "Wool, wrapped twice.", "Uld, viklet to gange.", 0.15, 1, {"stack": False, "slot": "face", "insulation": 0.06, "durability": 120, "repair": {"cloth": 1}}, ("scarf", "#5B3F5A", "#C9C1AE"))
item("boots", "clothing", "Boots", "Støvler", "Lined winter boots.", "Forede vinterstøvler.", 1.4, 1, {"stack": False, "slot": "feet", "insulation": 0.1, "armor": 0.05, "durability": 200, "repair": {"cloth": 1}}, ("boots", "#3E3329", "#6A5A4A"))
item("socks", "clothing", "Socks", "Strømper", "Cotton socks. Better than bare feet.", "Bomuldsstrømper. Bedre end bare fødder.", 0.05, 1, {"stack": False, "slot": "feet", "insulation": 0.03, "durability": 60, "repair": {"cloth": 1}}, ("socks", "#C9C1AE", "#8A8070"))
item("wool_socks", "clothing", "Wool socks", "Uldsokker", "Thick wool socks.", "Tykke uldsokker.", 0.1, 1, {"stack": False, "slot": "feet", "insulation": 0.07, "durability": 100, "repair": {"cloth": 1}}, ("socks", "#8A6A52", "#5A4A3A"))
item("trousers", "clothing", "Trousers", "Bukser", "Heavy work trousers.", "Kraftige arbejdsbukser.", 0.8, 1, {"stack": False, "slot": "legs", "insulation": 0.08, "armor": 0.05, "durability": 160, "repair": {"cloth": 1}}, ("trousers", "#3F4A56", "#2A3440"))
item("thermal_underwear", "clothing", "Thermal underwear", "Termoundertøj", "A thin layer that keeps the warmth in.", "Et tyndt lag der holder på varmen.", 0.3, 1, {"stack": False, "slot": "legs", "insulation": 0.12, "durability": 120, "repair": {"cloth": 1}}, ("trousers", "#C9C1AE", "#8A8070"))
item("backpack", "clothing", "Backpack", "Rygsæk", "Carry ten more things.", "Bær ti ting mere.", 1.0, 1, {"stack": False, "slot": "back", "carry": 10, "durability": 300, "repair": {"cloth": 1}}, ("backpack", "#4F5A3A", "#2E3424"))
item("insulated_gloves", "clothing", "Insulated gloves", "Forede handsker", "Thick mittens with a lining.", "Tykke luffer med for.", 0.3, 1, {"stack": False, "slot": "hands", "insulation": 0.12, "durability": 140, "repair": {"cloth": 1}}, ("gloves", "#2E4A5C", "#C9C1AE"))
item("snow_goggles", "clothing", "Snow goggles", "Snebriller", "Cut the glare of the snow.", "Tager blændingen fra sneen.", 0.1, 1, {"stack": False, "slot": "face", "insulation": 0.03, "durability": 120}, ("goggles", "#2C3033", "#D9C38A"))

# ------------------------------------------------------------------ weapons: melee
def melee(i, en, da, den, dda, wt, dmg, rng, cd, dur, chop=1, icon=("knife", "#A9A49A", "#3A3026"), repair="scrap_metal", cat="weapon"):
    item(i, cat, en, da, den, dda, wt, 1, {"stack": False, "slot": "hand", "damage": dmg, "range": rng, "cooldown_ticks": cd, "chop": chop,
                                           "durability": dur, "repair": {repair: 1}}, icon)


melee("kitchen_knife", "Kitchen knife", "Køkkenkniv", "Short and sharp.", "Kort og skarp.", 0.2, 26, 56, 4, 90, icon=("knife", "#A9A49A", "#3A3026"))
melee("hunting_knife", "Hunting knife", "Jagtkniv", "A heavy fixed blade.", "Et tungt, fast blad.", 0.35, 34, 60, 4, 160, icon=("knife", "#8A8478", "#6A4A30"))
melee("baseball_bat", "Baseball bat", "Baseballbat", "Ash wood. Heavy swings.", "Asketræ. Tunge slag.", 1.0, 40, 82, 7, 140, icon=("bat", "#9A7A55", "#4E3A26"), repair="wood")
melee("crowbar", "Crowbar", "Brækjern", "Pries, breaks, and swings.", "Bryder op og slår.", 1.6, 38, 74, 7, 300, icon=("crowbar", "#5E6467", "#7E2A22"), cat="tool")
melee("hammer", "Hammer", "Hammer", "A claw hammer. Tool and weapon.", "En kløfthammer. Værktøj og våben.", 0.7, 30, 60, 5, 240, icon=("hammer", "#5E6467", "#6A4A30"), cat="tool")
melee("fire_axe", "Fire axe", "Brandøkse", "Red-handled, heavy, brutal.", "Rødt skaft, tung og brutal.", 2.2, 58, 80, 8, 220, chop=2, icon=("axe", "#7E2A22", "#A9A49A"))
melee("shovel", "Shovel", "Skovl", "Digs snow and swings hard.", "Skovler sne og slår hårdt.", 1.8, 32, 84, 7, 200, icon=("shovel", "#6A4A30", "#5E6467"), cat="tool")
melee("pickaxe", "Pickaxe", "Hakke", "A miner's pick.", "En minearbejders hakke.", 2.4, 44, 76, 8, 260, icon=("pickaxe", "#6A4A30", "#5E6467"), cat="tool")
melee("sharpened_stick", "Sharpened stick", "Spidset stok", "Better than nothing.", "Bedre end ingenting.", 0.5, 18, 80, 5, 40, icon=("stick", "#7A5E40", "#4E3A26"), repair="wood")
melee("metal_pipe", "Metal pipe", "Metalrør", "A length of steel pipe.", "Et stykke stålrør.", 1.4, 32, 76, 6, 260, icon=("pipe", "#5E6467", "#3A3E40"))
melee("ice_pick", "Ice pick", "Isøkse", "A climber's ice axe.", "En bjergbestigers isøkse.", 0.6, 30, 62, 5, 180, icon=("pickaxe", "#3F5B6A", "#A9A49A"), cat="frozen")
for ex in ("club", "machete", "hatchet", "felling_axe"):
    pass  # existing melee weapons keep their mechanics (merged below)
item("club", "weapon", "Wooden club", "Træknippel", "A heavy length of wood.", "Et tungt stykke træ.", 1.0, 1, {}, ("bat", "#7A5E40", "#4E3A26"))
item("machete", "weapon", "Machete", "Machete", "A long blade that also clears brush.", "Et langt blad der også rydder krat.", 0.8, 1, {}, ("knife", "#A9A49A", "#3A3026"))
item("hatchet", "tool", "Hatchet", "Håndøkse", "Chops wood quickly; a light weapon.", "Hugger brænde hurtigt; et let våben.", 0.9, 1, {}, ("axe", "#5E6467", "#94826B"))
item("felling_axe", "tool", "Felling axe", "Fældeøkse", "Fells trees in few strokes.", "Fælder træer med få hug.", 2.6, 1, {}, ("axe", "#5A6142", "#94826B"))

# ------------------------------------------------------------------ weapons: firearms (mechanics defined by iteration 014 D, merged)
for g, en, da, wt in (("handgun", "Handgun", "Pistol", 0.9), ("revolver", "Revolver", "Revolver", 1.1), ("shotgun", "Shotgun", "Haglgevær", 3.2),
                      ("hunting_rifle", "Hunting rifle", "Jagtriffel", 3.6), ("military_rifle", "Military rifle", "Militærriffel", 3.9)):
    item(g, "weapon", en, da, None, None, wt, 1, {}, ("gun_" + ("short" if g in ("handgun", "revolver") else "long"), "#3A3E40", "#6A4A30"))
item("ammo_pistol", "ammo", "Pistol rounds", "Pistolpatroner", None, None, 0.012, 30, {}, ("ammo", "#B59A5A", "#3A3E40"))
item("ammo_revolver", "ammo", "Revolver rounds", "Revolverpatroner", None, None, 0.015, 30, {}, ("ammo", "#C9A86A", "#5A4A3A"))
item("shotgun_shells", "ammo", "Shotgun shells", "Haglpatroner", None, None, 0.04, 20, {}, ("shells", "#9A3A32", "#C9A86A"))
item("rifle_rounds", "ammo", "Rifle rounds", "Riffelpatroner", None, None, 0.025, 30, {}, ("ammo", "#B59A5A", "#4E5A3A"))
item("loaded_magazine", "ammo", "Loaded magazine", "Ladt magasin", None, None, 0.25, 4, {}, ("magazine", "#2C3033", "#B59A5A"))

# ------------------------------------------------------------------ weapon maintenance
item("gun_cleaning_kit", "tool", "Gun cleaning kit", "Våbenrensesæt", "Rods, patches and solvent. Restores a held firearm's condition.", "Stænger, klude og opløsning. Genopretter et skydevåben i hånden.", 0.4, 1, {"use": "repair_hand", "repair": 40, "fixes": "firearm"}, ("kit", "#3A3E40", "#C9A86A"))
item("gun_oil", "tool", "Gun oil", "Våbenolie", "A small can of oil. Improves a held firearm's condition a little.", "En lille dåse olie. Forbedrer et skydevåben lidt.", 0.15, 3, {"use": "repair_hand", "repair": 15, "fixes": "firearm"}, ("oilcan", "#8A7A3A", "#3A3E40"))
item("weapon_parts", "part", "Replacement weapon parts", "Reservedele til våben", None, None, 0.3, 3, {}, ("gear", "#5E6467", "#B59A5A"))
item("sharpening_stone", "tool", "Sharpening stone", "Slibesten", "Restores the edge of a held blade or axe.", "Genopretter æggen på et blad eller en økse i hånden.", 0.3, 1, {"use": "repair_hand", "repair": 30, "fixes": "melee"}, ("stone", "#7A7A72", "#4E4E48"))

# ------------------------------------------------------------------ tools
for i, en, da, ic in (("screwdriver", "Screwdriver", "Skruetrækker", "screwdriver"), ("wrench", "Wrench", "Skruenøgle", "wrench"), ("pliers", "Pliers", "Tang", "pliers"),
                      ("handsaw", "Handsaw", "Fuchsvans", "saw"), ("hacksaw", "Hacksaw", "Nedstryger", "saw"), ("wire_cutters", "Wire cutters", "Bidetang", "pliers"),
                      ("multitool", "Multitool", "Multiværktøj", "pliers"), ("lockpick", "Lockpick", "Dirk", "key"), ("bolt_cutters", "Bolt cutters", "Boltsaks", "pliers"),
                      ("sewing_kit", "Sewing kit", "Syæske", "kit")):
    item(i, "tool", en, da, "A tool. Kept for crafting and repairs.", "Et værktøj. Til håndværk og reparationer.", 0.4 if i not in ("bolt_cutters", "handsaw") else 1.4, 1, {"stack": False}, (ic, "#5E6467", "#7E2A22"))

# ------------------------------------------------------------------ construction and crafting materials
item("planks", "material", "Planks", "Brædder", "Sawn boards.", "Savede brædder.", 1.2, 4, {}, ("plank", "#9A7A55", "#6A4A30"))
item("nails", "material", "Nails", "Søm", "A handful of nails.", "En håndfuld søm.", 0.05, 30, {}, ("nails", "#7A8083", "#3A3E40"))
item("screws", "material", "Screws", "Skruer", "A handful of screws.", "En håndfuld skruer.", 0.05, 30, {}, ("nails", "#A9A49A", "#5E6467"))
item("scrap_metal", "material", "Scrap metal", "Skrot", "Twisted sheet and rod. Building and repairs.", "Bøjet plade og stang. Til byggeri og reparationer.", 1.0, 1, {}, ("scrap", "#5E6467", "#73392A"))
item("sheet_metal", "material", "Sheet metal", "Metalplade", "A flat sheet of steel.", "En flad stålplade.", 2.0, 2, {}, ("sheet", "#7A8083", "#3A3E40"))
item("rope", "material", "Rope", "Reb", "Ten metres of rope.", "Ti meter reb.", 0.8, 3, {}, ("coil", "#A3926A", "#6A5A3A"))
item("wire", "material", "Wire", "Ståltråd", "A coil of steel wire.", "En rulle ståltråd.", 0.4, 5, {}, ("coil", "#7A8083", "#3A3E40"))
item("duct_tape", "material", "Duct tape", "Gaffatape", "Fixes almost anything for a while.", "Fikser næsten alt for en stund.", 0.2, 5, {}, ("tape", "#7A8083", "#5E6467"))
item("glue", "material", "Glue", "Lim", "A tube of strong glue.", "En tube stærk lim.", 0.1, 5, {}, ("tube", "#D9C38A", "#3A3E40"))
item("cloth", "material", "Cloth", "Stof", "Fabric for bandages, clothing and repairs.", "Stof til forbindinger, tøj og reparationer.", 0.2, 1, {}, ("cloth", "#8A8478", "#5A5650"))
item("leather", "material", "Leather", "Læder", "A piece of tough hide.", "Et stykke sejt skind.", 0.4, 5, {}, ("cloth", "#6E4A30", "#4E3426"))
item("plastic", "material", "Plastic", "Plastik", "Scraps of hard plastic.", "Stumper af hård plastik.", 0.2, 10, {}, ("sheet", "#C9C1AE", "#7EA6C2"))
item("rubber", "material", "Rubber", "Gummi", "Strips of rubber.", "Gummistrimler.", 0.3, 10, {}, ("coil", "#2C2A28", "#5A5652"))
item("glass_bottles", "material", "Glass bottles", "Glasflasker", "Empty bottles.", "Tomme flasker.", 0.4, 5, {}, ("bottle", "#4F6A3A", "#9AB59A"))
item("cement", "material", "Cement", "Cement", "A sack of cement. Concrete and steel hatches.", "En sæk cement. Beton og stållemme.", 5.0, 1, {}, ("sack", "#9A968E", "#5E5B55"))
item("timber_frame", "part", "Timber frame", "Tømmerramme", "A ready-made frame for a door or barricade.", "En færdig ramme til en dør eller barrikade.", 6.0, 1, {}, ("plank", "#7A5E40", "#4E3A26"))
item("spike_kit", "part", "Spike kit", "Pigge-sæt", "Sharpened stakes for a trap.", "Spidsede pæle til en fælde.", 3.0, 1, {}, ("stick", "#7A5E40", "#5E6467"))
item("grow_light", "part", "Grow light", "Vækstlampe", "A lamp that grows potatoes in the dark.", "En lampe der dyrker kartofler i mørket.", 1.5, 1, {}, ("lantern", "#D9C38A", "#3A3E40"))
item("stovepipe", "part", "Stovepipe", "Kakkelovnsrør", None, None, 2.0, 1, {}, ("pipe", "#3A3E40", "#5E6467"))
item("carburetor", "part", "Carburetor", "Karburator", None, None, 1.5, 1, {}, ("gear", "#5E6467", "#73392A"))
item("workshop_manual", "junk", "Workshop manual", "Værkstedshåndbog", None, None, 0.6, 1, {}, ("book", "#3F5B6A", "#D9C38A"))

# mechanical parts
for i, en, da, ic in (("gears", "Gears", "Tandhjul", "gear"), ("springs", "Springs", "Fjedre", "spring"), ("bolts", "Bolts", "Bolte", "nails"),
                      ("pipes", "Pipes", "Rør", "pipe"), ("bearings", "Bearings", "Lejer", "gear"), ("engine_parts", "Engine parts", "Motordele", "gear")):
    item(i, "mechanical", en, da, "Mechanical parts. Crafting and repairs.", "Mekaniske dele. Til håndværk og reparationer.", 0.3 if i not in ("engine_parts", "pipes") else 2.0, 10 if i in ("springs", "bolts", "bearings") else 3, {}, (ic, "#5E6467", "#B59A5A"))
# electronics
item("batteries", "electronics", "Batteries", "Batterier", "A pack of AA batteries. Crafting material.", "En pakke AA-batterier. Materiale.", 0.1, 10, {}, ("battery", "#3A3E40", "#D9C38A"))
item("cables", "electronics", "Cables", "Kabler", "Lengths of insulated cable.", "Stykker af isoleret kabel.", 0.3, 5, {}, ("coil", "#2C2A28", "#B5543A"))
item("circuit_boards", "electronics", "Circuit boards", "Printkort", "Salvaged boards.", "Bjærgede printkort.", 0.2, 5, {}, ("chip", "#3F6A3A", "#D9C38A"))
item("electrical_parts", "electronics", "Electronic components", "Elektroniske komponenter", "Switches, relays and wire. Power and lights.", "Kontakter, relæer og ledning. Strøm og lys.", 0.3, 1, {}, ("chip", "#3A4A3A", "#B5543A"))
item("fuses", "electronics", "Fuses", "Sikringer", "A box of fuses.", "En æske sikringer.", 0.05, 10, {}, ("battery", "#C9C1AE", "#B5543A"))
# fuel
item("fuel", "fuel", "Gasoline", "Benzin", "A few litres of gasoline: the generator and the car.", "Et par liter benzin: generatoren og bilen.", 3.0, 1, {}, ("jerrycan", "#7E2A22", "#C9A86A"))
item("diesel", "fuel", "Diesel", "Diesel", "A can of diesel. Heavy machinery fuel (not used by the generator).", "En dunk diesel. Til tunge maskiner (ikke generatoren).", 3.0, 1, {}, ("jerrycan", "#3F5B4A", "#C9A86A"))
item("propane", "fuel", "Propane canister", "Propanflaske", "A small gas canister.", "En lille gasflaske.", 1.0, 2, {}, ("canister", "#B5543A", "#3A3E40"))
item("kerosene", "fuel", "Kerosene", "Petroleum", "Lamp oil.", "Lampeolie.", 1.0, 2, {}, ("canister", "#3F6457", "#C9C1AE"))
item("motor_oil", "fuel", "Motor oil", "Motorolie", "A bottle of engine oil.", "En flaske motorolie.", 1.0, 2, {}, ("oilcan", "#2C2A28", "#C9A86A"))

# ------------------------------------------------------------------ exploration & utilities
item("flashlight", "utility", "Flashlight", "Lommelygte", "Lights the dark (L).", "Lyser mørket op (L).", 0.3, 1, {}, ("flashlight", "#3A3E40", "#D9C38A"))
for i, en, da, den, dda, ic in (("headlamp", "Headlamp", "Pandelampe", "A strap-on lamp. Lights the dark (L).", "En pandelampe. Lyser mørket op (L).", "flashlight"),
                                ("lantern", "Lantern", "Lanterne", "A storm lantern. Lights the dark (L).", "En stormlampe. Lyser mørket op (L).", "lantern"),
                                ("hand_crank_flashlight", "Hand-crank flashlight", "Dynamolygte", "Wind it, and it lights the dark (L). Needs no batteries.", "Drej den, så lyser den (L).", "flashlight")):
    item(i, "utility", en, da, den, dda, 0.4, 1, {"stack": False, "use": "flashlight"}, (ic, "#4F5A3A", "#D9C38A"))
item("glow_sticks", "utility", "Glow sticks", "Lysstave", "Snap one for a faint green light that lasts ten minutes (L).", "Knæk én for svagt grønt lys i ti minutter (L).", 0.03, 10, {"use": "flashlight", "burn_seconds": 600}, ("glowstick", "#6AD96A", "#2C3033"))
item("flare", "utility", "Flares", "Nødblus", "A road flare. Burns bright for four minutes (L).", "Et nødblus. Brænder klart i fire minutter (L).", 0.2, 5, {"use": "flashlight", "burn_seconds": 240}, ("flare", "#B5543A", "#D9C38A"))
item("compass", "utility", "Compass", "Kompas", "A brass compass. A keepsake.", "Et messingkompas. Et minde.", 0.1, 1, {"stack": False}, ("compass", "#B59A5A", "#3A3E40"))
item("field_map", "utility", "Paper map", "Papirkort", None, None, 0.1, 1, {}, ("map", "#D9D2C0", "#7E2A22"))
item("binoculars", "utility", "Binoculars", "Kikkert", "Old field glasses. Valuable.", "En gammel kikkert. Værdifuld.", 0.7, 1, {"stack": False}, ("binoculars", "#2C3033", "#5E6467"))
item("handheld_radio", "utility", "Handheld radio", "Transistorradio", "Only static now. Valuable for parts.", "Kun sus nu. Værdifuld for delene.", 0.6, 1, {"stack": False}, ("radio", "#3A3E40", "#B5543A"))
item("walkie_talkie", "utility", "Walkie-talkie", "Walkie-talkie", "No one answers. Valuable for parts.", "Ingen svarer. Værdifuld for delene.", 0.4, 1, {"stack": False}, ("radio", "#2C3033", "#D9C38A"))
item("padlock", "utility", "Padlock", "Hængelås", "A sturdy padlock.", "En solid hængelås.", 0.3, 3, {}, ("padlock", "#5E6467", "#B59A5A"))
item("keys", "utility", "Keys", "Nøgler", "A ring of keys to doors that no longer matter.", "Et nøglebundt til døre der ikke betyder noget.", 0.05, 5, {}, ("key", "#B59A5A", "#5E6467"))
item("keycard", "utility", "Keycard", "Nøglekort", "A plastic access card.", "Et adgangskort i plastik.", 0.01, 5, {}, ("keycard", "#C9C1AE", "#3F6457"))
item("combination_note", "utility", "Combination note", "Kodeseddel", "Four digits scribbled on a scrap of paper.", "Fire cifre kradset ned på en lap papir.", 0.01, 5, {}, ("note", "#D9D2C0", "#3A3E40"))
item("dust_mask", "utility", "Dust mask", "Støvmaske", "Keeps the ash out of your throat.", "Holder asken ude af halsen.", 0.03, 1, {"stack": False, "slot": "face", "insulation": 0.02, "durability": 60}, ("mask", "#E6E1D2", "#8A8070"))
item("gas_mask", "utility", "Gas mask", "Gasmaske", "Rubber and glass. Hard to breathe in.", "Gummi og glas. Svær at ånde i.", 0.6, 1, {"stack": False, "slot": "face", "insulation": 0.04, "durability": 200}, ("gasmask", "#3A3E40", "#7A8083"))
item("gas_mask_filter", "utility", "Gas mask filters", "Gasmaskefiltre", "Screw-in filters.", "Filtre til at skrue i.", 0.2, 5, {}, ("canister", "#3A3E40", "#C9A86A"))
item("protective_goggles", "utility", "Protective goggles", "Beskyttelsesbriller", "Clear safety goggles.", "Klare sikkerhedsbriller.", 0.1, 1, {"stack": False, "slot": "face", "durability": 100}, ("goggles", "#7EA6C2", "#3A3E40"))
item("empty_bottle", "utility", "Water bottle", "Drikkedunk", "An empty reusable bottle.", "En tom genbrugsflaske.", 0.2, 3, {}, ("bottle", "#3F6457", "#C9C1AE"))
item("canteen", "utility", "Canteen", "Feltflaske", "An empty army canteen.", "En tom feltflaske.", 0.4, 2, {}, ("canteen", "#4F5A3A", "#3A3E40"))
item("thermos", "frozen", "Thermos", "Termokande", "Keeps a drink warm for hours (empty).", "Holder en drik varm i timer (tom).", 0.5, 1, {"stack": False}, ("thermos", "#7E2A22", "#C9C1AE"))
item("fuel_can", "utility", "Fuel can", "Benzindunk", "An empty jerrycan.", "En tom dunk.", 1.0, 1, {"stack": False}, ("jerrycan", "#5E6467", "#3A3E40"))
item("small_pouch", "utility", "Small pouch", "Lille pung", "A leather pouch.", "En læderpung.", 0.1, 3, {}, ("pouch", "#6E4A30", "#3A2E24"))
item("can_opener", "utility", "Can opener", "Dåseåbner", "Small and important.", "Lille og vigtig.", 0.1, 3, {}, ("key", "#7A8083", "#3A3E40"))
item("fishing_hook", "utility", "Fishing hook", "Fiskekrog", "Hooks. The holes in the ice are far away.", "Kroge. Hullerne i isen er langt væk.", 0.01, 20, {}, ("hook", "#7A8083", "#3A3E40"))
item("fishing_line", "utility", "Fishing line", "Fiskeline", "A spool of line.", "En spole line.", 0.05, 10, {}, ("spool", "#C9C1AE", "#7EA6C2"))
item("needle", "utility", "Needle", "Nål", "A sewing needle.", "En synål.", 0.01, 20, {}, ("needle", "#A9A49A", "#3A3E40"))
item("thread", "utility", "Thread", "Tråd", "A spool of thread.", "En trådrulle.", 0.02, 10, {}, ("spool", "#B5543A", "#C9C1AE"))
item("whistle", "utility", "Whistle", "Fløjte", "Loud. Better left in the pocket.", "Højlydt. Bedst i lommen.", 0.02, 3, {}, ("whistle", "#B59A5A", "#3A3E40"))

# ------------------------------------------------------------------ frozen-world survival
item("thermal_blanket", "frozen", "Thermal blanket", "Varmetæppe", "A foil blanket. Wrap up (+warmth); reusable.", "Et folietæppe. Svøb dig (+varme); kan genbruges.", 0.1, 1, {"stack": False, "use": "warm", "warmth": 15, "reusable": True}, ("blanket", "#C9A86A", "#7A8083"))
item("ice_cleats", "frozen", "Ice cleats", "Isbrodder", "Spikes for your boots.", "Pigge til støvlerne.", 0.4, 1, {"stack": False}, ("cleats", "#5E6467", "#2C3033"))
item("portable_stove", "frozen", "Portable stove", "Spritkoger", "Burns stove fuel for warmth (+warmth, uses 1 stove fuel).", "Brænder brændsel for varme (bruger 1 brændsel).", 1.2, 1, {"stack": False, "use": "warm", "warmth": 30, "reusable": True, "consumes": {"stove_fuel": 1}}, ("stove", "#3A3E40", "#B5543A"))
item("stove_fuel", "frozen", "Stove fuel", "Brændsel til koger", "A small canister for the portable stove.", "En lille dåse til kogeren.", 0.3, 5, {}, ("canister", "#3F6457", "#D9C38A"))
item("snow_container", "frozen", "Snow-filled container", "Beholder med sne", "Melt it in your mouth: water, and cold.", "Smelt den i munden: vand, og kulde.", 1.0, 2, {"use": "drink", "hydration": 15, "warmth": -5}, ("canister", "#E6E8E4", "#7E97A3"))

# ------------------------------------------------------------------ household items and junk
for i, en, da, wt, stack, ic in (("books", "Books", "Bøger", 0.6, 3, "book"), ("photographs", "Photographs", "Fotografier", 0.01, 10, "photo"),
                                 ("old_newspapers", "Old newspapers", "Gamle aviser", 0.2, 5, "note"), ("cigarettes", "Cigarette packs", "Cigaretpakker", 0.03, 10, "pack"),
                                 ("playing_cards", "Playing cards", "Spillekort", 0.1, 3, "cards"), ("watch", "Watches", "Ure", 0.05, 5, "watch"),
                                 ("jewellery", "Jewellery", "Smykker", 0.02, 10, "ring"), ("toys", "Toys", "Legetøj", 0.2, 3, "toy"),
                                 ("toothbrush", "Toothbrushes", "Tandbørster", 0.02, 10, "brush"), ("soap", "Soap", "Sæbe", 0.1, 5, "cube"),
                                 ("wallet", "Wallets", "Punge", 0.1, 5, "pouch"), ("coins", "Coins", "Mønter", 0.01, 30, "coins"),
                                 ("pens", "Pens", "Kuglepenne", 0.01, 10, "pen"), ("notebook", "Notebooks", "Notesbøger", 0.1, 5, "book"),
                                 ("candles", "Candles", "Stearinlys", 0.1, 10, "candle"), ("broken_electronics", "Broken electronics", "Ødelagt elektronik", 0.8, 3, "radio")):
    item(i, "junk", en, da, "Something that belonged to somebody. No use now — or a trade, one day.",
         "Noget der tilhørte nogen. Ingen nytte nu — eller en byttehandel en dag.", wt, stack, {}, (ic, "#8A7A62", "#5A4A3A"))


CATEGORY_KEYS = {"food": "CAT_FOOD", "drink": "CAT_DRINK", "medical": "CAT_MEDICAL", "fire": "CAT_FIRE", "clothing": "CAT_CLOTHING",
                 "weapon": "CAT_WEAPON", "ammo": "CAT_AMMO", "tool": "CAT_TOOL", "material": "CAT_MATERIAL", "mechanical": "CAT_MECHANICAL",
                 "electronics": "CAT_ELECTRONICS", "fuel": "CAT_FUEL", "utility": "CAT_UTILITY", "frozen": "CAT_FROZEN", "junk": "CAT_JUNK", "part": "CAT_PART"}


def build():
    p = os.path.join(ROOT, "content", "items.json")
    d = json.load(open(p))
    items = d["items"]
    loc_p = os.path.join(ROOT, "locale", "strings.json")
    loc = json.load(open(loc_p))
    seen = set()
    for (i, cat, en, da, den, dda, wt, stack, mech, icon) in C:
        assert i not in seen, "duplicate id " + i
        seen.add(i)
        e = items.get(i, {})
        e.setdefault("name_key", "ITEM_" + i.upper())
        e.setdefault("desc_key", "ITEM_" + i.upper() + "_DESC")
        e["cat"] = cat
        e["weight"] = wt
        e["stack_limit"] = stack
        for k, v in mech.items():
            e[k] = v
        e["icon"] = "icon." + i
        items[i] = e
        loc[e["name_key"]] = {"en": en, "da": da}
        if den is not None:
            loc[e["desc_key"]] = {"en": den, "da": dda}
    for i in items:
        assert i in seen, "item %s is not in the catalogue" % i
    d["categories"] = CATEGORY_KEYS
    d["_comment"] = ("Item definitions (iterations 003, 007, 014). 'stack_limit' = units per carrying slot; 'weight' in kg (shown, "
                     "not limiting). Gear (stack: false) are individual items with an id and condition, one slot each. 'use' = what Use does "
                     "(eat / drink / heal / warm / repair_hand / read / map / flashlight). Clothing slots: body, head, hands, feet, legs, back, face. "
                     "Full catalogue and sources: tools/build_catalogue.py. All numbers are EXPLORING prototype values.")
    json.dump(d, open(p, "w"), indent="\t", ensure_ascii=False)
    open(p, "a").write("\n")
    for k, (en, da) in {"CAT_FOOD": ("Food", "Mad"), "CAT_DRINK": ("Drinks", "Drikke"), "CAT_MEDICAL": ("Medical", "Medicin"),
                        "CAT_FIRE": ("Fire & warmth", "Ild & varme"), "CAT_CLOTHING": ("Clothing", "Tøj"), "CAT_WEAPON": ("Weapons", "Våben"),
                        "CAT_AMMO": ("Ammunition", "Ammunition"), "CAT_TOOL": ("Tools", "Værktøj"), "CAT_MATERIAL": ("Materials", "Materialer"),
                        "CAT_MECHANICAL": ("Mechanical parts", "Mekaniske dele"), "CAT_ELECTRONICS": ("Electronics", "Elektronik"),
                        "CAT_FUEL": ("Fuel", "Brændstof"), "CAT_UTILITY": ("Utilities", "Udstyr"), "CAT_FROZEN": ("Frozen-world survival", "Overlevelse i kulden"),
                        "CAT_JUNK": ("Household & junk", "Husgeråd & skrammel"), "CAT_PART": ("Parts", "Dele"), "CAT_ALL": ("All", "Alt")}.items():
        loc[k] = {"en": en, "da": da}
    json.dump(loc, open(loc_p, "w"), indent="\t", ensure_ascii=False)
    open(loc_p, "a").write("\n")
    return len(C)


if __name__ == "__main__":
    print("catalogue items:", build())
