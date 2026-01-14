@tool
extends MarginContainer

@onready var rebuild_button := $VBoxContainer/ButtonsContainer/RebuildButton
@onready var clean_build_check_button := $VBoxContainer/ButtonsContainer/CleanBuildCheckButton
@onready var log := $VBoxContainer/Log

# Paths configured for this project structure:
# - Swift package is at ../Swift relative to Godot project
# - Libraries go to res://bin
@onready var godot_project_path = ProjectSettings.globalize_path("res://")
@onready var swift_package_path = godot_project_path.path_join("../Swift")
@onready var build_path = swift_package_path.path_join(".build")
@onready var bin_path = ProjectSettings.globalize_path("res://bin")

# Library names matching Package.swift and .env configuration
const LIBRARY_NAME = "SwiftLibrary"

const PROGRESS_MARKERS := ["⠀","⠁","⠂","⠃","⠄","⠅","⠆","⠇","⡀","⡁","⡂","⡃","⡄","⡅","⡆","⡇","⠈","⠉","⠊","⠋","⠌","⠍","⠎","⠏","⡈","⡉","⡊","⡋","⡌","⡍","⡎","⡏","⠐","⠑","⠒","⠓","⠔","⠕","⠖","⠗","⡐","⡑","⡒","⡓","⡔","⡕","⡖","⡗","⠘","⠙","⠚","⠛","⠜","⠝","⠞","⠟","⡘","⡙","⡚","⡛","⡜","⡝","⡞","⡟","⠠","⠡","⠢","⠣","⠤","⠥","⠦","⠧","⡠","⡡","⡢","⡣","⡤","⡥","⡦","⡧","⠨","⠩","⠪","⠫","⠬","⠭","⠮","⠯","⡨","⡩","⡪","⡫","⡬","⡭","⡮","⡯","⠰","⠱","⠲","⠳","⠴","⠵","⠶","⠷","⡰","⡱","⡲","⡳","⡴","⡵","⡶","⡷","⠸","⠹","⠺","⠻","⠼","⠽","⠾","⠿","⡸","⡹","⡺","⡻","⡼","⡽","⡾","⡿","⢀","⢁","⢂","⢃","⢄","⢅","⢆","⢇","⣀","⣁","⣂","⣃","⣄","⣅","⣆","⣇","⢈","⢉","⢊","⢋","⢌","⢍","⢎","⢏","⣈","⣉","⣊","⣋","⣌","⣍","⣎","⣏","⢐","⢑","⢒","⢓","⢔","⢕","⢖","⢗","⣐","⣑","⣒","⣓","⣔","⣕","⣖","⣗","⢘","⢙","⢚","⢛","⢜","⢝","⢞","⢟","⣘","⣙","⣚","⣛","⣜","⣝","⣞","⣟","⢠","⢡","⢢","⢣","⢤","⢥","⢦","⢧","⣠","⣡","⣢","⣣","⣤","⣥","⣦","⣧","⢨","⢩","⢪","⢫","⢬","⢭","⢮","⢯","⣨","⣩","⣪","⣫","⣬","⣭","⣮","⣯","⢰","⢱","⢲","⢳","⢴","⢵","⢶","⢷","⣰","⣱","⣲","⣳","⣴","⣵","⣶","⣷","⢸","⢹","⢺","⢻","⢼","⢽","⢾","⢿","⣸","⣹","⣺","⣻","⣼","⣽","⣾","⣿"]

signal state_changed(working: bool)

func _ready() -> void:
	rebuild_button.pressed.connect(recompile_swift)

	var on_state_changed = func(is_working: bool):
		rebuild_button.disabled = is_working
		clean_build_check_button.disabled = is_working

	state_changed.connect(on_state_changed)

	# Log paths on startup for debugging
	append_log("[color=gray]Swift package: " + swift_package_path + "[/color]")
	append_log("[color=gray]Build path: " + build_path + "[/color]")
	append_log("[color=gray]Bin path: " + bin_path + "[/color]")
	append_log("Ready to build.")

func append_log(string: String) -> void:
	log.append_text(string + "\n")

func wait_process_finished(pid: int, progress_text: String):
	var start_time = Time.get_ticks_msec()
	var i = 0
	var initial_log_text = log.get_parsed_text()
	while OS.is_process_running(pid):
		await get_tree().create_timer(0.1).timeout
		var time_passed = (Time.get_ticks_msec() - start_time) / 1000
		log.text = "%s%s %s %ds" % [initial_log_text, progress_text, PROGRESS_MARKERS[i], time_passed]
		i = (i + 1) % PROGRESS_MARKERS.size()
	log.text = initial_log_text

