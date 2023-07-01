require 'lib/tiled/tiled.rb'
require 'lib/tiledriver/tiledriver.rb'

def tick(args)
  if args.tick_count.zero?
    setup_renderer(args)
    setup_player(args)
  end

  move_to(args, 32, 64) if args.state.player.y < -256
  move_to(args, 608, 300) if args.inputs.keyboard.key_down.r
  player_collider = get_player_collider(args)
  acceleration = {
    x: 0,
    y: -0.15 # gravity constant in hamster world.
  }

  args.state.player_flying = collided_with(args.state.collision_rects, player_collider.shift_rect(0, -1)).empty?

  process_input(args, acceleration)
  process_speed(args, acceleration)
  process_collisions(args)
  update_player_sprite(args)
  move_by(args, args.state.speed.x, args.state.speed.y)

  args.outputs.background_color = args.state.map.backgroundcolor.to_a
  renderer = args.state.renderer
  renderer.camera.track(get_player_collider(args))
  renderer.render_map(sprites: args.state.player_sprite, depth: 1)
end

def setup_renderer(args)
  map = Tiled::Map.new('maps/level0.tmx').tap(&:load)
  args.state.collision_rects = map.collision_objects

  renderer = Tiled::Renderer.new(args, map)
  args.state.map = map
  args.state.renderer = renderer
  renderer.camera.zoom = 2.25
end

def setup_player(args)
  tileset = Tiled::Tileset.load('tilesets/mr_cookies.tsx')

  player = { x: 32, y: 64 }
  args.state.player = player
  args.state.player_collider = tileset.tiles[0].object_layer.objects.find { |o| o.name == 'collider' }

  player_origin = tileset.tiles[0].object_layer.objects.find { |o| o.name == 'origin' }
  args.state.player_origin = player_origin
  args.state.player_sprites = {
    idle: tileset.animated_sprite_at(player.x - player_origin.x, player.y - player_origin.y, 0),
    running: tileset.animated_sprite_at(player.x - player_origin.x, player.y - player_origin.y, 7),
    flying_up: tileset.sprite_at(player.x - player_origin.x, player.y - player_origin.y, 23),
    flying_down: tileset.sprite_at(player.x - player_origin.x, player.y - player_origin.y, 28),
  }
  args.state.player_sprite = args.state.player_sprites[:idle]

  args.state.speed = { x: 0, y: 0 }
  args.state.flip = false
end

def collided_with(colliders, player)
  colliders.select { |rect| rect.intersect_rect? player }
end

def move_by(args, x, y)
  args.state.player[:x] += x
  args.state.player[:y] += y
  move_player_sprite(args)
end

def move_to(args, x, y)
  args.state.player[:x] = x
  args.state.player[:y] = y
  move_player_sprite(args)
  args.state.speed = { x: 0, y: 0 }
end

def move_player_sprite(args)
  args.state.player_sprite.x = (args.state.player.x - args.state.player_origin.x).to_i
  args.state.player_sprite.y = (args.state.player.y - args.state.player_origin.y).to_i
end

def get_player_collider(args)
  player = args.state.player
  collider = args.state.player_collider
  origin = args.state.player_origin

  collider.to_primitive(player.x - origin.x, player.y - origin.y)
end

def process_collisions(args)
  new_player_rect = get_player_collider(args).shift_rect(args.state.speed.x, args.state.speed.y)
  obstacles = collided_with(args.state.collision_rects, new_player_rect)

  return if obstacles.empty?

  if obstacles.any_intersect_rect? new_player_rect.merge(x: args.state.player.x)
    args.state.speed[:y] = 0
  end

  if obstacles.any_intersect_rect? new_player_rect.merge(y: args.state.player.y)
    args.state.speed[:x] = 0
  end
end

def process_input(args, acceleration)
  if args.inputs.keyboard.key_down.i
    args.state.show_debug = !args.state.show_debug
  end

  if args.inputs.left_right != 0
    args.state.flip = args.inputs.left_right < 0
    acceleration[:x] += args.inputs.left_right * 0.1
  elsif !args.state.player_flying
    if args.state.speed[:x].abs > 0
      acceleration[:x] -= 0.2 * args.state.speed[:x].sign
    end
  else
    acceleration[:x] -= 0.02 * args.state.speed[:x].sign # friction
  end

  if args.inputs.keyboard.key_down.up && !args.state.player_flying
    acceleration[:y] += 4.2
  end
end

def process_speed(args, acceleration)
  args.state.speed[:x] = (args.state.speed[:x] + acceleration[:x]).clamp(-2, 2)
  args.state.speed[:x] = 0 if args.state.speed[:x].abs < 0.1
  args.state.speed[:y] = (args.state.speed[:y] + acceleration[:y]).clamp(-10, 10)
end

def get_player_state(args)
  if args.state.player_flying
    if args.state.speed[:y] >= 0
      :flying_up
    else
      :flying_down
    end
  else
    if args.state.speed[:x].abs > 0
      :running
    else
      :idle
    end
  end
end

def update_player_sprite(args)
  args.state.player_sprite = args.state.player_sprites[get_player_state(args)]
  args.state.player_sprite.flip_horizontally = args.state.flip
end
