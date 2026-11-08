#!/usr/bin/env python3
"""Iteration 014 F: contextual, weighted loot pools -> content/loot_pools.json.

Every searchable container with a "pool" rolls its contents ONCE, the first time
it is searched (ScavengeSim -> LootPools.roll), from a seeded stream (world seed
+ container id), so the same world always holds the same things, on every peer,
whoever searches first. Containers with authored "loot"/"gear" (Ashgrove, the
cabin) keep their handcrafted contents.

Pool fields:
  empty  chance the container holds nothing at all
  junk   chance it holds only household junk
  rolls  [min, max] picks from "items"
  items  {item: [weight, min, max]}  (gear items always come one at a time)
  loaded chance a found firearm still has some rounds in it
Firearms are rare everywhere except the police armory (and even there, often gone).
Usage: python3 tools/build_loot_pools.py
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JUNK = ["books", "photographs", "old_newspapers", "cigarettes", "playing_cards", "watch", "jewellery", "toys", "toothbrush",
        "soap", "wallet", "coins", "pens", "notebook", "candles", "broken_electronics"]


def pool(empty, junk, rolls, items, loaded=0.0):
    return {"empty": empty, "junk": junk, "rolls": list(rolls), "items": {k: list(v) for k, v in items.items()}, "loaded": loaded}


# shared building blocks ---------------------------------------------------
KITCHEN = {"canned_food": (8, 1, 2), "canned_soup": (7, 1, 2), "canned_meat": (5, 1, 1), "vegetables": (5, 1, 2), "crackers": (6, 1, 1),
           "coffee": (4, 1, 1), "water_bottle": (5, 1, 1), "can_opener": (3, 1, 1), "matches": (4, 2, 6), "candles": (3, 1, 3),
           "spoiled_food": (5, 1, 1), "glass_bottles": (2, 1, 2), "empty_bottle": (3, 1, 2), "kitchen_knife": (2, 1, 1), "chocolate": (2, 1, 2), "alcohol": (2, 1, 1)}
FRIDGE = {"frozen_food": (8, 1, 2), "spoiled_food": (9, 1, 2), "fresh_meat": (3, 1, 1), "soda": (5, 1, 2), "water_bottle": (3, 1, 1),
          "energy_drink": (2, 1, 1), "snow_container": (1, 1, 1)}
CLOSET = {"padded_jacket": (3, 1, 1), "winter_coat": (1, 1, 1), "hat": (5, 1, 1), "scarf": (5, 1, 1), "gloves": (5, 1, 1), "socks": (7, 1, 1),
          "wool_socks": (4, 1, 1), "trousers": (5, 1, 1), "thermal_underwear": (2, 1, 1), "boots": (2, 1, 1), "cloth": (6, 1, 2),
          "backpack": (1, 1, 1), "sewing_kit": (2, 1, 1), "thermal_blanket": (1, 1, 1)}
BEDROOM = {"painkillers": (4, 1, 3), "bandage": (4, 1, 2), "vitamins": (3, 1, 3), "flashlight": (2, 1, 1), "batteries": (4, 1, 4),
           "watch": (3, 1, 1), "jewellery": (3, 1, 2), "wallet": (3, 1, 1), "books": (3, 1, 1), "candles": (2, 1, 2), "photographs": (3, 1, 3),
           "hand_warmer": (3, 1, 2), "cigarettes": (3, 1, 2), "keys": (2, 1, 1), "handgun": (0.35, 1, 1), "ammo_pistol": (0.8, 3, 9),
           "revolver": (0.2, 1, 1), "ammo_revolver": (0.5, 2, 6), "small_pouch": (1, 1, 1)}
DESK = {"pens": (8, 1, 4), "notebook": (6, 1, 2), "old_newspapers": (4, 1, 2), "batteries": (3, 1, 3), "keys": (4, 1, 1), "keycard": (2, 1, 1),
        "combination_note": (2, 1, 1), "coins": (3, 2, 12), "painkillers": (2, 1, 2), "coffee": (2, 1, 1), "chocolate": (2, 1, 1),
        "field_map": (1, 1, 1), "compass": (1, 1, 1), "handgun": (0.15, 1, 1)}
FILES = {"old_newspapers": (8, 1, 3), "notebook": (5, 1, 2), "books": (4, 1, 2), "pens": (4, 1, 3), "combination_note": (3, 1, 1),
         "field_map": (2, 1, 1), "workshop_manual": (1, 1, 1), "keycard": (1, 1, 1)}
TOOLS = {"hammer": (3, 1, 1), "screwdriver": (5, 1, 1), "wrench": (5, 1, 1), "pliers": (4, 1, 1), "handsaw": (3, 1, 1), "hacksaw": (2, 1, 1),
         "wire_cutters": (2, 1, 1), "crowbar": (2, 1, 1), "nails": (7, 5, 20), "screws": (6, 5, 20), "duct_tape": (5, 1, 2), "glue": (3, 1, 2),
         "wire": (4, 1, 3), "bolts": (4, 2, 8), "multitool": (1, 1, 1), "bolt_cutters": (1, 1, 1), "scrap_metal": (5, 1, 2),
         "sharpening_stone": (2, 1, 1), "fire_axe": (0.6, 1, 1), "motor_oil": (2, 1, 1), "gloves": (2, 1, 1), "protective_goggles": (2, 1, 1), "dust_mask": (2, 1, 1)}
PARTS = {"gears": (5, 1, 2), "springs": (5, 2, 6), "bolts": (6, 2, 8), "bearings": (4, 2, 6), "pipes": (3, 1, 2), "engine_parts": (2, 1, 1),
         "scrap_metal": (6, 1, 3), "sheet_metal": (3, 1, 1), "rubber": (3, 1, 4), "cables": (3, 1, 2), "carburetor": (0.6, 1, 1),
         "stovepipe": (0.6, 1, 1), "electrical_parts": (2, 1, 1), "wrench": (1, 1, 1)}
MATERIALS = {"planks": (6, 1, 3), "wood": (5, 1, 3), "scrap_metal": (5, 1, 3), "sheet_metal": (3, 1, 2), "cement": (2, 1, 1), "nails": (5, 5, 15),
             "rope": (3, 1, 2), "plastic": (4, 2, 6), "rubber": (3, 1, 4), "pipes": (3, 1, 2), "wire": (3, 1, 3), "tinder": (2, 2, 6)}
VEHICLE = {"fuel": (5, 1, 1), "motor_oil": (4, 1, 1), "field_map": (3, 1, 1), "flashlight": (2, 1, 1), "first_aid_kit": (1, 1, 1),
           "bandage": (2, 1, 2), "water_bottle": (3, 1, 1), "crackers": (2, 1, 1), "energy_bar": (3, 1, 2), "jerky": (2, 1, 2),
           "cigarettes": (3, 1, 2), "coins": (3, 2, 10), "flare": (3, 1, 2), "wrench": (2, 1, 1), "duct_tape": (2, 1, 1), "glow_sticks": (1, 1, 3),
           "sunglasses_never": (0, 1, 1)}
VEHICLE.pop("sunglasses_never")
WILD = {"wood": (6, 1, 3), "tinder": (5, 2, 6), "rope": (3, 1, 1), "fresh_meat": (3, 1, 1), "jerky": (3, 1, 2), "thermos": (1, 1, 1),
        "ice_cleats": (1, 1, 1), "snow_goggles": (2, 1, 1), "hand_warmer": (3, 1, 3), "stove_fuel": (2, 1, 2), "fishing_hook": (2, 2, 6),
        "fishing_line": (2, 1, 3), "frozen_food": (3, 1, 1), "snow_container": (3, 1, 1), "glow_sticks": (2, 1, 3), "whistle": (1, 1, 1),
        "compass": (1, 1, 1), "canteen": (1, 1, 1), "sharpened_stick": (2, 1, 1)}

P = {
    # homes (Ashgrove-style, miners' and harbour cottages differ in flavour)
    "home_kitchen": pool(0.15, 0.15, (1, 3), KITCHEN),
    "home_fridge": pool(0.25, 0.05, (1, 2), FRIDGE),
    "home_closet": pool(0.15, 0.10, (1, 3), CLOSET),
    "home_bedroom": pool(0.15, 0.25, (1, 3), BEDROOM, loaded=0.4),
    "household": pool(0.20, 0.45, (1, 2), {"candles": (4, 1, 3), "matches": (4, 2, 6), "batteries": (4, 1, 4), "books": (5, 1, 2),
                                            "soap": (4, 1, 2), "toothbrush": (3, 1, 2), "duct_tape": (2, 1, 1), "glue": (2, 1, 1),
                                            "needle": (2, 1, 4), "thread": (2, 1, 3), "flashlight": (1, 1, 1), "lantern": (1, 1, 1)}),
    "attic": pool(0.20, 0.40, (1, 3), {**CLOSET, "books": (4, 1, 2), "toys": (4, 1, 2), "photographs": (4, 1, 4), "lantern": (2, 1, 1),
                                        "kerosene": (2, 1, 1), "thermal_blanket": (2, 1, 1), "hunting_knife": (1, 1, 1), "binoculars": (1, 1, 1)}),
    "miner_home_kitchen": pool(0.15, 0.15, (1, 3), {**KITCHEN, "jerky": (4, 1, 2), "coffee": (6, 1, 1), "thermos": (2, 1, 1)}),
    "miner_home_fridge": pool(0.30, 0.05, (1, 2), FRIDGE),
    "miner_home_closet": pool(0.15, 0.10, (1, 3), {**CLOSET, "insulated_gloves": (3, 1, 1), "boots": (4, 1, 1), "headlamp": (1, 1, 1)}),
    "miner_home_bedroom": pool(0.15, 0.25, (1, 3), {**BEDROOM, "hunting_rifle": (0.25, 1, 1), "rifle_rounds": (0.6, 2, 6)}, loaded=0.3),
    "harbor_home_kitchen": pool(0.15, 0.15, (1, 3), {**KITCHEN, "canned_meat": (6, 1, 2), "fishing_line": (2, 1, 2)}),
    "harbor_home_fridge": pool(0.30, 0.05, (1, 2), {**FRIDGE, "fresh_meat": (5, 1, 1)}),
    "harbor_home_closet": pool(0.15, 0.10, (1, 3), {**CLOSET, "winter_coat": (2, 1, 1), "wool_socks": (6, 1, 2)}),
    "harbor_home_bedroom": pool(0.15, 0.25, (1, 3), {**BEDROOM, "shotgun": (0.2, 1, 1), "shotgun_shells": (0.6, 2, 6)}, loaded=0.3),
    # the hunter's cabin and the frozen wilderness
    "hunter_cabin": pool(0.10, 0.05, (2, 3), {"hunting_knife": (3, 1, 1), "rope": (4, 1, 2), "jerky": (5, 1, 3), "fresh_meat": (3, 1, 1),
                                              "matches": (4, 2, 6), "firestarter": (3, 1, 2), "charcoal": (2, 1, 3), "hand_warmer": (3, 1, 2), "thermos": (2, 1, 1),
                                              "binoculars": (2, 1, 1), "compass": (2, 1, 1), "field_map": (1, 1, 1), "rifle_rounds": (2, 3, 8),
                                              "hunting_rifle": (0.5, 1, 1), "gun_oil": (2, 1, 1), "gun_cleaning_kit": (1, 1, 1),
                                              "leather": (3, 1, 2), "thermal_blanket": (1, 1, 1), "fishing_hook": (2, 2, 6), "wool_socks": (2, 1, 1)},
                         loaded=0.5),
    "wilderness_frozen": pool(0.15, 0.10, (1, 3), WILD),
    # stores
    "store_counter": pool(0.25, 0.30, (1, 2), {"coins": (6, 3, 15), "cigarettes": (5, 1, 3), "chocolate": (4, 1, 2), "batteries": (4, 1, 4),
                                                "lighter": (4, 1, 2), "matches": (3, 2, 6), "pens": (3, 1, 3), "keys": (2, 1, 1),
                                                "energy_bar": (3, 1, 2), "handgun": (0.2, 1, 1)}, loaded=0.6),
    "grocery_shelf": pool(0.30, 0.05, (1, 3), {"canned_food": (8, 1, 3), "canned_soup": (7, 1, 3), "canned_meat": (5, 1, 2), "vegetables": (5, 1, 2),
                                                "crackers": (6, 1, 2), "chocolate": (4, 1, 3), "energy_bar": (4, 1, 3), "coffee": (4, 1, 2),
                                                "jerky": (3, 1, 2), "soda": (3, 1, 3), "spoiled_food": (3, 1, 1)}),
    "grocery_stock": pool(0.25, 0.05, (2, 3), {"canned_food": (8, 2, 4), "canned_soup": (6, 2, 4), "vegetables": (5, 1, 3), "water_bottle": (6, 1, 2),
                                                "soda": (4, 2, 4), "energy_drink": (3, 1, 2), "crackers": (4, 1, 3), "candles": (2, 2, 4),
                                                "matches": (2, 2, 6), "can_opener": (2, 1, 1)}),
    "grocery_cooler": pool(0.35, 0.0, (1, 2), {"frozen_food": (8, 1, 3), "spoiled_food": (8, 1, 2), "soda": (5, 1, 3), "fresh_meat": (3, 1, 1),
                                                "water_bottle": (4, 1, 2), "energy_drink": (3, 1, 2)}),
    "general_goods": pool(0.20, 0.20, (1, 3), {**KITCHEN, "batteries": (4, 1, 4), "flashlight": (2, 1, 1), "duct_tape": (3, 1, 2),
                                                "hand_warmer": (3, 1, 3), "rope": (2, 1, 1), "matches": (4, 2, 6), "lighter": (2, 1, 1)}),
    "clothing_rack": pool(0.20, 0.05, (1, 3), {"padded_jacket": (4, 1, 1), "winter_coat": (2, 1, 1), "trousers": (6, 1, 1), "thermal_underwear": (3, 1, 1),
                                                "scarf": (5, 1, 1), "hat": (5, 1, 1), "gloves": (5, 1, 1), "cloth": (3, 1, 2)}),
    "clothing_stock": pool(0.20, 0.05, (2, 3), {"socks": (7, 1, 2), "wool_socks": (5, 1, 2), "thermal_underwear": (4, 1, 1), "insulated_gloves": (3, 1, 1),
                                                 "hat": (4, 1, 1), "scarf": (4, 1, 1), "cloth": (5, 1, 3), "thread": (3, 1, 3), "needle": (3, 1, 4)}),
    "clothing_shoes": pool(0.20, 0.05, (1, 2), {"boots": (6, 1, 1), "wool_socks": (4, 1, 2), "socks": (4, 1, 2), "ice_cleats": (2, 1, 1), "leather": (2, 1, 1)}),
    "clothing_gear": pool(0.20, 0.05, (1, 3), {"backpack": (4, 1, 1), "snow_goggles": (4, 1, 1), "thermal_blanket": (3, 1, 1), "insulated_gloves": (3, 1, 1),
                                                "headlamp": (2, 1, 1), "canteen": (3, 1, 1), "small_pouch": (3, 1, 1), "whistle": (2, 1, 1),
                                                "ice_cleats": (2, 1, 1), "compass": (2, 1, 1), "portable_stove": (1, 1, 1), "stove_fuel": (2, 1, 2)}),
    # pharmacy / clinic
    "clinic_medical": pool(0.25, 0.05, (1, 3), {"bandage": (8, 1, 3), "disinfectant": (5, 1, 1), "painkillers": (6, 1, 4), "antibiotics": (3, 1, 2),
                                                 "splint": (3, 1, 1), "first_aid_kit": (2, 1, 1), "medical_syringe": (2, 1, 2), "rags": (3, 1, 3)}),
    "clinic_supply": pool(0.25, 0.05, (2, 3), {"bandage": (6, 2, 5), "rags": (5, 2, 5), "disinfectant": (4, 1, 2), "vitamins": (4, 1, 4),
                                                "dust_mask": (4, 1, 2), "gas_mask_filter": (1, 1, 1), "thermal_blanket": (2, 1, 1), "water_bottle": (2, 1, 1)}),
    "clinic_drugs": pool(0.40, 0.0, (1, 2), {"antibiotics": (6, 1, 3), "painkillers": (6, 1, 5), "medical_syringe": (4, 1, 2), "vitamins": (3, 1, 3)}),
    "clinic_desk": pool(0.20, 0.30, (1, 2), {**DESK, "painkillers": (4, 1, 2), "bandage": (3, 1, 2)}),
    # offices and civic
    "office_desk": pool(0.20, 0.35, (1, 2), DESK),
    "office_files": pool(0.35, 0.40, (1, 2), FILES),
    "civic_emergency": pool(0.10, 0.0, (2, 4), {"water_bottle": (6, 1, 2), "canned_food": (6, 1, 3), "crackers": (5, 1, 2), "first_aid_kit": (2, 1, 1),
                                                 "thermal_blanket": (4, 1, 1), "flashlight": (3, 1, 1), "hand_crank_flashlight": (2, 1, 1),
                                                 "batteries": (4, 2, 6), "glow_sticks": (4, 2, 5), "flare": (3, 1, 3), "handheld_radio": (1, 1, 1),
                                                 "gas_mask": (1, 1, 1), "gas_mask_filter": (2, 1, 2), "propane": (2, 1, 1), "portable_stove": (1, 1, 1), "fire_axe": (1, 1, 1)}),
    "civic_mayor": pool(0.05, 0.10, (2, 3), {"keycard": (4, 1, 1), "combination_note": (3, 1, 1), "alcohol": (4, 1, 1), "cigarettes": (3, 1, 2),
                                             "watch": (3, 1, 1), "jewellery": (2, 1, 3), "revolver": (0.8, 1, 1), "ammo_revolver": (2, 3, 8),
                                             "field_map": (2, 1, 1), "binoculars": (1, 1, 1)}, loaded=0.6),
    "police_desk": pool(0.20, 0.25, (1, 2), {**DESK, "handgun": (0.6, 1, 1), "ammo_pistol": (3, 3, 10), "walkie_talkie": (2, 1, 1),
                                             "flashlight": (3, 1, 1), "padlock": (2, 1, 1)}, loaded=0.4),
    "police_files": pool(0.35, 0.40, (1, 2), {**FILES, "keycard": (2, 1, 1), "keys": (3, 1, 1)}),
    "police_storage": pool(0.20, 0.05, (1, 3), {"flare": (4, 1, 3), "glow_sticks": (3, 2, 5), "first_aid_kit": (2, 1, 1), "handheld_radio": (2, 1, 1),
                                                 "walkie_talkie": (3, 1, 1), "batteries": (4, 2, 6), "padlock": (3, 1, 2), "bolt_cutters": (1, 1, 1),
                                                 "gas_mask": (1, 1, 1), "protective_goggles": (2, 1, 1), "ammo_pistol": (2, 4, 12)}),
    "police_evidence": pool(0.25, 0.30, (1, 2), {"lockpick": (4, 1, 1), "jewellery": (4, 1, 4), "wallet": (3, 1, 2), "watch": (3, 1, 2),
                                                  "cigarettes": (3, 1, 3), "machete": (1, 1, 1), "kitchen_knife": (2, 1, 1), "baseball_bat": (1, 1, 1),
                                                  "revolver": (0.5, 1, 1), "ammo_revolver": (1, 2, 6)}, loaded=0.3),
    # the armory: where the guns were. Most of it is gone.
    "police_armory": pool(0.45, 0.0, (1, 2), {"handgun": (3, 1, 1), "shotgun": (2, 1, 1), "military_rifle": (0.8, 1, 1), "ammo_pistol": (5, 6, 16),
                                              "shotgun_shells": (4, 4, 10), "rifle_rounds": (2, 4, 10), "loaded_magazine": (2, 1, 2),
                                              "gun_cleaning_kit": (2, 1, 1), "gun_oil": (2, 1, 2), "weapon_parts": (2, 1, 2)}, loaded=0.5),
    # workshops, industry, utility
    "workshop_tools": pool(0.15, 0.05, (1, 3), TOOLS),
    "workshop_parts": pool(0.15, 0.05, (1, 3), PARTS),
    "industrial_parts": pool(0.20, 0.05, (1, 3), PARTS),
    "industrial_materials": pool(0.20, 0.05, (1, 3), MATERIALS),
    "industrial_scrap": pool(0.15, 0.20, (1, 3), {"scrap_metal": (8, 1, 3), "sheet_metal": (3, 1, 1), "pipes": (4, 1, 2), "metal_pipe": (2, 1, 1),
                                                  "broken_electronics": (4, 1, 2), "rubber": (3, 1, 3), "bolts": (3, 2, 6), "cables": (2, 1, 2)}),
    "worker_locker": pool(0.25, 0.30, (1, 2), {"gloves": (5, 1, 1), "insulated_gloves": (2, 1, 1), "boots": (3, 1, 1), "hat": (3, 1, 1),
                                               "thermos": (3, 1, 1), "cigarettes": (4, 1, 2), "energy_bar": (3, 1, 2), "headlamp": (1, 1, 1),
                                               "dust_mask": (3, 1, 1), "protective_goggles": (3, 1, 1), "padlock": (2, 1, 1), "keys": (2, 1, 1),
                                               "multitool": (1, 1, 1), "playing_cards": (3, 1, 1)}),
    "warehouse_freight": pool(0.30, 0.10, (1, 3), {"planks": (5, 1, 3), "plastic": (4, 2, 6), "rope": (3, 1, 2), "canned_food": (3, 2, 4),
                                                   "water_bottle": (3, 1, 2), "cement": (2, 1, 1), "nails": (3, 10, 25), "batteries": (2, 2, 6),
                                                   "timber_frame": (0.5, 1, 1), "fuel_can": (1, 1, 1), "glass_bottles": (2, 2, 4)}),
    "utility_desk": pool(0.25, 0.30, (1, 2), {**DESK, "fuses": (4, 2, 6), "cables": (3, 1, 2)}),
    "utility_files": pool(0.35, 0.35, (1, 2), {**FILES, "workshop_manual": (3, 1, 1)}),
    "utility_storage": pool(0.15, 0.05, (2, 3), {"electrical_parts": (5, 1, 2), "cables": (6, 1, 3), "fuses": (6, 2, 8), "circuit_boards": (4, 1, 2),
                                                  "batteries": (4, 2, 6), "wire": (4, 1, 3), "wire_cutters": (2, 1, 1), "grow_light": (0.8, 1, 1),
                                                  "insulated_gloves": (2, 1, 1), "hand_crank_flashlight": (1, 1, 1)}),
    "electronics": pool(0.25, 0.20, (1, 3), {"batteries": (6, 2, 8), "circuit_boards": (4, 1, 2), "cables": (4, 1, 2), "fuses": (3, 2, 6),
                                              "handheld_radio": (2, 1, 1), "walkie_talkie": (2, 1, 1), "broken_electronics": (5, 1, 2),
                                              "electrical_parts": (3, 1, 1), "flashlight": (2, 1, 1)}),
    "fuel_depot": pool(0.25, 0.0, (1, 2), {"fuel": (6, 1, 2), "diesel": (5, 1, 2), "kerosene": (3, 1, 1), "propane": (3, 1, 1), "motor_oil": (4, 1, 1),
                                           "fuel_can": (2, 1, 1), "stove_fuel": (2, 1, 2), "charcoal": (3, 1, 4)}),
    # the mine
    "mine_office_desk": pool(0.20, 0.30, (1, 2), {**DESK, "field_map": (3, 1, 1), "compass": (2, 1, 1), "coffee": (3, 1, 1)}),
    "mine_office_files": pool(0.35, 0.40, (1, 2), {**FILES, "field_map": (3, 1, 1)}),
    "mine_office_storage": pool(0.20, 0.05, (1, 3), {"headlamp": (3, 1, 1), "batteries": (5, 2, 6), "rope": (4, 1, 2), "first_aid_kit": (1, 1, 1),
                                                      "dust_mask": (4, 1, 2), "gas_mask": (1, 1, 1), "gas_mask_filter": (2, 1, 2),
                                                      "pickaxe": (1, 1, 1), "insulated_gloves": (2, 1, 1), "thermos": (2, 1, 1)}),
    "mine_lamps": pool(0.20, 0.0, (1, 2), {"headlamp": (5, 1, 1), "lantern": (4, 1, 1), "batteries": (6, 2, 6), "kerosene": (3, 1, 1),
                                           "glow_sticks": (3, 2, 4), "hand_crank_flashlight": (1, 1, 1), "candles": (2, 2, 4)}),
    "mine_tools": pool(0.15, 0.05, (1, 3), {"pickaxe": (4, 1, 1), "shovel": (4, 1, 1), "crowbar": (2, 1, 1), "hammer": (3, 1, 1), "rope": (4, 1, 2),
                                            "wrench": (2, 1, 1), "bolts": (3, 2, 6), "scrap_metal": (3, 1, 2), "ice_pick": (1, 1, 1)}),
    "mine_store": pool(0.25, 0.05, (1, 3), {"planks": (5, 1, 3), "wood": (4, 1, 3), "rope": (4, 1, 2), "nails": (4, 5, 15), "cement": (2, 1, 1),
                                            "water_bottle": (2, 1, 1), "canned_food": (3, 1, 2), "jerky": (2, 1, 2), "diesel": (2, 1, 1),
                                            "pipes": (2, 1, 2), "timber_frame": (0.4, 1, 1)}),
    "mine_deep": pool(0.25, 0.10, (1, 3), {"pickaxe": (2, 1, 1), "headlamp": (2, 1, 1), "thermos": (2, 1, 1), "canned_meat": (3, 1, 1),
                                           "batteries": (3, 2, 4), "rope": (2, 1, 1), "engine_parts": (1, 1, 1), "gears": (3, 1, 2),
                                           "bearings": (3, 2, 5), "jewellery": (2, 1, 2), "photographs": (2, 1, 2), "hunting_knife": (1, 1, 1),
                                           "handgun": (0.3, 1, 1)}, loaded=0.6),
    # harbour
    "marine": pool(0.20, 0.10, (1, 3), {"rope": (8, 1, 3), "fishing_hook": (4, 2, 8), "fishing_line": (4, 1, 3), "flare": (4, 1, 2), "motor_oil": (3, 1, 1),
                                        "diesel": (3, 1, 1), "canned_meat": (3, 1, 2), "rubber": (3, 1, 3), "whistle": (2, 1, 1), "wire": (2, 1, 2),
                                        "sheet_metal": (1, 1, 1), "binoculars": (1, 1, 1), "compass": (2, 1, 1)}),
    "marine_safety": pool(0.15, 0.0, (1, 3), {"flare": (6, 1, 3), "thermal_blanket": (5, 1, 1), "first_aid_kit": (2, 1, 1), "whistle": (4, 1, 1),
                                              "water_bottle": (3, 1, 2), "glow_sticks": (3, 2, 4), "hand_warmer": (3, 1, 3), "rope": (2, 1, 1)}),
    "harbor_office_desk": pool(0.20, 0.30, (1, 2), {**DESK, "compass": (3, 1, 1), "binoculars": (2, 1, 1), "alcohol": (2, 1, 1)}),
    "harbor_office_files": pool(0.35, 0.40, (1, 2), {**FILES, "field_map": (3, 1, 1)}),
    "harbor_office_storage": pool(0.20, 0.05, (1, 3), {"flare": (3, 1, 2), "rope": (4, 1, 2), "batteries": (3, 2, 4), "lantern": (2, 1, 1),
                                                       "kerosene": (2, 1, 1), "handheld_radio": (1, 1, 1), "padlock": (2, 1, 1), "fuel_can": (1, 1, 1)}),
    "harbor_radio": pool(0.15, 0.10, (1, 2), {"handheld_radio": (4, 1, 1), "walkie_talkie": (3, 1, 1), "batteries": (5, 2, 6), "cables": (3, 1, 2),
                                              "circuit_boards": (3, 1, 2), "fuses": (2, 2, 4), "flashlight": (2, 1, 1)}),
    "harbor_cargo": pool(0.30, 0.10, (1, 3), {"canned_food": (4, 2, 4), "canned_meat": (4, 1, 3), "plastic": (4, 2, 6), "rubber": (3, 2, 5),
                                              "sheet_metal": (2, 1, 2), "engine_parts": (2, 1, 1), "rope": (3, 1, 2), "batteries": (2, 2, 6),
                                              "alcohol": (2, 1, 2), "cigarettes": (2, 2, 4), "circuit_boards": (1, 1, 2)}),
    "cannery_cold": pool(0.35, 0.0, (1, 2), {"frozen_food": (8, 1, 3), "fresh_meat": (5, 1, 2), "spoiled_food": (6, 1, 2), "snow_container": (2, 1, 1)}),
    "cannery_tins": pool(0.25, 0.0, (1, 3), {"canned_meat": (8, 1, 3), "canned_food": (5, 1, 3), "canned_soup": (4, 1, 2), "can_opener": (2, 1, 1),
                                             "spoiled_food": (2, 1, 1)}),
    # vehicles
    "vehicle_car": pool(0.25, 0.25, (1, 2), VEHICLE),
    "vehicle_truck": pool(0.20, 0.15, (1, 3), {**VEHICLE, "fuel": (6, 1, 2), "diesel": (4, 1, 1), "fuel_can": (2, 1, 1), "crowbar": (1, 1, 1),
                                                "rope": (2, 1, 1), "engine_parts": (1, 1, 1)}),
    "vehicle_police": pool(0.20, 0.05, (1, 3), {**VEHICLE, "flare": (5, 1, 3), "first_aid_kit": (2, 1, 1), "walkie_talkie": (3, 1, 1),
                                                 "shotgun": (0.6, 1, 1), "shotgun_shells": (2, 2, 6), "ammo_pistol": (2, 3, 8)}, loaded=0.4),
}

# Iteration 015 D: lockpicks turn up in toolboxes, workers' lockers and old cabins.
for _n, _w in {"workshop_tools": 2, "worker_locker": 1.5, "hunter_cabin": 1.5, "attic": 1, "industrial_parts": 1}.items():
    P[_n]["items"]["lockpick"] = (_w, 1, 1)


if __name__ == "__main__":
    items = json.load(open(os.path.join(ROOT, "content", "items.json")))["items"]
    for name, pl in P.items():
        for it in list(pl["items"]) :
            assert it in items, f"{name}: unknown item {it}"
    for j in JUNK:
        assert j in items, j
    out = {"_comment": "Contextual weighted loot pools (iteration 014 F, tools/build_loot_pools.py). A pooled container rolls once, "
                       "on its first search, from the world seed + its id. EXPLORING prototype values.",
           "junk": JUNK, "pools": P}
    with open(os.path.join(ROOT, "content", "loot_pools.json"), "w") as f:
        json.dump(out, f, indent="\t"); f.write("\n")
    print("loot pools:", len(P))
