module HappyImporter
  module Document
    class OsmStreetsDocument < Nokogiri::XML::SAX::Document

      attr_reader :streets, :nodes, :street_points

      def initialize(arango)
        @streets = {}
        @arango = arango
        @nodes = {}
        @street_points = []
        @current_street = nil
      end

      def start_element name, attrs = []
        attributes = Hash[attrs]

        case name
          when 'way'
            @current_street = attributes['id']
            @streets[@current_street] = { osm_id: @current_street, points: [], name: nil, name_normalized: nil, other_part_refs: [] }
          when 'nd'
            result = @arango['locations'].first_example({ id: attributes['ref'] })
            #@streets[@current_street][:points] << { lat: result['lat'], lon: result['lon'] }

            @steet_points << { street_ref: @current_street, lat: result['lat'], lon: result['lon'] }

            @nodes[attributes['ref']] ||= []
            @nodes[attributes['ref']] << @current_street

          when 'tag'
            if attributes['k'] == 'name'
              @streets[@current_street][:name] = attributes['v']
              @streets[@current_street][:name_normalized] = attributes['v'].normalize_for_parsec
            end
        end
      end

    end
  end
end
