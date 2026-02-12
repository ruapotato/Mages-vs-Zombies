# Valheim-Style Building System for Mages-vs-Zombies

A complete, working building system inspired by Valheim, designed for shelter construction and zombie defense.

## Overview

This building system provides:
- **Ghost preview** with visual feedback for valid/invalid placement
- **Grid snapping** (2x2 unit grid) for precise building
- **Snap points** for connecting pieces together
- **Health system** - zombies can damage and destroy buildings
- **Workbench requirement** - must be within 20m of a workbench to build
- **Visual damage feedback** - buildings show damage through color changes
- **Interactive doors** - can be opened and closed

## Files

1. **building_pieces_data.gd** - Database of all building pieces
2. **building_piece.gd** - Individual building piece with health, damage, and interaction
3. **build_mode.gd** - Building mode controller (placement, rotation, validation)
4. **crafting_station.gd** - Workbench/crafting station (required for building)

## Building Pieces

### Wooden Pieces
- **Wooden Wall** (100 HP) - Cost: 4 wood, 2 stone
- **Wooden Floor** (80 HP) - Cost: 3 wood
- **Wooden Door** (60 HP) - Cost: 4 wood, 1 iron (interactive)
- **Wooden Roof 26°** (80 HP) - Cost: 3 wood, 1 stone
- **Wooden Roof 45°** (80 HP) - Cost: 3 wood, 1 stone
- **Wooden Stairs** (70 HP) - Cost: 5 wood
- **Wooden Beam** (90 HP) - Cost: 2 wood

### Stone Pieces
- **Stone Wall** (300 HP) - Cost: 6 stone, 1 wood
- **Stone Floor** (250 HP) - Cost: 4 stone
- **Reinforced Door** (200 HP) - Cost: 4 wood, 4 iron, 2 stone (interactive)

## Controls

- **B** - Toggle build mode on/off
- **R** - Rotate current piece (45° increments)
- **Left-click** - Place piece
- **Right-click / ESC** - Cancel placement
- **1-9 keys** - Quick select building pieces

## Usage Example

```gdscript
extends Node3D

@onready var build_mode: BuildMode = BuildMode.new()

func _ready():
    # Initialize building system
    add_child(build_mode)
    build_mode.initialize($Player, $Player/Camera3D, self)

    # Connect signals
    build_mode.build_piece_placed.connect(_on_piece_placed)

func _input(event):
    if event.is_action_pressed("toggle_build"):  # Map to "B" key
        build_mode.toggle()

func _on_piece_placed(piece_id: String, position: Vector3, rotation: float):
    print("Placed: %s at %s" % [piece_id, position])
```

## Key Features

### 1. Ghost Preview
- Semi-transparent preview shows where piece will be placed
- **Green** = valid placement
- **Red** = invalid placement (overlapping, no resources, etc.)

### 2. Grid Snapping
- 2x2 unit grid for precise alignment
- Automatically snaps to nearest grid position
- Helps create clean, aligned structures

### 3. Snap Points
- Pieces automatically connect to adjacent pieces
- Walls snap to floors, walls, and other walls
- Floors snap to create continuous platforms
- Stairs chain together for multi-story buildings

### 4. Health & Damage System
- All building pieces have health points
- Zombies can attack and damage buildings
- Visual feedback shows damage state:
  - **75-100%** - No visible damage
  - **50-75%** - Light damage (slight darkening)
  - **25-50%** - Moderate damage (darker, reddish tint)
  - **0-25%** - Heavy damage (very dark, red)
- Pieces are destroyed at 0 HP

### 5. Workbench Requirement
- Must be within 20m of a workbench to build
- Workbench itself doesn't require another workbench (bootstrap)
- Encourages establishing base camps

### 6. Resource System
- Each piece has a resource cost
- Resources are consumed on placement
- System integrates with player inventory

### 7. Interactive Elements
- **Doors** can be opened/closed by interacting
- Doors rotate 90° when opened
- Collision is disabled when door is open

## Shelter System

Buildings provide **SHELTER** - a critical survival mechanic:

```gdscript
# Check if player is inside shelter
func is_inside_shelter(position: Vector3) -> bool:
    var nearby = get_buildings_in_radius(position, 5.0)
    var has_walls = false
    var has_roof = false

    for piece in nearby:
        if piece.get_piece_type() == BuildingPiecesData.PieceType.WALL:
            has_walls = true
        if piece.get_piece_type() == BuildingPiecesData.PieceType.ROOF:
            has_roof = true

    return has_walls and has_roof
```

