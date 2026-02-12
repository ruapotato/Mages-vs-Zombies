# Player System - 2D Billboard Character

This is the Paper Mario-style player system for Mages vs Zombies, featuring a 2D sprite character in a 3D world.

## Files

### `player_controller.gd`
Main player controller script that handles:
- **Movement**: WASD movement with sprint (Shift), acceleration, and friction
- **Jumping**: Space to jump, with optional double jump support
- **Camera**: Mouse look first-person camera that follows the player
- **Health System**: 100 HP with regeneration (2 HP/sec after 5 seconds)
- **Mana System**: 100 mana, regenerates 5/sec
- **Spell Casting**: 5 spell slots bound to number keys 1-5
- **Build Mode**: Toggle with B key

### `player_animation.gd`
Procedural 2D animation controller that provides:
- **Idle Animation**: Breathing effect with subtle sway
- **Walk Animation**: Bob up/down, squash/stretch, tilt, and arm swing simulation
- **Jump Animation**: Squash on takeoff, stretch in air, tuck at apex
- **Cast Animation**: Windup, raise, and stretch with rotation

### `player.tscn`
Player scene structure:
- **CharacterBody3D** (root)
  - **CollisionShape3D**: Capsule collision (0.4 radius, 1.8 height)
  - **Sprite3D**: Billboard sprite (always faces camera)
  - **CameraPivot**: Parent node for camera rotation
    - **Camera3D**: Player's viewpoint camera
  - **AnimationController**: Procedural animation node
  - **SpellSpawnPoint**: Marker for spell casting origin

## Controls

| Action | Key | Description |
|--------|-----|-------------|
| Move | W/A/S/D | Movement in 4 directions |
| Sprint | Left Shift | Increases movement speed |
| Jump | Space | Jump (can double jump if enabled) |
| Look | Mouse | Camera rotation |
| Spell 1-5 | 1-5 | Cast spell in slot 1-5 |
| Build Mode | B | Toggle building mode |
| Menu | Escape | Toggle mouse capture |

## Properties

### Movement
- `walk_speed`: 5.0 m/s
- `sprint_speed`: 8.0 m/s
- `jump_velocity`: 7.0 m/s
- `double_jump_enabled`: true

### Combat
- `max_health`: 100
- `health_regen_rate`: 2 HP/sec
- `health_regen_delay`: 5 seconds after damage
- `max_mana`: 100
- `mana_regen_rate`: 5 mana/sec

### Spells (Default)
1. **Fireball** - 15 mana, 1.0s cooldown
2. **Ice Spike** - 20 mana, 1.5s cooldown
3. **Lightning** - 25 mana, 2.0s cooldown
4. **Heal** - 30 mana, 10.0s cooldown
5. **Shield** - 20 mana, 8.0s cooldown

## Usage

### Adding to Scene
```gdscript
var player_scene = preload("res://scenes/player/player.tscn")
var player = player_scene.instantiate()
add_child(player)
player.global_position = Vector3(0, 1, 0)
```

### Taking Damage
```gdscript
player.take_damage(25.0)  # Deal 25 damage
```

### Healing
```gdscript
player.heal(50.0)  # Heal 50 HP
```

### Getting Player Stats
```gdscript
var health_percent = player.get_health_percent()  # 0.0 to 1.0
var mana_percent = player.get_mana_percent()  # 0.0 to 1.0
```

### Getting Spell Info
```gdscript
var spell_info = player.get_spell_info(0)  # Get info for spell slot 1
print(spell_info.name)  # "fireball"
print(spell_info.cooldown)  # Remaining cooldown
print(spell_info.available)  # Can cast now?
```

## Customization

### Adding Player Sprite
Replace the empty Sprite3D with your character sprite:
1. Create or import a 2D character sprite (PNG with transparency)
2. In the editor, select the Sprite3D node
3. Drag your texture to the "Texture" property
4. Adjust `base_scale` in AnimationController if needed

### Animation Tuning
Edit `player_animation.gd` constants:
```gdscript
# Make walk animation faster/slower
const WALK_BOB_SPEED := 10.0  # Increase for faster bob

# More dramatic squash/stretch
const WALK_SQUASH_AMOUNT := 0.1  # Increase for more squash

# Adjust idle breathing
const IDLE_BREATH_SPEED := 1.5
const IDLE_BREATH_AMOUNT := 0.03
```

### Spell Integration
To connect actual spell effects:
1. Create spell scenes in `res://scenes/spells/`
2. Modify `_spawn_spell_effect()` in `player_controller.gd`:
```gdscript
func _spawn_spell_effect(spell_name: String) -> void:
    var camera_forward := -camera.global_transform.basis.z
    var spawn_position := global_position + Vector3(0, 1.5, 0) + camera_forward * 1.5

    var spell_scene = load("res://scenes/spells/" + spell_name + ".tscn")
    if spell_scene:
        var spell = spell_scene.instantiate()
        get_tree().current_scene.add_child(spell)
        spell.global_position = spawn_position
        spell.setup(camera_forward, self)
```

## Animation Details

The procedural animation system creates smooth transitions without sprite sheets:

- **Billboard**: Sprite always faces camera (Paper Mario style)
- **Direction Indication**: Animation shows movement direction through bob and tilt
- **Squash/Stretch**: Gives weight and personality to movement
- **Smooth Transitions**: All animations blend naturally

## Physics Layers

- **Collision Layer**: 2 (Player)
- **Collision Mask**: 1 (World)

Make sure your level geometry is on layer 1 for proper collision detection.

## TODO

- [ ] Integrate actual spell projectile scenes
- [ ] Add death/respawn system
- [ ] Add footstep sounds synced to walk animation
- [ ] Add particle effects for spell casting
- [ ] Add UI for health/mana bars
- [ ] Add spell slot UI with cooldown indicators
- [ ] Add character sprite art
- [ ] Add hit flash/damage feedback animation
- [ ] Add shadow blob under character
