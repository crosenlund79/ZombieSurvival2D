extends Node
## Runs every tests/unit/test_*.gd. Usage (headless):
##   godot --headless --path . res://tests/run_tests.tscn
## Writes tests/_out/unit_results.json and exits with code 1 on failure.

func _ready() -> void:
	await get_tree().process_frame
	var total := 0
	var failed := 0
	var report := []
	var files := Array(DirAccess.get_files_at("res://tests/unit"))
	files.sort()
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		var script := load("res://tests/unit/" + f) as GDScript
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var tc: TestCase = script.new()
			total += 1
			await tc.call(name)
			var ok := tc.failures.is_empty()
			if not ok:
				failed += 1
			report.append({"test": f + ":" + name, "pass": ok, "failures": tc.failures})
			print(("PASS " if ok else "FAIL ") + f + ":" + name + ("" if ok else "  " + str(tc.failures)))
	var check := ContentCheck.new()
	check.run()
	print("\n--- content check ---\n" + check.report_text())
	var content_ok := check.count("FAIL") == 0
	print("\n%d/%d unit tests passed; content check %s" % [total - failed, total, "PASS" if content_ok else "FAIL"])
	DirAccess.make_dir_recursive_absolute("res://tests/_out")
	var out := FileAccess.open("res://tests/_out/unit_results.json", FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify({"tests": report, "content": check.lines}, "\t"))
	get_tree().quit(0 if failed == 0 and content_ok else 1)
