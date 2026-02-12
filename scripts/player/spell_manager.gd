extends Node
class_name SpellManager
## Manages player's equipped spells and spell inventory

signal spell_equipped(slot: int, spell_id: String)
signal spell_cast(spell_id: String)
signal active_slot_changed(slot: int)

const MAX_SPELL_SLOTS: int = 5

@export var player: Node = null

# Equipped spells (slot index -> spell_id)
var equipped_spells: Dictionary = {}

# Active spell slot
var active_slot: int = 0

# Spell instances (spell_id -> SpellBase node)
var spell_instances: Dictionary = {}

# Reference to player's mana manager
var mana_manager: ManaManager = null


func _ready() -> void:
	# Find mana manager
	if player and player.has_node("ManaManager"):
		mana_manager = player.get_node("ManaManager")

	# Equip some default spells for testing
	_equip_default_spells()


func _equip_default_spells() -> void:
	# Equip starter spells
	equip_spell(0, "fireball")
	equip_spell(1, "ice_shard")
	equip_spell(2, "magic_missile")


func equip_spell(slot: int, spell_id: String) -> bool:
	if slot < 0 or slot >= MAX_SPELL_SLOTS:
		push_warning("Invalid spell slot: %d" % slot)
		return false

	if not SpellRegistry.SPELLS.has(spell_id):
		push_warning("Unknown spell: %s" % spell_id)
		return false

	# Unequip previous spell in this slot
	if equipped_spells.has(slot):
		_unequip_spell(slot)

	# Create spell instance
	var spell_instance := _create_spell_instance(spell_id)
	if not spell_instance:
		push_warning("Failed to create spell instance: %s" % spell_id)
		return false

	# Store references
	equipped_spells[slot] = spell_id
	spell_instances[spell_id] = spell_instance

	# Emit signal
	spell_equipped.emit(slot, spell_id)

	return true


func _unequip_spell(slot: int) -> void:
	if not equipped_spells.has(slot):
		return

	var spell_id: String = equipped_spells[slot]

	# Remove spell instance
	if spell_instances.has(spell_id):
		var spell_instance = spell_instances[spell_id]
		if is_instance_valid(spell_instance):
			spell_instance.queue_free()
		spell_instances.erase(spell_id)

	# Remove from equipped
	equipped_spells.erase(slot)


func _create_spell_instance(spell_id: String) -> SpellBase:
	var spell_data := SpellRegistry.get_spell_data(spell_id)
	if spell_data.is_empty():
		return null

	var spell_type: int = spell_data.get("spell_type", 0)
	var spell_instance: SpellBase = null

	# Create appropriate spell subclass
	match spell_type:
		SpellRegistry.SpellType.PROJECTILE:
			spell_instance = ProjectileSpell.new()
		SpellRegistry.SpellType.BEAM:
			spell_instance = BeamSpell.new()
		SpellRegistry.SpellType.AOE:
			spell_instance = AOESpell.new()
		_:
			# Default to base spell
			spell_instance = SpellBase.new()

	if spell_instance:
		spell_instance.name = "Spell_%s" % spell_id
		spell_instance.spell_id = spell_id
		spell_instance.owner_player = player

		# Add to scene tree
		if player:
			player.add_child(spell_instance)
		else:
			add_child(spell_instance)

		# Connect signals
		spell_instance.spell_cast.connect(_on_spell_cast)
		spell_instance.mana_changed.connect(_on_spell_mana_changed)

	return spell_instance


func try_cast_active_spell() -> bool:
	return try_cast_spell(active_slot)


func try_cast_spell(slot: int) -> bool:
	if not equipped_spells.has(slot):
		return false

	var spell_id: String = equipped_spells[slot]
	if not spell_instances.has(spell_id):
		return false

	var spell: SpellBase = spell_instances[spell_id]

	# Check mana
	if mana_manager and not mana_manager.has_enough_mana(spell.mana_cost):
		return false

	# Try to cast
	var cast_success := spell.try_cast()

	# Consume mana if cast was successful
	if cast_success and mana_manager:
		mana_manager.consume_mana(spell.mana_cost)

	return cast_success


func set_active_slot(slot: int) -> void:
	if slot < 0 or slot >= MAX_SPELL_SLOTS:
		return

	if active_slot != slot:
		active_slot = slot
		active_slot_changed.emit(slot)


func next_spell() -> void:
	active_slot = (active_slot + 1) % MAX_SPELL_SLOTS
	active_slot_changed.emit(active_slot)


func previous_spell() -> void:
	active_slot = (active_slot - 1 + MAX_SPELL_SLOTS) % MAX_SPELL_SLOTS
	active_slot_changed.emit(active_slot)


func get_active_spell() -> SpellBase:
	if not equipped_spells.has(active_slot):
		return null

	var spell_id: String = equipped_spells[active_slot]
	if spell_instances.has(spell_id):
		return spell_instances[spell_id]

	return null


func get_spell_in_slot(slot: int) -> SpellBase:
	if not equipped_spells.has(slot):
		return null

	var spell_id: String = equipped_spells[slot]
	if spell_instances.has(spell_id):
		return spell_instances[spell_id]

	return null


func get_spell_id_in_slot(slot: int) -> String:
	return equipped_spells.get(slot, "")


func has_spell(spell_id: String) -> bool:
	return spell_instances.has(spell_id)


func is_spell_on_cooldown(slot: int) -> bool:
	var spell := get_spell_in_slot(slot)
	if not spell:
		return false
	return spell.is_on_cooldown


func get_spell_cooldown_remaining(slot: int) -> float:
	var spell := get_spell_in_slot(slot)
	if not spell:
		return 0.0
	return spell.get_cooldown_remaining()


func cancel_active_spell() -> void:
	var spell := get_active_spell()
	if spell:
		spell.cancel_cast()


func _on_spell_cast(spell_id: String) -> void:
	spell_cast.emit(spell_id)


func _on_spell_mana_changed(current: int, maximum: int) -> void:
	# Spells share mana with the player, so sync it
	if mana_manager:
		# This is handled by the mana_manager, spells just query it
		pass


# Utility functions
func get_all_equipped_spell_ids() -> Array[String]:
	var result: Array[String] = []
	for slot in equipped_spells:
		result.append(equipped_spells[slot])
	return result


func get_spell_count() -> int:
	return equipped_spells.size()


func is_slot_empty(slot: int) -> bool:
	return not equipped_spells.has(slot)


# Save/Load support
func get_save_data() -> Dictionary:
	return {
		"equipped_spells": equipped_spells.duplicate(),
		"active_slot": active_slot
	}


func load_save_data(data: Dictionary) -> void:
	# Clear existing spells
	for slot in equipped_spells.keys():
		_unequip_spell(slot)

	# Load equipped spells
	var saved_spells: Dictionary = data.get("equipped_spells", {})
	for slot in saved_spells:
		var spell_id: String = saved_spells[slot]
		equip_spell(int(slot), spell_id)

	# Load active slot
	active_slot = data.get("active_slot", 0)
	active_slot_changed.emit(active_slot)
