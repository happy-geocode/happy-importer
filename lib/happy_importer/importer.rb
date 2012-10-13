module HappyImporter
  class Importer

    def initialize(filename, arango_host = nil)
      @filename = filename
      @arango_host = arango_host
    end

    def self.check_osmosis
      if `which osmosis`.empty?
        puts "You need to install osmosis. Use homebrew, apt or what-ever you want..."
      end
    end

    # This function extracts the nodes from the OSM XML file and stores them in the sqlite database
    def extract_nodes
      # Shell out to osmosis to extract the nodes and store them in the sqlite
      if File.exist?('/tmp/osm-nodes.xml')
        puts '[Extract Nodes] We already have the node extraction ... Skipping'
      else
        puts "[Extract Nodes] Osmosis is running to extract the nodes"
        `osmosis --read-xml file="#{@filename}" --tag-filter reject-ways --tag-filter reject-relations --write-xml /tmp/osm-nodes.xml`
      end

      puts "[Extract Nodes] Now we are parsing the XML and putting everything into a CSV file ... Please stand by (this might take a while)"
      f = File.open('/tmp/temp-nodes.csv', 'w')
      parser = ::Nokogiri::XML::SAX::Parser.new(Document::NodeDocument.new(f))
      parser.parse File.open('/tmp/osm-nodes.xml', 'r')
      f.close

      # Do the arangoimport magic here ... We do this manually for now

      puts '[Extract Nodes] Deleting the temporary files!'

      File.delete('/tmp/osm-nodes.xml')
      puts '[Extract Nodes] done!'
    end

    def extract_streets
      puts "[Extract Streets] Osmosis is running to extract the streets"
      `osmosis --read-xml file="#{filename}" --tag-filter reject-nodes --way-key keyList=highway --tag-filter accept-ways name="*" --tag-filter reject-relations --write-xml /tmp/osm-streets.xml`
    end

    def extract_house_numbers
      puts "[Extract House Numbers] Osmosis is running to extract the house number points"
      `osmosis --read-xml file="#{@filename}" --tag-filter accept-nodes addr:housenumber="*" --tag-filter accept-relations addr:housenumber="*" --tag-filter accept-ways addr:housenumber="*" --write-xml /tmp/osm-house-numbers.xml`
    end

    def extract_borders
      puts "[Extract Temporary Borders] Osmosis is running to extract all the borders in the file"
      `osmosis --read-xml file="#{@filename}" --tag-filter reject-nodes --tag-filter accept-relations boundary=administrative --tag-filter accept-ways boundary=administrative --write-xml /tmp/osm-borders.xml`
    end

    def extract_states
      puts "[Extract States] Osmosis is running to extract the states from the temporary borders file"
      `osmosis --read-xml file=/tmp/osm-borders.xml --tag-filter reject-nodes --tag-filter accept-relations admin_level=4 --tag-filter accept-ways admin_level=4 --write-xml /tmp/osm-states.xml`

      puts "[Extract States] Osmosis is done ... Now we parse the XML"

    end

    def extract_cities
      puts "[Extract States] Osmosis is running to extract the cities from the temporary borders file"
      `osmosis --read-xml file=/tmp/osm-borders.xml --tag-filter reject-nodes --tag-filter accept-relations admin_level=8 --tag-filter accept-ways admin_level=8 --write-xml /tmp/osm-cities.xml`
    end

    def extract_zip_codes
      # Bodo Magic
    end

    private
    def arango_connection
      if @arango_host
        @arango ||= ::Ashikawa::Core::Database.new @arango_host
      else
        nil
      end
    end
  end
end