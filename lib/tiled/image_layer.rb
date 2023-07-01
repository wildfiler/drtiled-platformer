class Tiled::ImageLayer
  include Tiled::Serializable
  include Tiled::WithAttributes

  attr_reader :map, :image

  attributes :id, :name, :x, :y, :width, :height, :opacity, :visible, :tintcolor, :offset, :parallax, :repeatx, :repeaty

  def initialize(map)
    @map = map
  end

  def from_xml_hash(hash)
    raw_attributes = hash[:attributes]
    raw_attributes['visible'] = raw_attributes['visible'] != '0'
    raw_attributes['offset'] = [raw_attributes.delete('offsetx').to_f,
                                -raw_attributes.delete('offsety').to_f]
    raw_attributes['parallax'] = [raw_attributes.delete('parallaxx')&.to_f || 1.0,
                                  raw_attributes.delete('parallaxy')&.to_f || 1.0]

    attributes.add(raw_attributes)

    hash[:children].each do |child|
      case child[:name]
      when 'properties'
        properties.from_xml_hash(child[:children])
      when 'image'
        puts child
        @image = Tiled::Image.new(map)
        image.from_xml_hash(child)
      end
    end

    self
  end
end
