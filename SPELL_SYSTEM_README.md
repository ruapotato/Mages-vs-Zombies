# Mages-vs-Zombies Spell System

A comprehensive magic spell system for Godot 4.6, converted from the gun system in Zombies-vs-Humans.

## Overview

The spell system includes:
- 20 unique spells across 7 damage types
- 3 spell delivery types (Projectile, Beam, AOE)
- Mana system with regeneration
- Status effects (burn, freeze, slow, stun, root)
- Spell progression with tiers (1-4)

## File Structure

```
scripts/
├── autoload/
│   └── spell_registry.gd          # Registry of all spells
├── player/
│   ├── mana_manager.gd            # Mana pool and regeneration
│   └── spell_manager.gd           # Equipped spells management
└── weapons/
    ├── spell_data.gd              # Spell data resource
    ├── spell_base.gd              # Base spell class
    ├── projectile_spell.gd        # Projectile spell implementation
    ├── beam_spell.gd              # Beam spell implementation
    ├── aoe_spell.gd               # AOE spell implementation
    └── spell_projectile.gd        # Projectile physics/behavior
```

## Damage Types

Each spell belongs to one of seven damage types:

### FIRE
- **Fireball** (Tier 1): Launch flaming projectile, causes burn
- **Flame Wave** (Tier 2): Expanding wave of fire with knockback
- **Inferno** (Tier 3): Persistent burning area
- **Meteor Storm** (Tier 4): Rain meteors from the sky

### ICE
- **Ice Shard** (Tier 1): Piercing ice projectile that slows
- **Frost Nova** (Tier 2): Freeze enemies around you
- **Glacial Spike** (Tier 3): Massive ice spike with high freeze chance
- **Blizzard** (Tier 4): Devastating blizzard over large area

### LIGHTNING
- **Chain Lightning** (Tier 2): Lightning chains between enemies
- **Thunder Strike** (Tier 3): Call down thunder bolt
- **Static Field** (Tier 3): Electrified field with constant damage

### ARCANE
- **Magic Missile** (Tier 1): Homing arcane missiles
- **Arcane Blast** (Tier 3): Powerful explosion with knockback
- **Time Warp** (Tier 4): Slow enemies, speed allies

### NATURE
- **Vine Grasp** (Tier 2): Root enemies in place
- **Healing Rain** (Tier 3): Heal allies and regenerate mana

### DARK
- **Soul Drain** (Tier 2): Drain life and mana from enemies
- **Shadow Bolt** (Tier 2): Shadow damage over time

### HOLY
- **Divine Light** (Tier 2): Damage undead, heal allies
- **Smite** (Tier 3): Devastating holy strike (2.5x vs undead)

## Spell Types

### PROJECTILE
Fires projectiles that travel through space:
- Can have homing behavior
- Can pierce multiple enemies
- Can explode on impact

**Examples:** Fireball, Ice Shard, Magic Missile, Shadow Bolt

### BEAM
Continuous beam that locks onto target:
- Damage over time while active
- Can chain to nearby enemies (Chain Lightning)
- Can drain life/mana (Soul Drain)

**Examples:** Chain Lightning, Soul Drain

### AOE (Area of Effect)
Affects area around target point:
- Instant (Frost Nova)
- Persistent (Blizzard, Inferno)
- Expanding (Flame Wave)
- Meteor Rain (Meteor Storm)

**Examples:** Meteor Storm, Blizzard, Frost Nova, Divine Light

## Mana System

### Basic Mechanics
- Default max mana: 100
- Base regeneration: 5 mana/sec
- Regen delay after casting: 1 second
- Mana costs range from 10-60 per spell

### ManaManager Features
```gdscript
# Check mana
mana_manager.has_enough_mana(amount)

# Consume mana
mana_manager.consume_mana(amount)

# Add mana
mana_manager.add_mana(amount)

# Modify regeneration
mana_manager.set_mana_regen(new_regen)
mana_manager.add_mana_regen_bonus(bonus)

# Refill instantly
mana_manager.refill_mana()
```

### Signals
```gdscript
signal mana_changed(current: int, maximum: int)
signal mana_depleted()
signal mana_full()
```

## Spell Manager

Manages equipped spells and spell casting.

### Usage
```gdscript
# Equip spell to slot
spell_manager.equip_spell(slot, "fireball")

# Cast spell
spell_manager.try_cast_active_spell()
spell_manager.try_cast_spell(slot)

# Switch active spell
spell_manager.set_active_slot(slot)
spell_manager.next_spell()
spell_manager.previous_spell()

# Query spells
spell_manager.get_active_spell()
spell_manager.is_spell_on_cooldown(slot)
spell_manager.get_spell_cooldown_remaining(slot)
```

### Signals
```gdscript
signal spell_equipped(slot: int, spell_id: String)
signal spell_cast(spell_id: String)
signal active_slot_changed(slot: int)
```

