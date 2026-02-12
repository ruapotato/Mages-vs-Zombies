# Quick Start Guide - Spell System

## 1. Register SpellRegistry as Autoload

In Godot Editor:
1. Go to **Project > Project Settings > Autoload**
2. Add `res://scripts/autoload/spell_registry.gd`
3. Set Node Name to `SpellRegistry`

## 2. Add Components to Player

```gdscript
# player.gd
extends CharacterBody3D

# Add these nodes in the scene tree
@onready var mana_manager: ManaManager = $ManaManager
@onready var spell_manager: SpellManager = $SpellManager

func _ready():
    # Link spell manager to player
    spell_manager.player = self

    # Connect signals
    spell_manager.spell_cast.connect(_on_spell_cast)
    mana_manager.mana_changed.connect(_on_mana_changed)
    mana_manager.mana_depleted.connect(_on_mana_depleted)

func _input(event):
    # Cast spell
    if event.is_action_pressed("cast_spell"):
        spell_manager.try_cast_active_spell()

    # Cycle spells
    if event.is_action_pressed("next_spell"):
        spell_manager.next_spell()

    if event.is_action_pressed("previous_spell"):
        spell_manager.previous_spell()

    # Quick cast spell slots (1-5)
    for i in range(5):
        if event.is_action_pressed("spell_%d" % (i + 1)):
            spell_manager.set_active_slot(i)
            spell_manager.try_cast_active_spell()

func _on_spell_cast(spell_id: String):
    print("Cast spell: %s" % spell_id)

func _on_mana_changed(current: int, maximum: int):
    # Update UI
    var percent = float(current) / float(maximum) * 100.0
    print("Mana: %d/%d (%.1f%%)" % [current, maximum, percent])

func _on_mana_depleted():
    print("Out of mana!")
```

## 3. Add Player Scene Nodes

In the Player scene, add these as children:

```
Player (CharacterBody3D)
├── ManaManager (Node)
│   └── Script: res://scripts/player/mana_manager.gd
└── SpellManager (Node)
    └── Script: res://scripts/player/spell_manager.gd
```

## 4. Set Up Input Actions

In **Project > Project Settings > Input Map**, add:

```
cast_spell        -> Left Mouse Button
next_spell        -> Mouse Wheel Down
previous_spell    -> Mouse Wheel Up
spell_1           -> 1
spell_2           -> 2
spell_3           -> 3
spell_4           -> 4
spell_5           -> 5
```

## 5. Create UI Elements

### Mana Bar (mana_bar.gd)

```gdscript
extends ProgressBar

var player: CharacterBody3D

func _ready():
    player = get_tree().get_first_node_in_group("player")
    if player and player.has_node("ManaManager"):
        var mana_manager = player.get_node("ManaManager")
        mana_manager.mana_changed.connect(_update_bar)
        _update_bar(mana_manager.current_mana, mana_manager.max_mana)

func _update_bar(current: int, maximum: int):
    max_value = maximum
    value = current
```

### Spell Hotbar (spell_hotbar.gd)

```gdscript
extends HBoxContainer

var player: CharacterBody3D
var spell_slots: Array[TextureRect] = []

func _ready():
    player = get_tree().get_first_node_in_group("player")
    if player and player.has_node("SpellManager"):
        var spell_manager = player.get_node("SpellManager")
        spell_manager.spell_equipped.connect(_update_slot)
        spell_manager.active_slot_changed.connect(_update_active_slot)

    # Create 5 spell slots
    for i in range(5):
        var slot = TextureRect.new()
        slot.custom_minimum_size = Vector2(64, 64)
        slot.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
        add_child(slot)
        spell_slots.append(slot)

func _update_slot(slot: int, spell_id: String):
    # Update slot with spell icon
    var icon_path = "res://assets/icons/spell_%s.png" % spell_id
    if ResourceLoader.exists(icon_path):
        spell_slots[slot].texture = load(icon_path)

func _update_active_slot(slot: int):
    # Highlight active slot
    for i in range(spell_slots.size()):
        if i == slot:
            spell_slots[i].modulate = Color.WHITE
        else:
            spell_slots[i].modulate = Color(0.5, 0.5, 0.5)
```

## 6. Test Basic Spell

```gdscript
# In player _ready() or console
spell_manager.equip_spell(0, "fireball")
spell_manager.equip_spell(1, "ice_shard")
spell_manager.equip_spell(2, "magic_missile")
```

## 7. Enemy Integration

Add these methods to enemy script:

