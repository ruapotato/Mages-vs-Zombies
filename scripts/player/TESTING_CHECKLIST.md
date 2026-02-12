# Player System Testing Checklist

Use this checklist to verify all player features are working correctly.

## Pre-Test Setup

- [ ] Project opens in Godot 4.6 without errors
- [ ] No script errors in Output console
- [ ] `scenes/main/game.tscn` is set as main scene
- [ ] All input actions are configured in Project Settings

## Basic Movement

- [ ] **W key** - Character moves forward relative to camera
- [ ] **S key** - Character moves backward relative to camera
- [ ] **A key** - Character moves left relative to camera
- [ ] **D key** - Character moves right relative to camera
- [ ] **Diagonal movement** - WASD combinations work smoothly
- [ ] **Movement stops** - Releasing keys brings character to smooth stop
- [ ] **Sprint** - Hold Shift increases movement speed noticeably
- [ ] **Sprint release** - Releasing Shift smoothly reduces to walk speed

## Jumping

- [ ] **Space bar** - Character jumps when on ground
- [ ] **Jump height** - Consistent jump height (~2-3 units)
- [ ] **Double jump** - Press Space again in air for second jump
- [ ] **Double jump limit** - Cannot triple jump
- [ ] **Ground reset** - Landing resets double jump ability
- [ ] **Gravity** - Character falls at appropriate rate

## Camera

- [ ] **Mouse look** - Moving mouse rotates camera smoothly
- [ ] **Horizontal rotation** - Full 360° rotation works
- [ ] **Vertical limit** - Camera stops at ~80° up and down
- [ ] **Camera follows** - Camera stays with player during movement
- [ ] **Smooth rotation** - No jittery or stuttering motion
- [ ] **ESC key** - Shows/hides mouse cursor
- [ ] **Re-capture** - Clicking in window re-captures mouse

## Animation System

### Idle Animation
- [ ] **Breathing** - Sprite gently scales up/down when standing still
- [ ] **Sway** - Slight side-to-side motion when idle
- [ ] **Smooth** - No jerky transitions

### Walk Animation
- [ ] **Bob** - Sprite bounces up/down while walking
- [ ] **Squash/stretch** - Sprite squashes when foot hits ground
- [ ] **Tilt** - Sprite leans slightly in movement direction
- [ ] **Speed sync** - Animation speed matches movement speed
- [ ] **Sprint animation** - Faster bob when sprinting

### Jump Animation
- [ ] **Takeoff squash** - Sprite squashes when leaving ground
- [ ] **Air stretch** - Sprite stretches while rising
- [ ] **Apex tuck** - Slight tuck at top of jump
- [ ] **Fall stretch** - Sprite stretches while falling

### Cast Animation
- [ ] **Trigger** - Animation plays when casting spell (press 1-5)
- [ ] **Windup** - Brief preparation motion
- [ ] **Raise** - Sprite lifts slightly during cast
- [ ] **Return** - Smooth return to idle/walk state

## Health System

Test using debug console or PlayerDebugUI:

- [ ] **Initial health** - Starts at 100/100
- [ ] **Take damage** - Call `player.take_damage(25)` in debug console
- [ ] **Health decreases** - Value drops correctly
- [ ] **Regen delay** - No regen for first 5 seconds after damage
- [ ] **Health regen** - Health increases at 2 HP/sec after delay
- [ ] **Regen caps** - Stops at max_health (100)
- [ ] **Death** - Console message when health reaches 0

## Mana System

- [ ] **Initial mana** - Starts at 100/100
- [ ] **Mana regen** - Increases at 5 mana/sec
- [ ] **Regen always on** - No delay, always regenerating
- [ ] **Regen caps** - Stops at max_mana (100)
- [ ] **Spell cost** - Mana decreases when casting spells

## Spell System

### Spell Slot 1 (Fireball - 15 mana, 1s CD)
- [ ] **Press 1** - Console prints "Cast spell: fireball"
- [ ] **Mana cost** - Mana decreases by 15
- [ ] **Cooldown** - Cannot cast again for 1 second
- [ ] **Animation** - Cast animation plays

### Spell Slot 2 (Ice Spike - 20 mana, 1.5s CD)
- [ ] **Press 2** - Console prints "Cast spell: ice_spike"
- [ ] **Mana cost** - Mana decreases by 20
- [ ] **Cooldown** - Cannot cast again for 1.5 seconds

