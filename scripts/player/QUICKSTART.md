# Quick Start Guide - Player System

## Getting Started

### 1. Open the Project in Godot 4.6
```bash
cd /matrix/david/main_home_folder/myProjects/ACTIVE/Mages-vs-Zombies
./Godot_v4.6-stable_linux.x86_64 --editor
```

### 2. Create a Placeholder Sprite (Optional)
To see the player visually:

1. Open the script: `scripts/player/create_placeholder_sprite.gd`
2. In Godot: **File** -> **Run Script**
3. This creates `res://assets/player/mage_placeholder.png`
4. Open `scenes/player/player.tscn`
5. Select the **Sprite3D** node
6. Drag the placeholder texture to the **Texture** property

### 3. Test the Player
The main game scene is already set up at `scenes/main/game.tscn`:

1. Press **F5** (or click Play) to run the project
2. You should spawn on a green platform
3. Use the controls below to test movement

## Controls

```
W/A/S/D     - Move
Space       - Jump (press again in air for double jump)
Left Shift  - Sprint
Mouse       - Look around
1-5         - Cast spells (check console for output)
B           - Toggle build mode
ESC         - Show/hide mouse cursor
```

## What You Get

### Core Features Working Out of the Box
- Character movement with acceleration/friction
- Sprint system
- Jump and double jump
- Mouse look camera
- Health system (100 HP, regenerates 2/sec after 5s)
- Mana system (100 mana, regenerates 5/sec)
- 5 spell slots with cooldowns
- Procedural walk/idle/jump animations
- Billboard sprite (always faces camera)

### Animation System
The character automatically animates based on state:
- **Idle**: Gentle breathing and swaying
- **Walking**: Bob, squash/stretch, tilt
- **Jumping**: Squash/stretch based on velocity
- **Casting**: Wind-up and release animation

## Next Steps

### Adding Spell Effects
Currently spells just print to console. To add real effects:

1. Create spell scenes in `scenes/spells/`
2. Edit `player_controller.gd` line ~220 in `_spawn_spell_effect()`
3. Uncomment and modify the spell instantiation code

### Adding Player Art
Replace the placeholder sprite:

1. Create or find a 64x64 pixel sprite of your mage character
2. Export as PNG with transparency
3. Import to `assets/player/`
4. Assign to Sprite3D texture in player scene
5. Adjust scale if needed (edit `base_scale` in AnimationController)

### Connecting UI
The player has methods for UI integration:

```gdscript
# Health bar
var health_percent = player.get_health_percent()  # Returns 0.0 to 1.0

# Mana bar
var mana_percent = player.get_mana_percent()

# Spell slot UI
for i in range(5):
    var spell = player.get_spell_info(i)
    update_spell_ui(i, spell.name, spell.cooldown, spell.available)
```

### Customization
All parameters are exposed in the Inspector:

1. Open `scenes/player/player.tscn`
2. Select the root **Player** node
3. Adjust values in the Inspector:
   - **Movement**: Walk speed, sprint speed, jump height
   - **Camera**: Mouse sensitivity, distance, FOV
   - **Combat**: Health, mana, regen rates
   - **Spells**: Names, cooldowns, mana costs

## Troubleshooting

### Player falls through floor
- Make sure your floor has a CollisionShape3D
- Floor should be on physics layer 1 (World)
- Player is on layer 2 (Player) and collides with layer 1

### Camera not working
- Check that Input.mouse_mode is captured
- Press ESC twice to recapture mouse
- Verify Camera3D node exists in scene

### Animations not playing
- Check that Sprite3D is assigned in AnimationController
- Verify AnimationController script is attached
- Check console for any script errors

### Spells not casting
- Check console output for error messages
- Verify you have enough mana (shown in console)
- Make sure spell isn't on cooldown

## File Structure

```
Mages-vs-Zombies/
├── scripts/player/
│   ├── player_controller.gd        # Main controller
│   ├── player_animation.gd         # Animation system
│   ├── create_placeholder_sprite.gd # Sprite generator
│   ├── README.md                   # Full documentation
│   └── QUICKSTART.md              # This file
├── scenes/player/
│   └── player.tscn                # Player scene
└── scenes/main/
    └── game.tscn                  # Test scene
```

## Performance Notes

- The billboard system is very efficient
- Procedural animation has minimal overhead
- Character is optimized for multiplayer (other players will see the billboard too)
- Physics runs at 60 ticks/second (configured in project.godot)

## Have Fun!

The player system is fully functional and ready to use. Just add your game content around it:
- Create enemy AI that targets the player
- Add spell projectile scenes
- Build your world geometry
- Add UI for health/mana/spells
- Create interactable objects

Check README.md for detailed API documentation and customization options.
