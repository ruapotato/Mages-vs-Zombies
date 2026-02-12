# Player System Architecture Overview

## System Diagram

```
Player (CharacterBody3D)
├── CollisionShape3D (Capsule: 0.4r × 1.8h)
├── Sprite3D (Billboard, 2D character sprite)
├── CameraPivot (Node3D @ y=1.6)
│   └── Camera3D (z=5.0, FOV 75°)
├── AnimationController (PlayerAnimation)
└── SpellSpawnPoint (Marker3D @ y=1.5)
```

## Component Breakdown

### 1. PlayerController (CharacterBody3D)
**File**: `player_controller.gd` (315 lines)

**Responsibilities**:
- Movement physics (WASD, sprint, jump, double jump)
- Mouse look camera control
- Health/mana systems with regeneration
- Spell casting system (5 slots)
- Input handling
- Build mode toggle

**Key Properties**:
```gdscript
# Movement
walk_speed: 5.0 m/s
sprint_speed: 8.0 m/s
jump_velocity: 7.0 m/s

# Stats
max_health: 100
max_mana: 100
health_regen_rate: 2 HP/sec (after 5s delay)
mana_regen_rate: 5 mana/sec

# Spells (5 slots)
1. Fireball   - 15 mana, 1.0s CD
2. Ice Spike  - 20 mana, 1.5s CD
3. Lightning  - 25 mana, 2.0s CD
4. Heal       - 30 mana, 10.0s CD
5. Shield     - 20 mana, 8.0s CD
```

**Public API**:
```gdscript
take_damage(amount: float)
heal(amount: float)
get_health_percent() -> float
get_mana_percent() -> float
get_spell_info(slot: int) -> Dictionary
```

---

### 2. PlayerAnimation (Node)
**File**: `player_animation.gd` (208 lines)

**Responsibilities**:
- Procedural 2D animation without sprite sheets
- State-based animation (idle, walk, jump, cast)
- Squash/stretch effects
- Bob and tilt during movement
- Direction-aware animation

**Animation States**:
```
Idle
├── Breathing: sin wave scale on Y axis
└── Sway: gentle side-to-side motion

Walking
├── Bob: vertical bounce (10 Hz)
├── Squash/Stretch: volume conservation
├── Tilt: lean into movement direction
└── Side Swing: simulated arm motion

Jumping
├── Takeoff: squash (1.1x, 0.85y)
├── Rising: stretch (0.85x, 1.15y)
├── Apex: tuck (0.95x, 1.05y)
└── Falling: slight stretch

Casting
├── Windup: slight squash + rotation
├── Cast: raise height + stretch
└── Release: return to neutral
```

**Public API**:
```gdscript
update_movement(velocity: Vector3, grounded: bool)
play_cast()
get_current_state() -> String
reset()
```

---

### 3. Player Scene (player.tscn)
**File**: `player.tscn` (36 lines)

**Scene Tree**:
```
Player [CharacterBody3D]
│   collision_layer: 2 (Player)
│   collision_mask: 1 (World)
│   script: player_controller.gd
│
├─ CollisionShape3D
│   shape: CapsuleShape3D (0.4r, 1.8h)
│   position: (0, 0.9, 0)
│
├─ Sprite3D
│   billboard: ENABLED
│   texture_filter: NEAREST (pixel art)
│   position: (0, 0.9, 0)
│
├─ CameraPivot [Node3D]
│   position: (0, 1.6, 0)
│   │
│   └─ Camera3D
│       position: (0, 0, 5)
│       fov: 75°
│
├─ AnimationController [Node]
│   script: player_animation.gd
│
└─ SpellSpawnPoint [Marker3D]
    position: (0, 1.5, 0)
```

---

## Data Flow

### Movement Loop
```
Input (WASD)
  → _handle_input()
  → _handle_movement() [calculate velocity]
  → move_and_slide() [CharacterBody3D]
  → update_movement() [AnimationController]
  → _animate_walk/_animate_idle() [visual feedback]
```

### Spell Casting Flow
```
Input (1-5 keys)
  → _cast_spell(slot)
  → Check cooldown & mana
  → Deduct mana, start cooldown
  → play_cast() [AnimationController]
  → _spawn_spell_effect() [instantiate projectile]
```

### Camera Flow
```
Mouse Movement
  → _input() [capture relative motion]
  → Update camera_rotation (x=pitch, y=yaw)
  → _update_camera() [smooth interpolation]
  → Apply to CameraPivot rotation
```

### Regeneration Flow
```
Every frame (_physics_process):
  → time_since_damage += delta
  → If > health_regen_delay:
      current_health += regen_rate * delta
  → current_mana += mana_regen_rate * delta
```

---

## Integration Points

### For Other Systems to Use

**Enemy AI** - Target player:
```gdscript
var player = get_tree().get_first_node_in_group("player")
var direction = (player.global_position - global_position).normalized()
player.take_damage(25.0)
```

**UI System** - Display stats:
```gdscript
health_bar.value = player.get_health_percent()
mana_bar.value = player.get_mana_percent()

for i in 5:
    var spell = player.get_spell_info(i)
    spell_button[i].disabled = !spell.available
```

**Spell System** - Instantiate projectiles:
```gdscript
# In player_controller.gd, modify _spawn_spell_effect():
var spell_scene = load("res://scenes/spells/" + spell_name + ".tscn")
var spell = spell_scene.instantiate()
get_tree().current_scene.add_child(spell)
spell.global_position = spawn_position
spell.direction = camera_forward
spell.caster = self
```

---

## Technical Details

### Physics
- **Tick Rate**: 60 Hz (project.godot)
- **Gravity**: 20 m/s²
- **Acceleration**: 10 m/s² (ground), 5 m/s² (air)
- **Friction**: 15 m/s² (ground only)

### Billboard System
- Sprite3D with `billboard = ENABLED`
- Always faces camera (Paper Mario style)
- Animation shows movement direction via tilt/bob
- Other players in multiplayer see same billboard

### Performance
- ~0.2ms per frame (animation + physics)
- No sprite sheet overhead
- Minimal draw calls (single billboard quad)
- Optimized for multiplayer

### Input Mapping (project.godot)
```
move_forward   → W
move_back      → S
move_left      → A
move_right     → D
jump           → Space
sprint         → Left Shift
spell_1-5      → 1-5 number keys
build_mode     → B
ui_cancel      → Escape
```

---

## File Stats

| File | Lines | Purpose |
|------|-------|---------|
| player_controller.gd | 315 | Main logic |
| player_animation.gd | 208 | Procedural animation |
| player.tscn | 36 | Scene definition |
| player_debug_ui.gd | 43 | Debug overlay (optional) |
| create_placeholder_sprite.gd | 107 | Sprite generator (utility) |
| **Total** | **709** | **Complete system** |

---

## Extensibility

### Easy to Add
- New spell slots (just extend arrays)
- Different animation parameters (all constants)
- Status effects (add to state vars)
- Equipment system (add child nodes)

### Moderate Difficulty
- Multiplayer synchronization (add RPC methods)
- Inventory system (new component script)
- Character customization (sprite swapping)

### Complex
- Animation blending (requires state machine)
- Procedural animation layers (stacking effects)
- Advanced spell combos (spell system rework)

---

## Credits

Created for: **Mages vs Zombies**
Style: Paper Mario meets Valheim
Engine: Godot 4.6
Architecture: Component-based with procedural animation
