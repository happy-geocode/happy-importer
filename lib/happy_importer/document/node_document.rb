module HappyImporter
  module Document
    class NodeDocument < Nokogiri::XML::SAX::Document

      attr_reader :nodes

      def initialize
        @nodes = Hash.new
        @node_count = 0
      end

      def start_element name, attrs = []
        attributes = Hash[attrs]
        case name
          when 'node'
            @nodes[attributes['id']] = { lat: attributes['lat'].to_f, lon: attributes['lon'].to_f }
            @node_count += 1
            puts "#{Time.new} [Reading nodes to memory] #{@node_count}" if @node_count % 1000000 == 0
        end
      end

      def end_element name
        #puts "#{name} ended"
      end
    end
  end
end
