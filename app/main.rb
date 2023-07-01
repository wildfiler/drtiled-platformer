require 'lib/tiled/tiled.rb'
require 'lib/tiledriver/tiledriver.rb'

def tick(args)
  if args.tick_count.zero?
    map = Tiled::Map.new('maps/level0.tmx').tap(&:load)
    renderer = Tiled::Renderer.new(args, map)
    args.state.renderer = renderer
    args.state.map = map
  end

  renderer = args.state.renderer
  renderer.camera.position = [0,0]
  renderer.camera.zoom = 2
  renderer.render_map
end
