# Building System - Quick Start Guide

## Setup (5 Minutes)

### Step 1: Add to Your Player Script

```gdscript
extends CharacterBody3D

var build_mode: BuildMode

func _ready():
    # Create build mode instance
    build_mode = BuildMode.new()
    add_child(build_mode)

    # Initialize with references
    var camera = $Camera3D  # Adjust to your camera path
    var world = get_parent()  # Usually the main scene
    build_mode.initialize(self, camera, world)

    # Connect signals (optional)
    build_mode.build_piece_placed.connect(_on_building_placed)

func _input(event):
    # Toggle build mode with B key
    if event is InputEventKey and event.pressed and event.keycode == KEY_B:
        build_mode.toggle()

func _on_building_placed(piece_id: String, pos: Vector3, rot: float):
    print("Built: ", piece_id)
```

### Step 2: Add Resource Management to Player

```gdscript
# Add to your player script
var inventory: Dictionary = {
    "wood": 100,
    "stone": 50,
    "iron": 10
}

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

### Step 3: Place a Starting Workbench

```gdscript
# In your level/world script
func _ready():
    # Spawn a workbench at spawn point
    var workbench = CraftingStation.new()
    add_child(workbench)
    workbench.global_position = Vector3(0, 0, 0)
```

## That's It!

You now have a fully functional building system!

## Controls

- **B** - Toggle build mode
- **R** - Rotate piece
- **Left Click** - Place piece
- **Right Click / ESC** - Cancel

## Testing

1. Run your game
2. Press **B** to enter build mode
3. You should see a green ghost of a wooden wall
4. Aim at the ground
5. Press **R** to rotate
6. Click to place

## Building Pieces Available

| Piece | HP | Cost | Type |
|-------|----|----|------|
| Wooden Wall | 100 | 4 wood, 2 stone | WALL |
| Wooden Floor | 80 | 3 wood | FLOOR |
| Wooden Door | 60 | 4 wood, 1 iron | DOOR |
| Wooden Stairs | 70 | 5 wood | STAIRS |
| Wooden Beam | 90 | 2 wood | BEAM |
| Wooden Roof 26° | 80 | 3 wood, 1 stone | ROOF |
| Wooden Roof 45° | 80 | 3 wood, 1 stone | ROOF |
| Stone Wall | 300 | 6 stone, 1 wood | WALL |
| Stone Floor | 250 | 4 stone | FLOOR |
| Reinforced Door | 200 | 4 wood, 4 iron, 2 stone | DOOR |

## Switching Between Pieces

Add this to your player script:

```gdscript
func _input(event):
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_B: build_mode.toggle()
            KEY_1: build_mode.set_current_piece("wooden_wall")
            KEY_2: build_mode.set_current_piece("wooden_floor")
            KEY_3: build_mode.set_current_piece("wooden_door")
            KEY_4: build_mode.set_current_piece("wooden_stairs")
            KEY_5: build_mode.set_current_piece("wooden_beam")
            KEY_6: build_mode.set_current_piece("wooden_roof_26")
```

## Making Zombies Damage Buildings

In your zombie AI script:

```gdscript
func attack_target(target):
    if target is BuildingPiece:
        target.take_damage(20.0)  # Zombie does 20 damage
        print("Zombie attacking building!")
```

## Shelter Detection

To check if player is in shelter (protected from zombies):

```gdscript
func is_player_in_shelter() -> bool:
    var nearby = []
    for piece in get_tree().get_nodes_in_group("building_pieces"):
        if piece.global_position.distance_to(player.global_position) < 5.0:
            nearby.append(piece)

    var has_walls = false
    var has_roof = false

    for piece in nearby:
        if piece is BuildingPiece:
            if piece.get_piece_type() == BuildingPiecesData.PieceType.WALL:
                has_walls = true
            elif piece.get_piece_type() == BuildingPiecesData.PieceType.ROOF:
                has_roof = true

    return has_walls and has_roof
```

## Common Issues

**"Can't place - too far from workbench"**
- Place a workbench first (it's free to place anywhere)
- Stand within 20m of the workbench

**"Ghost is red, can't place"**
- You're overlapping another building
- Move slightly or adjust rotation

**"Nothing happens when I press B"**
- Make sure you called `build_mode.initialize()`
- Check console for errors

## Next Steps

1. ✅ Read `BUILDING_SYSTEM_README.md` for full details
2. ✅ Check `building_system_example.gd` for integration examples
3. ✅ Customize building pieces in `building_pieces_data.gd`
4. ✅ Add custom buildings and features

## Pro Tips

- **Grid snapping**: Buildings snap to a 2x2 grid automatically
- **Piece snapping**: Walls snap to floors, stairs connect, etc.
- **Resource efficiency**: Stone buildings cost more but have 3x HP
- **Defense**: Build walls with a door for zombie-proof shelter
- **Verticality**: Use stairs and floors to build multi-story bases

Enjoy building!
