class_name TestCase
extends RefCounted
## Minimal test base: methods named test_* are run by tests/test_runner.gd.

var failures: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func eq(got: Variant, want: Variant, msg: String) -> void:
	if typeof(got) != typeof(want) and not ((got is int or got is float) and (want is int or want is float)):
		failures.append("%s: got %s (%s), want %s" % [msg, str(got), type_string(typeof(got)), str(want)])
	elif got != want:
		failures.append("%s: got %s, want %s" % [msg, str(got), str(want)])
