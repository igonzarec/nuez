extends CanvasLayer
## Selector enfocado; PauseMenu es dueño de la pausa y restaura el contexto al cerrar.
signal chosen(equipped: bool)
signal cancelled
@onready var equip: Button = %Equip
@onready var unequip: Button = %Unequip
@onready var error_label: Label = %Error

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	equip.pressed.connect(func() -> void: chosen.emit(true))
	unequip.pressed.connect(func() -> void: chosen.emit(false))
	%Cancel.pressed.connect(func() -> void: cancelled.emit())
	refresh()

func refresh() -> void:
	var equipped := TrailWardrobe.is_equipped("christmas_hat")
	equip.disabled = equipped
	unequip.disabled = not equipped
	(unequip if equipped else equip).grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()

func show_save_error() -> void:
	error_label.text = "No se pudo guardar. No se cambió el gorro."
	error_label.show()
