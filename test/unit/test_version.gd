extends GutTest
## The version name lives in project.godot (config/version) and must follow
## VERSIONING.md: "0.1 Dev 1", "0.1 Beta 2" or "0.1". The release pipeline
## (tools/version.sh) refuses anything else.

const PATTERN := "^(0|[1-9][0-9]{0,3})\\.(0|[1-9][0-9]{0,3})( (Dev|Beta) [1-9][0-9]{0,3})?$"


func test_project_version_follows_the_scheme() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var re := RegEx.create_from_string(PATTERN)
	assert_not_null(re.search(version), "config/version '%s' must look like '0.1 Dev 1', '0.1 Beta 2' or '0.1'" % version)


func test_pattern_matches_the_documented_examples() -> void:
	var re := RegEx.create_from_string(PATTERN)
	for good: String in ["0.1 Dev 1", "0.1 Dev 12", "0.1 Beta 2", "0.1", "1.0"]:
		assert_not_null(re.search(good), good)
	for bad: String in ["0.3.0", "V0.1 Dev 1", "0.1 dev 1", "0.1 Dev 0", "0.1 Alpha 1", "0.1-dev.1"]:
		assert_null(re.search(bad), bad)
