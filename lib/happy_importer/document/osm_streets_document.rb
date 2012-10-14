module HappyImporter
  module Document
    class OsmStreetsDocument < Nokogiri::XML::SAX::Document

      attr_reader :streets, :nodes

      def initialize(node_coords)
        @node_coords = node_coords
        @streets = {}
        @nodes = {}
        @current_street = nil
      end

      def start_element name, attrs = []
        attributes = Hash[attrs]

        case name
          when 'way'
            @current_street = attributes['id']
            @streets[@current_street] = { points: [], name: nil, name_normalized: nil, other_part_refs: [] }
          when 'nd'
            @streets[@current_street][:points] << node_coords[attributes['ref']]

            @nodes[attributes['ref']] ||= []
            @nodes[attributes['ref']] << @current_street

          when 'tag'
            if attributes['k'] == 'name'
              @streets[@current_street][:name] = attributes['v']
              @streets[@current_street][:name] = attributes['v'].normalize_for_parsec
            end
        end
      end

    end
  end
end