## Status Effects

Spells can apply various status effects to enemies:

### Burn (Fire)
```gdscript
# Apply burn damage over time
burn_damage_per_sec: int
burn_duration: float
```

### Slow/Freeze (Ice)
```gdscript
# Reduce movement speed
slow_percent: float        # 0.0-1.0 (percentage reduction)
slow_duration: float

# Chance to freeze (immobilize)
freeze_chance: float       # 0.0-1.0
freeze_duration: float
```

### Stun (Lightning)
```gdscript
# Chance to stun enemy
stun_chance: float         # 0.0-1.0
stun_duration: float
```

### Root (Nature)
```gdscript
# Immobilize enemy
root_duration: float
```

### DOT (Dark/Poison)
```gdscript
# Damage over time
dot_damage_per_sec: int
dot_duration: float
```

### Knockback
```gdscript
# Push enemies away
knockback_force: float
```

## Creating New Spells

### 1. Add to SpellRegistry

```gdscript
# In spell_registry.gd SPELLS dictionary
"my_new_spell": {
    "spell_id": "my_new_spell",
    "display_name": "My New Spell",
    "damage_type": DamageType.FIRE,
    "spell_type": SpellType.PROJECTILE,
    "base_damage": 60,
    "mana_cost": 25,
    "cast_time": 0.5,
    "cooldown": 2.0,
    "projectile_speed": 40.0,
    "projectile_lifetime": 5.0,
    "description": "Does something cool",
    "cast_sound": "fire_cast",
    "impact_sound": "fire_impact",
    "particle_effect": "my_spell_particle",
    "trail_color": Color(1.0, 0.5, 0.0),
    "glow_intensity": 2.0
}
```

### 2. Spell Properties Reference

**Core Properties:**
- `spell_id`: Unique identifier
- `display_name`: Display name
- `damage_type`: DamageType enum value
- `spell_type`: SpellType enum value
- `base_damage`: Base damage amount
- `mana_cost`: Mana required to cast
- `cast_time`: Time to cast (seconds)
- `cooldown`: Cooldown after casting (seconds)
- `spell_tier`: Tier 1-4 (difficulty/power)

**Projectile Properties:**
- `projectile_speed`: Speed of projectile
- `projectile_lifetime`: Max lifetime
- `homing_strength`: 0.0-1.0 homing capability
- `pierce_count`: Number of enemies to pierce
- `missile_count`: Number of missiles (Magic Missile)

**Beam Properties:**
- `beam_range`: Max beam distance
- `beam_duration`: How long beam lasts
- `beam_width`: Visual beam width
- `chain_count`: Number of chain targets
- `chain_range`: Distance for chaining
- `chain_damage_falloff`: Damage reduction per chain

**AOE Properties:**
- `aoe_radius`: Radius of effect
- `aoe_duration`: How long AOE lasts
- `explosion_radius`: Explosion size
- `meteor_count`: Number of meteors
- `meteor_interval`: Time between meteors

**DOT Properties:**
- `damage_per_tick`: Damage per tick
- `tick_interval`: Time between ticks
- `burn_damage_per_sec`: Burn DOT
- `burn_duration`: Burn duration
- `dot_damage_per_sec`: Generic DOT
- `dot_duration`: DOT duration

**Status Effect Properties:**
- `slow_percent`: 0.0-1.0 movement reduction
- `slow_duration`: Duration of slow
- `freeze_chance`: 0.0-1.0 chance to freeze
- `freeze_duration`: Duration of freeze
- `stun_chance`: 0.0-1.0 chance to stun
- `stun_duration`: Duration of stun
- `root_duration`: Duration of root

**Special Properties:**
- `bonus_vs_undead`: Damage multiplier vs undead
- `knockback_force`: Knockback strength
- `lifesteal_percent`: 0.0-1.0 life steal
- `mana_steal_percent`: 0.0-1.0 mana steal
- `heal_per_tick`: Healing amount
- `heal_allies`: Instant heal amount
- `mana_regen_bonus`: Bonus mana regen
- `player_speed_bonus`: 0.0-1.0 speed boost

## Integration with Player

### Setup Example

```gdscript
# In player script
extends CharacterBody3D

@onready var mana_manager: ManaManager = $ManaManager
@onready var spell_manager: SpellManager = $SpellManager

func _ready():
    spell_manager.player = self

    # Connect signals
    spell_manager.spell_cast.connect(_on_spell_cast)
    mana_manager.mana_changed.connect(_on_mana_changed)

func _input(event):
    if event.is_action_pressed("cast_spell"):
        spell_manager.try_cast_active_spell()

    if event.is_action_pressed("next_spell"):
        spell_manager.next_spell()

    if event.is_action_pressed("previous_spell"):
        spell_manager.previous_spell()

    # Spell hotkeys
    for i in range(5):
        if event.is_action_pressed("spell_slot_%d" % i):
            spell_manager.set_active_slot(i)

func _on_spell_cast(spell_id: String):
    print("Cast spell: %s" % spell_id)

func _on_mana_changed(current: int, maximum: int):
    # Update UI
    pass
```

