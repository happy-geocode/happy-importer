module HappyImporter
  module Document
    class NodeDocument < Nokogiri::XML::SAX::Document

      def initialize(database)
        @database = database
        @node_count = 0
      end

      def start_element name, attrs = []
        attributes = Hash[attrs]
        case name
          when 'node'
            @database.execute "INSERT INTO osm_nodes (id, lat, lon) VALUES (#{attributes['id'].to_i}, #{attributes['lat'].to_f}, #{attributes['lon'].to_f});"
            @node_count += 1
            puts @node_count if @node_count % 10000 == 0
        end
      end

      def end_element name
        #puts "#{name} ended"
      end
    end
  end
end