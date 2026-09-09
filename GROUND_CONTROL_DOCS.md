# Ground Control — Technical Documentation

A browser-based sci-fi multiplayer platformer race. 1–5 players join a room, collect their color-matched key, and race to board the spaceship first.

---

## Table of Contents

1. [Player Movement](#1-player-movement)
2. [Key Collection](#2-key-collection)
3. [Spaceship & Win Condition](#3-spaceship--win-condition)
4. [HUD & Key Status](#4-hud--key-status)
5. [Minimap](#5-minimap)
6. [Scene Navigation](#6-scene-navigation)
7. [WebSocket Multiplayer](#7-websocket-multiplayer)
8. [Remote Player Sync](#8-remote-player-sync)
9. [Deterministic Key Spawning](#9-deterministic-key-spawning)
10. [Pause System](#10-pause-system)
11. [Optimization Notes](#11-optimization-notes)

---

## 1. Player Movement

**Feature:** WASD/arrow key movement with double jump and gravity.

### Nodes Used
| Node | Role |
|---|---|
| `CharacterBody2D` | Root — handles movement and collision response |
| `CollisionShape2D` | Defines the physical hitbox (28×44 rectangle) |
| `Polygon2D` | Visual representation — drawn in code, no texture files needed |
| `Camera2D` | Follows the player by being a child node |

### How It Works

`CharacterBody2D` is Godot's node for player-controlled characters. It does not simulate physics on its own — you control it manually via `velocity` and then call `move_and_slide()` which moves the body and resolves collisions automatically.

```gdscript
# _physics_process runs at fixed 60Hz — required for stable collision
func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += GRAVITY * delta       # manual gravity

    var direction := Input.get_axis("move_left", "move_right")
    velocity.x = direction * SPEED

    move_and_slide()                        # move + resolve collisions
```

Gravity is applied manually every frame. `is_on_floor()` is a built-in check provided by `CharacterBody2D` after `move_and_slide()` runs.

### Why Polygon2D Instead of Sprite2D

Sprite2D requires an image file. Image files created outside the Godot editor don't automatically get `.import` metadata, which means they won't load. `Polygon2D` draws directly from code with zero file dependencies — color is set via the `.color` property.

### Decision: Double Jump

`jump_count` tracks how many jumps have been used. Resets on landing. Cap at 2.

```gdscript
if Input.is_action_just_pressed("jump"):
    if is_on_floor():
        jump_count = 0
    if jump_count < MAX_JUMPS:
        velocity.y = JUMP_VELOCITY
        jump_count += 1
```

---

## 2. Key Collection

**Feature:** Each player is assigned a color. A matching-color key is placed on the map. Only that player can collect their key.

### Nodes Used
| Node | Role |
|---|---|
| `Area2D` | Root — detects player contact without blocking movement |
| `CollisionShape2D` | Defines the pickup area (24×24 rectangle) |
| `Polygon2D` | Diamond-shaped visual, colored to match the player |

### How It Works

`Area2D` fires a `body_entered` signal when a `CharacterBody2D` overlaps it. No manual checking needed every frame.

```gdscript
# key_item.gd
func _on_body_entered(body: Node2D) -> void:
    if body.has_method("collect_key"):
        if body.collect_key(key_color):   # player checks color match
            queue_free()                  # remove key from world
```

Color matching happens in the player:

```gdscript
# player.gd
func collect_key(key_color: Color) -> bool:
    if key_color.is_equal_approx(player_color):
        has_key = true
        return true
    return false
```

`is_equal_approx` is used instead of `==` because floating point color values can have tiny precision differences.

### Why Area2D and Not CharacterBody2D

`Area2D` detects overlap but doesn't physically block anything — the player walks through it. `CharacterBody2D` would push the player away. For a pickup, you want detection only.

---

## 3. Spaceship & Win Condition

**Feature:** Player who collects their key and reaches the spaceship first wins.

### Nodes Used
| Node | Role |
|---|---|
| `Area2D` | Root — detects when a player boards |
| `CollisionShape2D` | Boarding detection zone (80×64) |
| `Sprite2D` | Visual |

### How It Works

```gdscript
# spaceship.gd
signal player_won(player_id: int)

func _on_body_entered(body: Node2D) -> void:
    if body.has_method("can_board_ship") and body.can_board_ship():
        player_won.emit(body.player_id)
```

```gdscript
# player.gd
func can_board_ship() -> bool:
    return has_key   # must have collected key first
```

The win signal flows: `Spaceship → level_01.gd → NetworkManager.send_win() → relay → all clients`.

---

## 4. HUD & Key Status

**Feature:** Always-visible UI showing key collection status, minimap toggle, and pause button.

### Nodes Used
| Node | Role |
|---|---|
| `CanvasLayer` | Root — renders children fixed to screen regardless of camera |
| `Label` | Key status text |
| `Button` | MAP toggle, Pause button |

### Why CanvasLayer

Normal `Node2D` children move with the world. `CanvasLayer` renders at a fixed screen position — camera movement doesn't affect it. This is the standard approach for any HUD/UI overlay in Godot.

### Key Status Update

Called from `level_01.gd` every physics frame:

```gdscript
# hud.gd
func update_key_status(has_key: bool, color: Color) -> void:
    if has_key:
        key_label.text     = "KEY [collected]"
        key_label.modulate = color        # tint label to player color
    else:
        key_label.text     = "KEY [find yours]"
        key_label.modulate = Color(0.6, 0.6, 0.6)
```

---

## 5. Minimap

**Feature:** Toggleable minimap showing platforms, all players, all keys, and the spaceship.

### Nodes Used
| Node | Role |
|---|---|
| `Panel` | Minimap container (200×150px, top-right corner) |
| `Control` + script | Custom drawing canvas |

### How It Works

Godot's `_draw()` API lets you draw shapes directly onto a Control node every frame. The minimap script scales world coordinates to minimap coordinates and draws dots/rects.

```gdscript
# minimap_draw.gd
const WORLD_RECT = Rect2(0, 0, 1280, 720)

func world_to_map(pos: Vector2) -> Vector2:
    return Vector2(
        (pos.x - WORLD_RECT.position.x) / WORLD_RECT.size.x * size.x,
        (pos.y - WORLD_RECT.position.y) / WORLD_RECT.size.y * size.y
    )

func _draw() -> void:
    # draw all players using the "players" group
    for node in get_tree().get_nodes_in_group("players"):
        draw_circle(world_to_map(node.global_position), 4, node.player_color)
```

### Why Groups

Instead of storing direct node references (which break when nodes are freed), minimap uses Godot's **group system**. Any node that calls `add_to_group("players")` in its `_ready()` is automatically found by `get_nodes_in_group("players")`. No coupling between minimap and specific scene structure.

```gdscript
# player.gd _ready()
add_to_group("players")

# key_item.gd _ready()
add_to_group("keys")
```

`queue_redraw()` is called every `_process` frame to trigger a fresh `_draw()` call.

---

## 6. Scene Navigation

**Feature:** Main Menu → Lobby → Level flow, with state surviving transitions.

### The Problem

When you call `get_tree().change_scene_to_file(...)`, the current scene is destroyed. Any variable in that scene is lost — including network connections, player IDs, room codes.

### Solution: Autoload Singleton

`NetworkManager` is declared as an **Autoload** in `project.godot`:

```ini
[autoload]
NetworkManager="*res://scripts/network_manager.gd"
```

Autoloads load once at game start and persist for the entire session. Every scene can read from it:

```gdscript
NetworkManager.my_id        # my player ID
NetworkManager.room_code    # current room
NetworkManager.my_color     # assigned color
```

### Signal Cleanup — Critical Rule

Each scene connects to NetworkManager signals in `_ready()`. If the player completes a round and returns to the main menu, `_ready()` runs again and connects the same signals a second time. Signals would fire twice.

Fix: disconnect in `_exit_tree()`:

```gdscript
func _exit_tree() -> void:
    if NetworkManager.game_started.is_connected(_on_game_started):
        NetworkManager.game_started.disconnect(_on_game_started)
```

### The await Null Trap

After `await get_tree().create_timer(3.0).timeout`, the node might have left the scene tree. Calling `get_tree()` at that point returns null and crashes.

Fix: store the reference before awaiting:

```gdscript
var tree := get_tree()
await tree.create_timer(3.0).timeout
tree.change_scene_to_file("res://scenes/main_menu.tscn")
```

---

## 7. WebSocket Multiplayer

**Feature:** Up to 5 players join a room via a 4-letter code and play together in a browser.

### Why WebSocket and Not Godot's Built-in Multiplayer

Godot's built-in ENet multiplayer uses UDP. Browsers block UDP. WebSocket is the only persistent two-way connection that works in browsers.

### Architecture

```
[Browser 1] ←→ [Railway Relay Server] ←→ [Browser 2]
                        ↕
               [Browser 3, 4, 5...]
```

Players don't connect to each other — all connect to one relay server that forwards messages.

### Relay Server (`relay.js`)

Node.js server using the `ws` package. Tracks rooms:

```javascript
rooms = Map {
    "ABCD" → {
        players:    Map { "1" → ws, "2" → ws },
        colorMap:   Map { "1" → 0, "2" → 1 },
        usedColors: Set { 0, 1 },
        host:       "1"
    }
}
```

All messages are JSON. The server reads the `type` field and routes accordingly:

```javascript
switch (msg.type) {
    case 'create_room': // create room, assign color, reply with code
    case 'join_room':   // validate code, assign color, notify others
    case 'start_game':  // host only — broadcast seed to all
    case 'move':        // forward position to all other players in room
}
```

### Client (`network_manager.gd`)

```gdscript
func _process(_delta: float) -> void:
    _socket.poll()   # must call every frame to send/receive

    if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
        while _socket.get_available_packet_count() > 0:
            _handle_packet(_socket.get_packet())
```

`poll()` is manual — Godot does not automatically receive data. Every incoming message is JSON, parsed and matched to a signal:

```gdscript
match data.get("type", ""):
    "connected":      my_id = str(data["id"]); connected_to_server.emit()
    "game_start":     game_started.emit(int(data["seed"]))
    "move":           position_received.emit(str(data["id"]), Vector2(...))
```

### Color Assignment

Server holds a `COLORS` array matching exactly the `PLAYER_COLORS` in `key_spawner.gd`. Colors are assigned in order and tracked per room so no two players share a color.

---

## 8. Remote Player Sync

**Feature:** All players see each other moving in real time.

### The Problem

Network messages arrive ~20 times per second. The game runs at 60fps. If you snap a remote player to each received position, movement looks like it teleports 20 times per second.

### Solution: Lerp (Linear Interpolation)

```gdscript
# player.gd — remote players only
func _physics_process(delta: float) -> void:
    if not is_local:
        global_position = global_position.lerp(target_position, 12.0 * delta)
        return
```

`lerp(a, b, t)` moves `t`% of the way from `a` to `b`. At 60fps with `t = 12 * delta ≈ 0.2`, the remote player smoothly chases their real position and catches up within a few frames.

### Collision Disabled for Remote Players

Remote players are `CharacterBody2D` with an active collision shape by default. Godot's physics would push the local player away when they overlap.

Fix: disable collision for remote players on spawn:

```gdscript
# player.gd _ready()
if not is_local:
    $CollisionShape2D.disabled = true
```

Remote players are purely visual — they follow lerped positions, no physics needed.

### Position Sending Rate

Sending every frame (60Hz) is wasteful. Positions are sent ~20Hz:

```gdscript
# level_01.gd
_net_tick = (_net_tick + 1) % 3   # every 3 physics frames = 20Hz
if _net_tick == 0:
    NetworkManager.send_position(local_player.global_position)
```

---

## 9. Deterministic Key Spawning

**Feature:** All 5 clients place keys in identical positions without communicating individual positions.

### The Problem

Keys are placed randomly. If each client randomizes independently, Player 1's red key might be at position A on Client 1 but position B on Client 2. The game breaks.

### Solution: Shared Seed

The host picks a random seed and sends it to all players in the `game_start` message. Every client runs the same shuffle with the same seed — producing identical results.

```gdscript
# key_spawner.gd
func spawn_keys() -> void:
    var points := [marker1.pos, marker2.pos, marker3.pos, ...]
    seed(network_seed)    # same seed on all clients
    points.shuffle()      # produces identical order everywhere
    
    for i in active_players:
        var key = KEY_SCENE.instantiate()
        add_child(key)                        # add first
        key.global_position = points[i]      # position after add_child
        key.key_color = PLAYER_COLORS[i]
```

### Critical Order: add_child Before Setting Position

`global_position` requires the node to be inside the scene tree. Setting it before `add_child()` has no effect — the position is silently ignored.

### call_deferred for Spawning

Spawning keys directly in `_ready()` caused timing issues — some nodes weren't fully initialized. `call_deferred("spawn_keys")` queues the call to run after the current frame completes.

---

## 10. Pause System

**Feature:** Any player can pause the game for everyone. Pause lasts max 20 seconds then auto-resumes. Anyone can resume early.

### Network Flow

```
Player presses pause
    → send_pause() to relay
    → relay checks: already paused? → ignore
    → relay broadcasts "paused" to ALL players (including pauser)
    → relay starts 20-second server-side timer
    → all clients receive "paused" → get_tree().paused = true
```

The timer is server-side so all clients agree on the deadline regardless of clock differences.

### Why PROCESS_MODE_ALWAYS

When `get_tree().paused = true`, all nodes stop running by default. Two systems must keep running while paused:

1. **NetworkManager** — must keep polling WebSocket to receive the `resumed` message
2. **HUD** — must count down the timer and accept button clicks

```gdscript
# network_manager.gd
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

# hud.gd
func _ready() -> void:
    process_mode               = Node.PROCESS_MODE_ALWAYS
    pause_button.process_mode  = Node.PROCESS_MODE_ALWAYS
    resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
```

Setting `process_mode` explicitly in code is more reliable than setting it in the `.tscn` file — inheritance through CanvasLayer children is inconsistent for Control nodes when paused.

### Color Identification

Instead of showing a player number, the pause label is tinted with the pausing player's color:

```gdscript
func _on_game_paused(by_pid: String) -> void:
    var color := NetworkManager.players.get(by_pid, {}).get("color", Color.WHITE)
    pause_label.text     = "● paused the game"
    pause_label.modulate = color
```

---

## 11. Optimization Notes

### What Could Be Improved

| Area | Current | Better |
|---|---|---|
| Position sync | Send raw Vector2 every 3 frames | Delta compression — only send if moved more than N pixels |
| Remote lerp | `lerp` at fixed rate | Snapshot interpolation with timestamps for variable latency |
| Minimap redraw | Redraws every frame via `queue_redraw()` | Only redraw when a node has actually moved |
| Key spawner markers | Hardcoded Marker2D children | Export array of positions for easier level design |
| Win screen | Label added in code | Dedicated win screen scene with proper UI |
| Server | Single relay.js process | Add room cleanup for abandoned rooms, reconnection support |

### What Was Intentionally Kept Simple

- **No client-side prediction** — local player input isn't predicted and corrected, it's just sent. For a slow-paced platformer this is fine. For a fast competitive game it would cause lag.
- **No reconnection** — if a player disconnects mid-game they can't rejoin. Server promotes next player as host automatically.
- **No cheat prevention** — any client can claim a win. Relay forwards it without validation. Acceptable for a casual game.

---

## Deployment

- **Relay server**: Node.js on Railway — `wss://ground-control-production-527b.up.railway.app`
- **Game client**: Exported as HTML5/WebAssembly via Godot's Web export preset with `ensure_cross_origin_isolation_headers=true` (required for SharedArrayBuffer)
- **Hosting**: Upload exported zip to itch.io as an HTML5 game