```gdscript
# enemy.gd
extends CharacterBody3D

var health: int = 100
var is_burning: bool = false
var burn_timer: float = 0.0
var burn_dps: int = 0

func _process(delta):
    if is_burning and burn_timer > 0:
        burn_timer -= delta
        if burn_timer <= 0:
            is_burning = false
        else:
            take_damage(burn_dps * delta, null, false, global_position)

func take_damage(amount: int, attacker: Node, is_critical: bool, hit_position: Vector3):
    health -= amount
    print("Enemy took %d damage! HP: %d" % [amount, health])

    if health <= 0:
        die()

func apply_burn(damage_per_sec: int, duration: float):
    is_burning = true
    burn_dps = damage_per_sec
    burn_timer = duration
    print("Enemy is burning! %d DPS for %ds" % [damage_per_sec, duration])

func apply_slow(percent: float, duration: float):
    # Reduce movement speed
    var speed_mult = 1.0 - percent
    # Apply to movement
    print("Enemy slowed by %.0f%% for %.1fs" % [percent * 100, duration])

func apply_freeze(duration: float):
    # Immobilize enemy
    print("Enemy frozen for %.1fs" % duration)

func apply_stun(duration: float):
    # Interrupt and prevent actions
    print("Enemy stunned for %.1fs" % duration)

func apply_root(duration: float):
    # Prevent movement but allow actions
    print("Enemy rooted for %.1fs" % duration)

func apply_dot(damage_per_sec: int, duration: float):
    # Generic damage over time
    print("Enemy taking %.0f DPS for %.1fs" % [damage_per_sec, duration])

func apply_knockback(force: Vector3):
    # Apply force
    velocity += force
    print("Enemy knocked back!")

func is_undead() -> bool:
    return true  # For testing Holy spells

func die():
    print("Enemy died!")
    queue_free()
```

## 8. Common Issues

### "Spell data not found"
- Make sure `SpellRegistry` is registered as autoload
- Check spell_id spelling in `SpellRegistry.SPELLS`

### "Weapon has no owner_player set"
- Ensure `spell_manager.player = self` in player's `_ready()`

### Spells don't cast
- Check mana is available: `mana_manager.current_mana`
- Check cooldown: `spell.is_on_cooldown`
- Verify input actions are set up correctly

### No visual effects
- Projectiles need collision shapes
- Check AudioManager is set up for sounds
- Verify particle scenes exist or are being created

### Beam/AOE spells don't show
- Check that spell has required nodes (`CastPoint`, etc.)
- Verify spell type matches implementation (BEAM uses BeamSpell class)

## 9. Debugging

```gdscript
# Check equipped spells
print(spell_manager.get_all_equipped_spell_ids())

# Check mana
print("Mana: %d/%d" % [mana_manager.current_mana, mana_manager.max_mana])

# Check active spell
var spell = spell_manager.get_active_spell()
if spell:
    print("Active: %s" % spell.display_name)
    print("Cooldown: %.1fs" % spell.get_cooldown_remaining())

# List all spells
for spell_id in SpellRegistry.get_all_spell_ids():
    var data = SpellRegistry.get_spell_data(spell_id)
    print("%s - %s" % [data.display_name, data.description])
```

## 10. Next Steps

Once basic casting works:

1. **Create spell scenes**: Make custom visuals in `res://scenes/spells/`
2. **Add spell icons**: Create icons in `res://assets/icons/`
3. **Implement status effects**: Add full status effect system to enemies
4. **Create spell VFX**: Add particles, trails, and impact effects
5. **Balance spells**: Adjust damage, costs, and cooldowns
6. **Add spell progression**: Implement spell unlocking and upgrades
7. **Create spell combos**: Add synergies between elements
8. **Add sound effects**: Create audio for all spell types
9. **Optimize performance**: Pool objects, limit particles
10. **Network sync**: If multiplayer, sync spell casts

## Example: Complete Player Setup

```gdscript
# player.gd - Complete example
extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@onready var camera_mount = $CameraMount
@onready var camera_3d = $CameraMount/Camera3D
@onready var mana_manager = $ManaManager
@onready var spell_manager = $SpellManager

var mouse_sensitivity = 0.002
var gravity = 9.8

func _ready():
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    spell_manager.player = self

    # Setup starting spells
    spell_manager.equip_spell(0, "fireball")
    spell_manager.equip_spell(1, "ice_shard")
    spell_manager.equip_spell(2, "magic_missile")

    # Connect signals
    spell_manager.spell_cast.connect(_on_spell_cast)
    mana_manager.mana_changed.connect(_on_mana_changed)

func _input(event):
    # Mouse look
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        camera_mount.rotate_x(-event.relative.y * mouse_sensitivity)
        camera_mount.rotation.x = clamp(camera_mount.rotation.x, -PI/2, PI/2)

    # Spell casting
    if event.is_action_pressed("cast_spell"):
        spell_manager.try_cast_active_spell()

    if event.is_action_pressed("next_spell"):
        spell_manager.next_spell()

    if event.is_action_pressed("previous_spell"):
        spell_manager.previous_spell()

func _physics_process(delta):
    # Gravity
    if not is_on_floor():
        velocity.y -= gravity * delta

    # Jump
    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = JUMP_VELOCITY

    # Movement
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

    if direction:
        velocity.x = direction.x * SPEED
        velocity.z = direction.z * SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)
        velocity.z = move_toward(velocity.z, 0, SPEED)

    move_and_slide()

func _on_spell_cast(spell_id: String):
    print("Cast: %s" % spell_id)

func _on_mana_changed(current: int, maximum: int):
    # Update UI here
    pass
```

That's it! You now have a fully functional spell system.
