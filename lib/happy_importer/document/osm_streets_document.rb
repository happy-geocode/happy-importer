module HappyImporter
  module Document
    class OsmStreetsDocument < Nokogiri::XML::SAX::Document

      attr_reader :streets, :nodes

      def initialize
        @streets = {}
        @nodes = {}
        @current_street = nil
      end

      def start_element name, attrs = []
        attributes = Hash[attrs]

        case name
          when 'way'
            @current_street = attributes['id']
            @streets[@current_street] = { nodes: [], name: nil, refs: [] }
          when 'nd'
            @streets[@current_street][:nodes] << attributes['ref']

            @nodes[attributes['ref']] ||= []
            @nodes[attributes['ref']] << @current_street

          when 'tag'
            @streets[@current_street][:name] = attributes['v'] if attributes['k'] == 'name'
        end
      end

    end
  end
end
