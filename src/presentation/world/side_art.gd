class_name SideArt
extends RefCounted
## Side-view art (iteration 012 experiment): which side-view picture stands in
## for a top-down one, and where things sit in the cross-section. Only the
## presentation changes; ids, state and rules stay the same. Every side-view
## picture is a normal template (assets/templates/side/…) and can be replaced
## like any other asset.

const MAP := {
	"bunker.ladder_up": "side.ladder",
	"bunker.ladder_down_slab": "side.hatch_down",
	"world.storage_locker": "side.storage",
	"world.generator_off": "side.generator_off",
	"world.generator_on": "side.generator_on",
	"world.purifier_off": "side.purifier_off",
	"world.purifier_on": "side.purifier_on",
	"world.lamp_off": "side.lamp_off",
	"world.lamp_on": "side.lamp_on",
	"world.bedroll": "side.bedroll",
	"world.timber_pile_empty": "side.timber_empty",
	"world.timber_pile_small": "side.timber_small",
	"world.timber_pile_medium": "side.timber_medium",
	"world.timber_pile_large": "side.timber_large",
	"bunker.support_exposed": "side.scaffold_exposed",
	"bunker.support_building": "side.scaffold_building",
	"bunker.support_done": "side.scaffold_done",
	"build.wall_wood": "side.wall_wood",
	"build.wall_metal": "side.wall_metal",
	"build.wall_concrete": "side.wall_concrete",
	"build.barricade_wood": "side.wall_wood",
	"build.barricade_metal": "side.wall_metal",
	"build.barricade_concrete": "side.wall_concrete",
	"build.door_closed": "side.door_closed",
	"build.door_open": "side.door_open",
	"build.crate": "side.crate",
	"build.workbench": "side.workbench",
	"build.stove": "side.stove",
	"build.planter_empty": "side.planter_empty",
	"build.planter_growing": "side.planter_growing",
	"build.planter_ripe": "side.planter_ripe",
}
## Pictures that stretch from the floor to the ceiling of their open space.
const FULL_HEIGHT := ["side.scaffold_exposed", "side.scaffold_building", "side.scaffold_done"]
## Pictures that continue up through the ceiling into the shaft above (screen px beyond the ceiling).
const THROUGH_CEILING := {"side.ladder": 150.0}


static func map(id: String) -> String:
	var s: String = MAP.get(id, id)
	return s if AssetCatalog.has(s) else id


## Screen position in the side view for an entity of a bunker level.
static func entity_screen(region: RegionState, def: Dictionary) -> Vector2:
	var p := Content.entity_position(def)
	var where := SideSection.hang(region, p) if str(def.get("type", "")) == "lamp" else SideSection.rest(region, p)
	return SideSection.to_screen(region, where)


## Screen position of anything else standing in the level (objects, people).
static func rest_screen(region: RegionState, plan: Vector2) -> Vector2:
	return SideSection.to_screen(region, SideSection.rest(region, plan))


## Screen height of the open space above a plan point (floor to ceiling).
static func open_height(region: RegionState, plan: Vector2) -> float:
	var f := SideSection.floor_y(region, plan.x, plan.y)
	var c := SideSection.ceiling_y(region, plan.x, plan.y)
	return maxf(40.0, (f - c) * SideSection.ROW_SCALE)