### Spell Slot 3 (Lightning - 25 mana, 2s CD)
- [ ] **Press 3** - Console prints "Cast spell: lightning"
- [ ] **Mana cost** - Mana decreases by 25
- [ ] **Cooldown** - Cannot cast again for 2 seconds

### Spell Slot 4 (Heal - 30 mana, 10s CD)
- [ ] **Press 4** - Console prints "Cast spell: heal"
- [ ] **Mana cost** - Mana decreases by 30
- [ ] **Cooldown** - Cannot cast again for 10 seconds

### Spell Slot 5 (Shield - 20 mana, 8s CD)
- [ ] **Press 5** - Console prints "Cast spell: shield"
- [ ] **Mana cost** - Mana decreases by 20
- [ ] **Cooldown** - Cannot cast again for 8 seconds

### Spell Restrictions
- [ ] **Low mana** - Console message "Not enough mana!" when insufficient
- [ ] **On cooldown** - Console message with remaining time
- [ ] **Can't cast** - Spell doesn't fire when restricted
- [ ] **Multiple spells** - Can cast different spells while one is on CD

## Build Mode

- [ ] **Press B** - Console prints "Build mode: ON"
- [ ] **Press B again** - Console prints "Build mode: OFF"
- [ ] **Toggle state** - Can toggle on/off repeatedly

## Physics & Collision

- [ ] **Ground collision** - Character stands on platform
- [ ] **No fall through** - Character doesn't fall through floor
- [ ] **Edge handling** - Can walk to edge without issues
- [ ] **Wall collision** - Character stops at walls (if walls added)
- [ ] **Slope handling** - Walks smoothly on angled surfaces (if slopes added)

## Billboard System

- [ ] **Sprite visible** - Can see the sprite (or white square if no texture)
- [ ] **Always faces camera** - Sprite rotates to face camera
- [ ] **No flip side** - Never see "back" of sprite
- [ ] **360° test** - Rotate camera all around, sprite always faces you
- [ ] **Height correct** - Sprite positioned at character center (~0.9 units up)

## Performance

- [ ] **Frame rate** - Consistent 60 FPS (or monitor refresh rate)
- [ ] **No stuttering** - Smooth movement at all times
- [ ] **No memory leaks** - Memory usage stable over time
- [ ] **Quick load** - Scene loads in under 2 seconds

## Debug UI (Optional)

If you added the PlayerDebugUI script:

- [ ] **Position display** - Shows current XYZ coordinates
- [ ] **Velocity display** - Shows velocity vector
- [ ] **Health/Mana bars** - Shows current and max values
- [ ] **Spell status** - Shows all 5 spells with cooldowns
- [ ] **Animation state** - Shows current animation
- [ ] **Real-time updates** - All values update smoothly

## Edge Cases

- [ ] **Rapid key presses** - No input breaking or stuck states
- [ ] **Spam jump** - Cannot break jump system with spam
- [ ] **Spam spells** - Cooldowns work even with rapid presses
- [ ] **Walk off edge** - Falls and lands properly
- [ ] **Zero mana** - Cannot cast any spells
- [ ] **Full health** - Regen stops at max, doesn't overflow
- [ ] **Alt-Tab** - Game recovers when window loses focus

## Integration Tests

- [ ] **Save/Load** - Position/stats persist if save system added
- [ ] **Enemy damage** - Takes damage from enemy attacks (when enemies added)
- [ ] **Spell projectiles** - Projectiles spawn at correct position (when spells added)
- [ ] **UI integration** - Health/mana bars update correctly (when UI added)

## Known Limitations (Expected Behavior)

These are not bugs:

- [ ] No sprite texture (white square) - Normal until sprite assigned
- [ ] Spells print to console only - Projectiles not implemented yet
- [ ] No death respawn - Death system not implemented
- [ ] No footstep sounds - Audio not implemented
- [ ] Character slides on ice - Physics materials not configured

## Troubleshooting

### Character Falls Through Floor
**Fix**: Ensure Ground StaticBody3D has CollisionShape3D and is on Layer 1

### Camera Not Working
**Fix**: Press ESC twice to recapture mouse, check Camera3D exists in scene

### Spells Not Casting
**Fix**: Check console for mana/cooldown messages, verify Input Map has spell_1-5

### No Animation
**Fix**: Verify AnimationController is in scene, sprite reference is set

### Input Not Working
**Fix**: Check Project Settings -> Input Map for all actions

## Test Results

Date Tested: _______________
Tester: _______________
Godot Version: 4.6

Pass Rate: ____ / ____ tests passed

Critical Issues:
-

Minor Issues:
-

Notes:
-
