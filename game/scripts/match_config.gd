extends Node

const CLASSES := {
	"assault": {"title":"ASSALTO","role":"Linha de frente","weapon":"assault_rifle","weapon_name":"Rifle de assalto","special":"Equilibrado: dano e alcance médios","color":Color(0.18,0.48,0.95)},
	"medic": {"title":"MÉDICO","role":"Suporte de equipe","weapon":"smg","weapon_name":"Submetralhadora","special":"Mobilidade e combate próximo","color":Color(0.20,0.78,0.48)},
	"support": {"title":"SUPORTE","role":"Controle de área","weapon":"shotgun","weapon_name":"Escopeta","special":"Alta potência a curta distância","color":Color(0.98,0.58,0.16)},
	"recon": {"title":"RECON","role":"Precisão e cobertura","weapon":"awm","weapon_name":"Rifle de precisão AWM","special":"Alto dano em longa distância","color":Color(0.70,0.38,0.95)}
}
var selected_class: String = "assault"
var match_started: bool = false

func get_selected() -> Dictionary:
	return CLASSES.get(selected_class, CLASSES["assault"])

func set_selected(class_id: String) -> void:
	if CLASSES.has(class_id):
		selected_class = class_id
