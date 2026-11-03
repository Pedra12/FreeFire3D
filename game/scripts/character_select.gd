extends Control

const CLASS_IDS := ["assault","medic","support","recon"]
var selected_index := 0
var detail_label: Label
var class_buttons: Array[Button] = []

func _ready() -> void:
	_build_screen()
	_select_class(0)

func _build_screen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.025,0.045,0.085,1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation",18)
	root.offset_left=42; root.offset_top=28; root.offset_right=-42; root.offset_bottom=-28
	add_child(root)
	var title := Label.new()
	title.text="CLOCKTOWER  |  SELEÇÃO DE OPERADOR"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",30)
	title.add_theme_color_override("font_color",Color(0.88,0.94,1))
	root.add_child(title)
	var subtitle := Label.new()
	subtitle.text="EQUIPE AZUL  •  ESCOLHA SUA CLASSE E ARMAMENTO"
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size",16)
	subtitle.add_theme_color_override("font_color",Color(0.48,0.72,0.96))
	root.add_child(subtitle)
	var cards := HBoxContainer.new()
	cards.size_flags_vertical=Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation",12)
	root.add_child(cards)
	for i in range(CLASS_IDS.size()):
		var data:Dictionary=MatchConfig.CLASSES[CLASS_IDS[i]]
		var button:=Button.new()
		button.text=String(data["title"])+"\n\n"+String(data["role"])+"\n\n"+String(data["weapon_name"])
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.size_flags_vertical=Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",20)
		button.add_theme_color_override("font_color",Color(0.92,0.96,1))
		button.pressed.connect(_select_class.bind(i))
		cards.add_child(button)
		class_buttons.append(button)
	detail_label=Label.new()
	detail_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	detail_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size",18)
	detail_label.add_theme_color_override("font_color",Color(0.78,0.88,0.98))
	root.add_child(detail_label)
	var start:=Button.new()
	start.text="CONFIRMAR E ENTRAR NA PARTIDA  •  4v4"
	start.custom_minimum_size=Vector2(0,72)
	start.add_theme_font_size_override("font_size",22)
	start.add_theme_color_override("font_color",Color.WHITE)
	start.add_theme_color_override("font_hover_color",Color(0.9,1,0.9))
	start.pressed.connect(_start_match)
	root.add_child(start)

func _select_class(index:int) -> void:
	selected_index=clampi(index,0,CLASS_IDS.size()-1)
	var class_id:=CLASS_IDS[selected_index]
	MatchConfig.set_selected(class_id)
	var data:Dictionary=MatchConfig.get_selected()
	detail_label.text="CLASSE: "+String(data["title"])+"   |   ARMA: "+String(data["weapon_name"])+"\n"+String(data["special"])
	for i in range(class_buttons.size()):
		class_buttons[i].modulate=Color(1,1,1,1) if i==selected_index else Color(0.62,0.68,0.78,1)

func _start_match() -> void:
	MatchConfig.match_started=true
	get_tree().change_scene_to_file("res://scenes/main.tscn")
