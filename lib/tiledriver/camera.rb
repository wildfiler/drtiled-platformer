module Tiled
  # The default deadzone in which a `#track`ed item may move
  # freely without moving the camera
  DEADZONE_DEFAULT = 128

  # Controller for a camera which moves around the map. It points to the pixel on the map
  # that is rendered to the lower-left pixel of the screen.
  class Camera
    include Tiled::Serializable
    attr_reader :rect, :zoom, :deadzone

    def initialize(args, map)
      @args = args
      @map = map

      @screen_width = args.grid.w.to_f
      @screen_height = args.grid.h.to_f

      # The camera is represented internally as a rectangle overlayed on the map
      @rect = [
        map.properties[:camera_origin_x] || 0,
        map.properties[:camera_origin_y] || 0,
        map.properties[:camera_origin_w] || @screen_width,
        map.properties[:camera_origin_h] || @screen_height
      ]

      @zoom = 1
      @min_zoom = nil
      @max_zoom = nil

      @map_width = map.pixelwidth
      @map_height = map.pixelheight

      @render_width = @map_width
      @render_height = @map_height
      @render_scale = [1, 1]

      @deadzone = {}
      set_deadzone up: DEADZONE_DEFAULT, down: DEADZONE_DEFAULT,
                   left: DEADZONE_DEFAULT, right: DEADZONE_DEFAULT
    end

    # @return [Float] the map X-coordinate of the camera
    def x
      rect.x
    end

    # @param value [Numeric] map X-coordinate to set
    def x=(value)
      rect.x = value
    end

    # @return [Float] the map Y-coordinate of the camera
    def y
      rect.y
    end

    # @param value [Numeric] map Y-coordinate to set
    def y=(value)
      rect.y = value
    end

    # @return [Array] the map coordinates of the lower-left corner of the camera
    def position
      [rect.x, rect.y]
    end

    # @param point [Array] the map coordinates to set the camera to
    def position=(point)
      rect.x = point.x
      rect.y = point.y
    end

    # Pans the camera around the map. Will not pan past the edges
    # of the map. You can pass in either X, Y, or both.
    #
    # @option :x [Numeric] the amount to pan on the X-axis
    # @option :y [Numeric] the amount to pan on the Y-axis
    def pan(x: nil, y: nil)
      if x
        @rect.x = [
          0,
          @rect.x + x,
          @map_width - @rect.w
        ].sort[1]
      end

      if y
        @rect.y = [
          0,
          @rect.y + y,
          @map_height - @rect.h
        ].sort[1]
      end
    end

    alias move pan

    # Sets zoom. Zoom is a value > 0 that is used as a scale amount. For example,
    # if zoom is set to 2, objects will appear twice as large as they did at zoom 1.
    #
    # @param value [Numeric] the value to set the zoom to
    def zoom=(value)
      @zoom = value
      calculate_zoom
    end

    # @param amount [Numeric] the amount to increase the zoom by
    def zoom_in(amount)
      if @max_zoom && zoom + amount > @max_zoom
        @zoom = @max_zoom
      else
        @zoom += amount
      end

      calculate_zoom
    end

    # Zooms the camera out. Will not zoom out to reveal past the edges of the map.
    # If up against only one edge, the camera will zoom out but will not be able
    # to remain centered and will stay butted up against the edge.
    #
    # @param amount [Numeric] the amount to decrease the zoom by
    def zoom_out(amount)
      orig_zoom = @zoom

      if @min_zoom && zoom - amount < @min_zoom
        @zoom = @min_zoom
      else
        @zoom -= amount
      end

      calculate_zoom

      # Roll back if we've zoomed out of bounds of the map
      if @rect.w > @map_width || @rect.h > @map_height
        @zoom = orig_zoom
        calculate_zoom
      end
    end

    # Gets the X, Y, width, and height to render a layer/map at based on
    # the camera's zoom and positioning.
    #
    # @param parallax [Array] the parallax value of the layer
    # @return [Hash] the camera-adjusted x, y, w, and h positioning of the layer
    def render_rect(parallax=[1, 1])
      {
        x: -x * @render_scale.x * parallax.x,
        y: -y * @render_scale.y * parallax.y,
        w: @render_width,
        h: @render_height
      }
    end

    # Sets the "deadzone" in the middle of the camera around which the player
    # may move freely without disturbing the position of the camera if using
    # `#track` to follow an external primitive. You may set any or all directons.
    #
    # #option up [Numeric] the deadzone's height above the center
    # #option down [Numeric] the deadzone's height below the center
    # #option left [Numeric] the deadzone's width left of the center
    # #option right [Numeric] the deadzone's width right of the center
    def set_deadzone(up: nil, down: nil, left: nil, right: nil)
      { up: up, down: down, left: left, right: right }.each do |direction, value|
        @deadzone[direction] = value if value
      end
    end

    # Adjust the camera's position to keep `target` within the deadzone.
    #
    # @param target [Array || Hash] a rectangle with x, y, w, and h
    def track(target)
      opposite =  [target.x + target.w, target.y + target.h]

      center_point = center
      upper_right = upper_right_corner

      right_margin = center_point.x + deadzone[:right]
      if opposite.x > right_margin && upper_right.x < @map_width
        pan x: opposite.x - right_margin
      elsif target.x < (left_margin = center_point.x - deadzone[:left]) && x > 0
        pan x: target.x - left_margin
      end

      up_margin = center_point.y + deadzone[:up]
      if opposite.y > up_margin && upper_right.y < @map_height
        pan y: opposite.y - up_margin
      elsif target.y < (down_margin = center_point.y - deadzone[:down]) && y > 0
        pan y: target.y - down_margin
      end
    end

    alias follow track

    # @return [Array<Float>] the map pixel located at the center of the camera
    def center
      [
        x + (@screen_width / 2 / @render_scale.x),
        y + (@screen_height / 2 / @render_scale.y)
      ]
    end

    # @return [Array<Float>] the map pixel located at the upper-right corner of the camera
    def upper_right_corner
      [
        x + (@screen_width / @render_scale.x),
        y + (@screen_height / @render_scale.y)
      ]
    end

    private

    # This needs to run every time zoom changes.
    def calculate_zoom
      aspect_ratio = @screen_width / @screen_height

      # Zoom needs to be reflected about 1 because increasing zoom
      # actually needs to decrease the size of the rectangle
      render_scale = zoom > 0 ? 1 + (1 - Math.sqrt(zoom)) : 0

      orig_width, orig_height = @rect.w, @rect.h

      @rect.w = @screen_width * render_scale
      @rect.h = @screen_height * render_scale

      if aspect_ratio > 1.0
        # Landscape
        @rect.w = @rect.h * aspect_ratio
      else
        # Portrait
        @rect.h = @rect.w / aspect_ratio
      end

      # Scale the map's render width according to the zoom
      @render_width = (@screen_width / @rect.w) * @map_width
      @render_height = (@screen_height / @rect.h) * @map_height
      @render_scale = [@render_width / @map_width, @render_height / @map_height]

      # #pan handles edge collisions
      pan x: (orig_width - @rect.w) / 2,
          y: (orig_height - @rect.h) / 2
    end
  end
end