## Enemy Integration

Enemies need these methods for full spell support:

```gdscript
# Required
func take_damage(amount: int, attacker: Node, is_critical: bool, hit_position: Vector3):
    pass

# Optional for status effects
func apply_burn(damage_per_sec: int, duration: float):
    pass

func apply_slow(percent: float, duration: float):
    pass

func apply_freeze(duration: float):
    pass

func apply_stun(duration: float):
    pass

func apply_root(duration: float):
    pass

func apply_dot(damage_per_sec: int, duration: float):
    pass

func apply_knockback(force: Vector3):
    pass

# For targeting
func is_undead() -> bool:
    return true
```

## UI Integration

### Mana Bar Example

```gdscript
extends ProgressBar

@onready var mana_manager: ManaManager = get_node("/root/Player/ManaManager")

func _ready():
    mana_manager.mana_changed.connect(_update_mana_bar)
    _update_mana_bar(mana_manager.current_mana, mana_manager.max_mana)

func _update_mana_bar(current: int, maximum: int):
    max_value = maximum
    value = current
```

### Spell Cooldown Indicator

```gdscript
extends TextureProgressBar

@export var spell_slot: int = 0
@onready var spell_manager: SpellManager = get_node("/root/Player/SpellManager")

func _process(_delta):
    var spell = spell_manager.get_spell_in_slot(spell_slot)
    if spell:
        if spell.is_on_cooldown:
            var remaining = spell.get_cooldown_remaining()
            var total = spell.cooldown
            value = (1.0 - remaining / total) * 100.0
        else:
            value = 100.0
```

## AudioManager Sounds

The following sounds are referenced by spells:

### Cast Sounds
- `fire_cast`, `flame_wave_cast`, `meteor_cast`, `inferno_cast`
- `ice_cast`, `frost_nova_cast`, `glacial_spike_cast`, `blizzard_cast`
- `lightning_cast`, `thunder_cast`, `static_cast`
- `arcane_cast`, `arcane_blast_cast`, `time_warp_cast`
- `nature_cast`, `healing_cast`
- `dark_cast`, `shadow_cast`
- `holy_cast`, `smite_cast`

### Impact Sounds
- `fire_impact`, `fire_whoosh`, `meteor_impact`, `inferno_loop`
- `ice_impact`, `ice_shatter`, `ice_shatter_heavy`, `blizzard_loop`
- `lightning_zap`, `lightning_chain`, `thunder_boom`, `static_loop`
- `arcane_impact`, `arcane_explosion`, `time_warp_loop`
- `vines_rustle`, `rain_loop`
- `soul_drain_loop`, `shadow_impact`
- `divine_light_impact`, `smite_impact`

### General Sounds
- `spell_cast` (default)
- `spell_impact` (default)
- `no_mana` (not enough mana)

## Performance Considerations

### Optimization Tips

1. **Spell Pooling**: For frequently cast spells, consider object pooling
2. **Particle Limits**: Limit active particle systems
3. **Collision Queries**: AOE spells use shape queries - don't spam them
4. **Visual LOD**: Reduce spell visuals at distance
5. **Network Sync**: Only sync spell casts, not every projectile update

### Recommended Settings

```gdscript
# ProjectSettings
const MAX_ACTIVE_SPELLS = 50
const MAX_PROJECTILES = 100
const SPELL_UPDATE_RATE = 0.016  # 60 FPS
```

## Testing

### Debug Commands

```gdscript
# Give spell
spell_manager.equip_spell(0, "meteor_storm")

# Infinite mana (for testing)
mana_manager.max_mana = 9999
mana_manager.mana_regen_per_sec = 1000.0

# Reset cooldowns
for slot in range(5):
    var spell = spell_manager.get_spell_in_slot(slot)
    if spell:
        spell.is_on_cooldown = false
```

## Future Enhancements

Potential additions to the spell system:

1. **Spell Upgrades**: Improve spells with power/effects
2. **Combo System**: Chain spells for bonus effects
3. **Spell Crafting**: Create custom spells
4. **Talent Trees**: Modify spell behavior
5. **Elemental Combos**: Combine damage types (fire + ice = steam)
6. **Spell Charging**: Hold to increase power
7. **Ritual Spells**: Multi-player cooperative casting
8. **Spell Books**: Collections that grant bonuses
9. **Metamagic**: Modify spell properties on-the-fly
10. **Environmental Effects**: Spells interact with terrain

## Credits

Converted from the weapon system in Zombies-vs-Humans.
Created for Mages-vs-Zombies, a Godot 4.6 game.
