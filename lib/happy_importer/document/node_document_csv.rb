module HappyImporter
  module Document

    # This class is used to export a node document into a CSV file by the form:
    # ID; LATITUDE; LONGITUDE
    # This file can be imported to ArangoDB using arangoimp
    class NodeDocumentCsv < Nokogiri::XML::SAX::Document

      def initialize(file)
        @file = file
        @node_count = 0
        @file.puts 'id;lat;lon'
      end

      def start_element name, attrs = []
        attributes = Hash[attrs]
        case name
          when 'node'
            @file.puts "#{attributes['id'].to_i};#{attributes['lat'].to_f};#{attributes['lon'].to_f}"
            @node_count += 1
            puts @node_count if @node_count % 1_000_000 == 0
        end
      end
    end
  end
end
