# Zombie System Quick Reference

## Files Created

### Scripts (in `/scripts/enemies/`)
- `zombie_base.gd` - Base zombie class with all core functionality
- `zombie_horde.gd` - Centralized manager for performance and waves
- `zombie_types.gd` - 5 zombie variant classes
- `zombie_test_example.gd` - Example implementation
- `ZOMBIE_SYSTEM_README.md` - Full documentation

### Scenes (in `/scenes/enemies/`)
- `zombie.tscn` - Base zombie scene
- `zombie_walker.tscn` - Walker variant
- `zombie_runner.tscn` - Runner variant
- `zombie_brute.tscn` - Brute variant
- `zombie_mage.tscn` - Mage variant
- `zombie_exploder.tscn` - Exploder variant

## Night Multipliers (CRITICAL!)

```gdscript
# In zombie_base.gd
night_damage_multiplier = 2.0   # Double damage!
night_speed_multiplier = 1.5    # 50% faster
night_health_multiplier = 1.5   # 50% more HP

# In zombie_horde.gd
night_spawn_multiplier = 2.0          # 2x zombies per wave
night_spawn_rate_multiplier = 1.5     # Spawn 50% faster
```

## Zombie Stats Reference

| Type | HP | Speed | Damage | Special | Spawn % |
|------|-------|--------|--------|---------|---------|
| Walker | 50 | 3.0 | 10 | Basic | 50% |
| Runner | 30 | 6.0 | 8 | Fast | 25% |
| Brute | 150 | 1.5 | 25 | Tank | 15% |
| Mage | 40 | 2.5 | 15 | Ranged | 7% |
| Exploder | 35 | 4.0 | 30 | AOE death | 3% |

## Code Snippets

### Spawn Zombies
```gdscript
# Random types
zombie_horde.spawn_zombies(10)

# Specific type
zombie_horde.spawn_zombies(5, "brute")
```

### Enable Waves
```gdscript
zombie_horde.enable_waves = true
zombie_horde.wave_interval = 120.0
zombie_horde.base_zombies_per_wave = 5
```

### Connect Signals
```gdscript
zombie_horde.wave_started.connect(_on_wave_started)
zombie_horde.wave_completed.connect(_on_wave_completed)
zombie_horde.zombie_died.connect(_on_zombie_died)
```

### Test Night Mode
```gdscript
DayNightCycle.set_time(0.0)  # Midnight - SCARY!
DayNightCycle.set_time(12.0) # Noon - Safe
```

### Get Stats
```gdscript
var stats = zombie_horde.get_stats()
print("Active: %d" % stats.active_zombies)
print("Is Night: %s" % stats.is_night)
```

## Performance Settings

```gdscript
# LOD distances (in zombie_horde.gd)
lod_distance_medium = 30.0  # Simplified AI
lod_distance_far = 60.0     # Minimal AI

# Batch limits (constants)
MAX_PHYSICS_ZOMBIES = 100   # Full physics
MAX_ANIMATED_ZOMBIES = 400  # Animations
PATH_UPDATE_BATCH = 20      # Path updates/frame
```

## State Machine

```gdscript
enum State {
    SPAWNING,  # Fade in
    IDLE,      # Looking for player
    CHASING,   # Moving toward player
    ATTACKING, # Dealing damage
    DYING,     # Death animation
    DEAD       # Removed
}
```

## Key Functions

### ZombieBase
- `take_damage(amount, attacker)` - Deal damage to zombie
- `die()` - Trigger death
- `set_lod_level(level, distance)` - Set performance level
- `get_stats()` - Get zombie info

### ZombieHorde
- `spawn_zombies(count, type)` - Spawn zombies
- `clear_all_zombies()` - Remove all zombies
- `get_stats()` - Get horde statistics
- `get_zombie_count()` - Active zombie count

## Common Issues

### Zombies not moving
- Check NavigationRegion3D exists in scene
- Verify navigation mesh is baked
- Ensure player is in "player" or "local_player" group

### Night scaling not working
- Verify DayNightCycle autoload exists
- Check `is_night()` function
- Ensure zombie_horde connected to `period_changed` signal

### Performance issues
- Reduce `max_active_zombies`
- Decrease `lod_distance_medium` and `lod_distance_far`
- Lower `MAX_PHYSICS_ZOMBIES` and `MAX_ANIMATED_ZOMBIES`

## Testing Commands

Add to your test script:
```gdscript
# In _input():
if Input.is_action_just_pressed("ui_accept"):
    zombie_horde.spawn_zombies(10)

if Input.is_key_pressed(KEY_T):
    DayNightCycle.set_time(0.0)  # Night test
```

## Night Survival Loop

The system creates this natural gameplay cycle:

**DAY (6:00 - 19:00)**
- Normal zombie stats
- Safe to explore
- Gather resources
- Build defenses
- Normal wave difficulty

**NIGHT (22:00 - 5:00)**
- 2x damage from zombies
- 1.5x zombie speed
- 1.5x zombie health
- 2x more zombies per wave
- 1.5x faster spawning
- SEEK SHELTER!

## Integration Steps

1. Add `ZombieHorde` node to main scene
2. Ensure `NavigationRegion3D` exists with baked mesh
3. Add player to "player" group
4. Connect to signals for UI updates
5. Test with `zombie_test_example.gd`
6. Add textures to `Sprite3D` nodes
7. Balance difficulty for your game

## Customization Tips

### Make night TERRIFYING
```gdscript
night_damage_multiplier = 3.0
night_speed_multiplier = 2.0
night_health_multiplier = 2.0
night_spawn_multiplier = 3.0
```

### Easier early game
```gdscript
base_zombies_per_wave = 3
zombies_per_wave_increase = 1
difficulty_scale_per_day = 0.05
```

### More variety
```gdscript
walker_probability = 0.3
runner_probability = 0.3
brute_probability = 0.2
mage_probability = 0.15
exploder_probability = 0.05
```

## Next Steps

- [ ] Add zombie sprites/textures
- [ ] Create shelter mechanics
- [ ] Add loot drops
- [ ] Implement XP/leveling
- [ ] Add particle effects
- [ ] Create boss zombies
- [ ] Add blood moon events
- [ ] Implement zombie door-breaking
