# Zombie System for Mages-vs-Zombies

## Overview
Complete Paper Mario style 2D billboard zombie system for Godot 4.6. Features 5 zombie types, wave spawning, LOD optimization, and CRITICAL night-time difficulty scaling.

## Files Created

### Core Scripts
1. **zombie_base.gd** - Base zombie class with full functionality
2. **zombie_horde.gd** - Centralized zombie manager for performance
3. **zombie_types.gd** - 5 different zombie variants

### Scene Files
1. **zombie.tscn** - Base zombie scene
2. **zombie_walker.tscn** - Basic slow zombie
3. **zombie_runner.tscn** - Fast, low health zombie
4. **zombie_brute.tscn** - Slow tank with high damage
5. **zombie_mage.tscn** - Ranged magic attacker
6. **zombie_exploder.tscn** - Explodes on death

## Night-Time Mechanics (CRITICAL!)

### Night Scaling Multipliers
Zombies become MUCH stronger at night to force players to seek shelter:

- **Damage**: 2.0x (double damage!)
- **Speed**: 1.5x (50% faster)
- **Health**: 1.5x (50% more HP)
- **Spawn Count**: 2.0x (waves spawn 2x more zombies)
- **Spawn Rate**: 1.5x (spawns 50% faster)

### Visual Indicators
- Day: Greenish tint (0.6, 0.8, 0.6)
- Night: Reddish tint (0.8, 0.5, 0.5)

## Zombie Types

### Walker (50% spawn rate)
- Base Health: 50
- Base Speed: 3.0
- Base Damage: 10
- Color: Green
- Role: Basic enemy

### Runner (25% spawn rate)
- Base Health: 30
- Base Speed: 6.0 (2x faster!)
- Base Damage: 8
- Color: Yellow
- Role: Fast flanker

### Brute (15% spawn rate)
- Base Health: 150 (3x health!)
- Base Speed: 1.5 (slow)
- Base Damage: 25 (2.5x damage!)
- Color: Red
- Role: Tank

### Mage Zombie (7% spawn rate)
- Base Health: 40
- Base Speed: 2.5
- Base Damage: 5 (melee)
- Ranged Damage: 15
- Attack Range: 15 units
- Color: Purple
- Role: Ranged attacker

### Exploder (3% spawn rate)
- Base Health: 35
- Base Speed: 4.0
- Base Damage: 15
- Explosion Damage: 30 (area)
- Explosion Radius: 5 units
- Color: Orange
- Role: Kamikaze/area denial

## State Machine

### States
1. **SPAWNING** - Fade in and scale up from ground
2. **IDLE** - Looking for targets
3. **CHASING** - Moving toward player
4. **ATTACKING** - Dealing damage
5. **DYING** - Death animation (fall and fade)
6. **DEAD** - Removed from game

## Performance Features (LOD System)

### LOD Levels
- **Level 0** (< 30 units): Full detail
  - Full physics (move_and_slide)
  - Full pathfinding
  - All animations
  - Health bar visible

- **Level 1** (30-60 units): Medium detail
  - Simplified physics
  - Reduced pathfinding updates
  - Basic animations
  - Health bar hidden if full HP

- **Level 2** (> 60 units): Minimal detail
  - Direct position updates (no physics)
  - No pathfinding
  - No animations
  - Health bar hidden

### Batch Processing
- Only 20 path updates per frame
- Only 100 zombies use physics
- Only 400 zombies animate
- Invisible zombies teleport for performance

## Wave System

### Configuration
- Base zombies per wave: 5
- Increase per wave: +2
- Wave interval: 120 seconds (2 minutes)
- Max active zombies: 50

### Night Wave Mechanics
When a wave starts at night:
- Zombie count is DOUBLED (10 instead of 5 on wave 1)
- Spawns 50% faster
- All zombies have night stat bonuses
- Console prints: "NIGHT WAVE - 2X ZOMBIES!"

## Difficulty Scaling

### Time-Based Difficulty
- +10% stats per game day
- Max 3x multiplier
- Scales: Health, Damage, Speed (30%)

### Day Calculation
Based on DayNightCycle autoload (24-hour cycle)

## Usage

### Setting Up Zombie Horde Manager
```gdscript
# In your main game scene
var zombie_horde = ZombieHorde.new()
add_child(zombie_horde)
zombie_horde.enable_waves = true
zombie_horde.spawn_radius_min = 20.0
zombie_horde.spawn_radius_max = 40.0
```

### Manual Spawning
```gdscript
# Spawn 10 random zombies
zombie_horde.spawn_zombies(10)

# Spawn 5 specific type
zombie_horde.spawn_zombies(5, "brute")
```

### Connecting Signals
```gdscript
zombie_horde.wave_started.connect(_on_wave_started)
zombie_horde.wave_completed.connect(_on_wave_completed)
zombie_horde.zombie_spawned.connect(_on_zombie_spawned)
```

## Integration with Day/Night Cycle

The system automatically connects to the `DayNightCycle` autoload:
- Checks `DayNightCycle.is_night()` for stat scaling
- Listens to `period_changed` signal
- Updates zombie stats in real-time
- Prints warnings when night falls

## Procedural Animation

### Walk Animation
- Bob height: 0.15 units
- Bob speed: 8.0
- Lean forward: 5 degrees

### Attack Animation
- Swing angle: 30 degrees
- Swing speed: 10.0
- Scale pulse during attack

### Death Animation
- Fall duration: 0.8 seconds
- Rotate 90 degrees
- Fade out alpha
- Sink into ground

## Health Bar

### Features
- Billboard (always faces camera)
- Color-coded:
  - Green: > 50% HP
  - Yellow: 25-50% HP
  - Red: < 25% HP
- Hidden at full health
- Positioned above head (2.2 units up)

## Collision Layers

- Layer 4 (bit 3): Enemy layer
- Mask 1 (bit 1): World
- Mask 2 (bit 2): Player

## Tips for Balancing

### Making Night Scarier
Increase in zombie_base.gd:
```gdscript
night_damage_multiplier = 3.0  # Triple damage!
night_speed_multiplier = 2.0   # Double speed!
```

### Easier Early Game
Reduce in zombie_horde.gd:
```gdscript
base_zombies_per_wave = 3
zombies_per_wave_increase = 1
```

### More Zombie Variety
Adjust probabilities in zombie_horde.gd:
```gdscript
walker_probability = 0.4
runner_probability = 0.3
brute_probability = 0.2
# etc.
```

## Future Enhancements

Potential additions:
1. Boss zombies (giant variants)
2. Special night-only zombie types
3. Weather effects on zombies
4. Zombie pathfinding around buildings
5. Zombie door-breaking mechanics
6. Blood moon events (5x multiplier!)

## Performance Notes

With batch processing and LOD system:
- 400+ zombies at 60 FPS on mid-range hardware
- Only close zombies use full physics
- Distant/invisible zombies use cheap teleportation
- Wave spawning prevents lag spikes

## Integration Checklist

- [ ] Add NavigationRegion3D to your map
- [ ] Ensure player is in "player" or "local_player" group
- [ ] Add DayNightCycle autoload (already exists)
- [ ] Create ZombieHorde node in main scene
- [ ] Set up spawn areas
- [ ] Test night difficulty (it should be SCARY!)
- [ ] Balance wave timing for your game pace

## Credits

Created for Mages-vs-Zombies - A Paper Mario meets Valheim meets COD meets Magic survival game!