func recompile_swift() -> void:
	state_changed.emit(true)
	log.clear()

	if OS.is_sandboxed():
		append_log("[color=red]Error: Cannot launch processes - app is sandboxed[/color]")
		state_changed.emit(false)
		return

	# Verify Swift package exists
	if not DirAccess.dir_exists_absolute(swift_package_path):
		append_log("[color=red]Error: Swift package not found at:[/color]")
		append_log(swift_package_path)
		state_changed.emit(false)
		return

	# Ensure bin directory exists
	if not DirAccess.dir_exists_absolute(bin_path):
		var err = DirAccess.make_dir_recursive_absolute(bin_path)
		if err != OK:
			append_log("[color=red]Error creating bin directory[/color]")
			state_changed.emit(false)
			return
		append_log("Created bin directory")

	# Create .gdignore to prevent Godot from scanning build artifacts
	var gdignore_path = bin_path.path_join(".gdignore")
	if not FileAccess.file_exists(gdignore_path):
		var file = FileAccess.open(gdignore_path, FileAccess.WRITE)
		if file:
			file.close()

	# Clean build if requested
	if clean_build_check_button.button_pressed:
		append_log("Cleaning previous build...")
		var pid := OS.create_process(
			"swift", [
				"package", "clean",
				"--package-path", swift_package_path,
				"--build-path", build_path
			], false
		)
		if pid == -1:
			append_log("[color=red]Failed to run swift package clean[/color]")
			state_changed.emit(false)
			return

		await wait_process_finished(pid, "Cleaning")
		append_log("[color=green]Clean complete[/color]")

	# Build Swift library
	append_log("Building " + LIBRARY_NAME + "...")
	var pid := OS.create_process(
		"swift", [
			"build",
			"--product", LIBRARY_NAME,
			"--package-path", swift_package_path,
			"--build-path", build_path
		], false)

	if pid == -1:
		append_log("[color=red]Failed to run swift build[/color]")
		state_changed.emit(false)
		return

	await wait_process_finished(pid, "Building")
	append_log("[color=green]Build complete[/color]")

	# Deploy libraries
	append_log("Deploying libraries...")
	var deploy_success = deploy_libraries()

	if not deploy_success:
		append_log("[color=red]Deployment failed[/color]")
		state_changed.emit(false)
		return

	append_log("[color=green]Deployment complete[/color]")
	append_log("Restarting editor...")
	await get_tree().create_timer(0.5).timeout
	EditorInterface.restart_editor(false)

func deploy_libraries() -> bool:
	var debug_path = build_path.path_join("debug")

	# Source paths (from Swift build output)
	var lib_swiftgodot_src = debug_path.path_join("libSwiftGodot.dylib")
	var lib_library_src = debug_path.path_join("lib" + LIBRARY_NAME + ".dylib")

	# Destination paths (matching .gdextension configuration)
	var swiftgodot_dst = bin_path.path_join("SwiftGodot.dylib")
	var library_dst = bin_path.path_join(LIBRARY_NAME + ".dylib")

	var success = true

	# Copy SwiftGodot.dylib
	if FileAccess.file_exists(lib_swiftgodot_src):
		var err = DirAccess.copy_absolute(lib_swiftgodot_src, swiftgodot_dst)
		if err != OK:
			append_log("[color=red]Failed to copy SwiftGodot.dylib: " + error_string(err) + "[/color]")
			success = false
		else:
			append_log("  → SwiftGodot.dylib")
	else:
		append_log("[color=yellow]Warning: libSwiftGodot.dylib not found[/color]")
		append_log("[color=gray]  " + lib_swiftgodot_src + "[/color]")

	# Copy library dylib
	if FileAccess.file_exists(lib_library_src):
		var err = DirAccess.copy_absolute(lib_library_src, library_dst)
		if err != OK:
			append_log("[color=red]Failed to copy " + LIBRARY_NAME + ".dylib: " + error_string(err) + "[/color]")
			success = false
		else:
			append_log("  → " + LIBRARY_NAME + ".dylib")
	else:
		append_log("[color=red]Error: lib" + LIBRARY_NAME + ".dylib not found[/color]")
		append_log("[color=gray]  " + lib_library_src + "[/color]")
		success = false

	return success
