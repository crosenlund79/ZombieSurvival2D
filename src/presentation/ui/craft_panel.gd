class_name CraftPanel
extends RefCounted
## Workbench panel (filled in by the crafting milestone).


static func open_for(anchor: StructureView, rid: String, oid: String) -> void:
	MachinePanel.open(anchor, rid, oid, anchor.panel_data, func(action: String, arg: String) -> void:
		Session.request_object(oid, action, arg))