When inside shelter:
- Zombies have difficulty getting in
- Safe from environmental hazards
- Critical for surviving nights

## Integration with Game Systems

### Zombie AI Integration
```gdscript
# In your zombie AI script
func _attack_target(target):
    if target is BuildingPiece:
        # Zombies can damage buildings
        target.take_damage(zombie_damage)
    elif target is Player:
        # Attack player
        target.take_damage(zombie_damage)
```

### Player Inventory Integration
```gdscript
# In your player script
func has_resources(cost: Dictionary) -> bool:
    for resource in cost:
        if inventory.get(resource, 0) < cost[resource]:
            return false
    return true

func consume_resources(cost: Dictionary) -> bool:
    if not has_resources(cost):
        return false

    for resource in cost:
        inventory[resource] -= cost[resource]
    return true
```

### Saving/Loading
```gdscript
# Save building data
func save_buildings() -> Array:
    var data = []
    for piece in get_tree().get_nodes_in_group("building_pieces"):
        if piece is BuildingPiece:
            data.append({
                "id": piece.piece_id,
                "position": var_to_str(piece.global_position),
                "rotation": piece.rotation.y,
                "health": piece.current_health
            })
    return data

# Load building data
func load_buildings(data: Array):
    for piece_data in data:
        var piece = BuildingPiece.new()
        piece.piece_id = piece_data["id"]
        world.add_child(piece)
        piece.global_position = str_to_var(piece_data["position"])
        piece.rotation.y = piece_data["rotation"]
        piece.current_health = piece_data["health"]
```

## Extending the System

### Adding New Building Pieces

Edit `building_pieces_data.gd`:

```gdscript
_add_piece(BuildingPieceData.new(
    "stone_tower",           # ID
    "Stone Tower",          # Display name
    PieceType.WALL,        # Type
    MaterialType.STONE,    # Material
    500.0,                 # Health
    {"stone": 20, "wood": 5},  # Cost
    Vector3(4, 4, 0.5),    # Size
    wall_snaps,            # Snap points
    false,                 # Interactive?
    "Tall defensive tower"  # Description
))
```

### Custom Snap Points

```gdscript
var custom_snaps: Array[Vector3] = [
    Vector3(0, 2, 0),   # Top center
    Vector3(0, -2, 0),  # Bottom center
    Vector3(2, 0, 0),   # Right center
    Vector3(-2, 0, 0),  # Left center
]
```

### Adding Special Effects

```gdscript
# In building_piece.gd, modify _destroy():
func _destroy() -> void:
    # Spawn destruction particles
    var particles = preload("res://effects/building_destroyed.tscn").instantiate()
    get_parent().add_child(particles)
    particles.global_position = global_position

    # Drop resources (50% of cost)
    for resource in piece_data.cost:
        var drop_amount = floor(piece_data.cost[resource] * 0.5)
        spawn_resource_drop(resource, drop_amount)

    piece_destroyed.emit(self)
    queue_free()
```

## Performance Considerations

- Snap point checking is optimized using groups
- Workbench proximity checks are throttled
- Ghost preview only updates when build mode is active
- Collision detection uses layers efficiently

## Future Enhancements

Potential additions:
- **Structural integrity** - pieces need proper support
- **Weather damage** - buildings degrade over time
- **Repair mechanic** - use resources to repair damaged pieces
- **Upgrade system** - upgrade wood to stone
- **Blueprints** - save and load building templates
- **Decay system** - abandoned buildings decay
- **Territory control** - claim areas with buildings

## Troubleshooting

**Ghost preview not showing?**
- Ensure BuildMode is initialized with valid player, camera, and world references
- Check that BuildingPiece class is properly loaded

**Can't place anything?**
- Make sure you have a workbench placed first
- Verify player is within 20m of workbench
- Check that player has required resources

**Pieces not snapping?**
- Verify snap points are properly defined in building_pieces_data.gd
- Check that pieces are in the "building_pieces" group
- Ensure grid_size matches piece sizes (default: 2.0)

**Zombies not damaging buildings?**
- Make sure zombie attacks call `building_piece.take_damage()`
- Verify collision layers are set correctly

## Credits

Built for **Mages-vs-Zombies** - A Godot 4.6 survival game
Inspired by Valheim's intuitive building system
