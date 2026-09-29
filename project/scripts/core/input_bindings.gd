class_name TrailInput
extends RefCounted

static func install() -> void:
	var keys := {"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "interact": [KEY_E], "pause": [KEY_ESCAPE]}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.18)
		InputMap.action_erase_events(action)
		for key: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	var buttons := {"jump": JOY_BUTTON_A, "interact": JOY_BUTTON_X, "pause": JOY_BUTTON_START, "sprint": JOY_BUTTON_LEFT_SHOULDER, "ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B, "ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN, "ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT}
	for action: String in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
	# R1 también activa sprint; L1 se conserva para no romper controles existentes.
	var sprint_r1 := InputEventJoypadButton.new()
	sprint_r1.button_index = JOY_BUTTON_RIGHT_SHOULDER
	if not InputMap.action_has_event("sprint", sprint_r1):
		InputMap.action_add_event("sprint", sprint_r1)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0], "move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0], "look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0], "look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0]}
	for action: String in axes:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		var event := InputEventJoypadMotion.new()
		event.axis = axes[action][0]
		event.axis_value = axes[action][1]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
