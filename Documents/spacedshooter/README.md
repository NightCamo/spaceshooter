# Spacedshooter

A small Godot 4 space shooter. Move the ship, collect perks, survive enemy fire,
and destroy different enemy types with automatic weapons.

## Play

1. Open Godot.
2. Click **Import**.
3. Select this folder: `C:\Users\ramab\Documents\spacedshooter`.
4. Open `project.godot`.
5. Press **F5** or the play button.

## Controls

- Move: WASD or arrow keys
- Shoot: automatic
- Laser: L
- Rocket: R
- Bomb: B
- Restart after game over: Space or Enter

When testing from Godot, click inside the running game window first. If the
editor/debugger has focus, keyboard and mouse input will not reach the game.
Use **F5** to run the main project. If you use **F6** by accident, the root
`node_2d.tscn` now also loads the real game.

## Pickups

- `R`: rapid fire
- `S`: spread shot / weapon upgrade
- `D`: shield
- `V`: speed boost
- `+`: extra life
- `B`: bomb / screen clear
- `L`: laser cooldown reset
- `K`: rocket cooldown boost

## Advanced Combat Tests

- F1: spawn a normal enemy
- F2: spawn the boss
- F3: give weapon upgrade
- F4: give shield
- F5: give bomb
- L: fire the laser
- R: launch a homing rocket
- B: use a bomb

The boss also appears every 5 waves. It has 3 health-based phases, a health bar,
warning text for dangerous attacks, drone summons, spread/circle shots, and a
laser sweep.

## Edit Controls In Godot

1. Open **Project > Project Settings**.
2. Go to the **Input Map** tab.
3. Edit these actions: `move_left`, `move_right`, `move_up`, `move_down`,
   `shoot`, and `restart`.
4. Click the plus button beside an action to add another key or mouse button.

## Useful Files

- `scenes/main.tscn`: the full playable game scene
- `scenes/player.tscn`: player ship visuals and bullet scene assignment
- `scenes/bullet.tscn`: player bullet visuals and collision shape
- `scenes/enemy.tscn`: enemy ship visuals and enemy bullet assignment
- `scenes/powerup.tscn`: falling perk pickup
- `scenes/explosion.tscn`: drawn explosion effect
- `scenes/boss.tscn`: multi-phase boss
- `scenes/player_laser.tscn`: player laser special weapon
- `scenes/rocket.tscn`: player homing rocket
- `scripts/player.gd`: movement, shooting, lives, invincibility
- `scripts/main.gd`: enemy spawning, score, lives UI, game over
- `scripts/enemy.gd`: enemy movement, shooting, destruction
- `scripts/powerup.gd`: pickup behavior and perk colors
- `scripts/explosion.gd`: explosion animation
- `scripts/boss.gd`: boss movement, health, phases, attacks
- `scripts/player_laser.gd`: laser beam damage
- `scripts/rocket.gd`: homing rocket targeting and splash damage

## Easy Tweaks

- Player speed: open `scenes/player.tscn`, select `Player`, edit `speed`.
- Fire rate: select `Player`, edit `fire_rate`. Lower is faster.
- Lives: select `Player`, edit `max_lives`.
- Auto-fire: select `Player`, edit `auto_fire_enabled`.
- Enemy spawn speed: open `scenes/main.tscn`, select `Main`, edit
  `spawn_interval`. Lower spawns more enemies.
- Enemy movement/shooting: open `scenes/enemy.tscn`, select `Enemy`, edit
  `speed` or `shoot_interval`.

## Performance Tweaks

- Bullet caps: open `scenes/main.tscn`, select `Main`, edit
  `max_player_bullets` and `max_enemy_bullets`.
- Enemy/pickup/effect caps: edit `max_enemies`, `max_powerups`, and
  `max_explosions`.
- Bullet pool warmup: edit `initial_player_bullet_pool` and
  `initial_enemy_bullet_pool`.
- Rocket pool/cap: edit `initial_rocket_pool` and `max_player_rockets`.
- Mobile background cost: open `scripts/starfield.gd` and lower `star_count`.

## Mobile Controls

Keyboard controls stay enabled for PC testing. Touch-drag movement is handled by
`scripts/player.gd` and can be disabled by selecting `Player` and turning off
`touch_drag_enabled`.

Optional mobile buttons for Laser, Rocket, and Bomb are created by `scripts/main.gd`.
To enable them, open `scenes/main.tscn`, select `Main`, and turn on
`mobile_controls_enabled`.

## Android Export Notes

To export to Android from Godot, install Godot export templates, configure the
Android SDK, install OpenJDK, set a package name, and test on a real device.
Mobile FPS depends heavily on projectile caps, star count, and screen resolution.

## iOS Export Notes

iOS export usually requires macOS, Xcode, an Apple Developer account, signing
certificates, and provisioning profiles. Do not expect to complete the full iOS
export pipeline from Windows alone.
