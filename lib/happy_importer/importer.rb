module HappyImporter
  class Importer

    def initialize(filename)
      @filename = filename
    end

    def self.check_osmosis
      if `which osmosis`.empty?
        puts "You need to install osmosis. Use homebrew, apt or what-ever you want..."
      end
    end

    # This function extracts the nodes from the OSM XML file and stores them in the sqlite database
    def extract_nodes
      setup_nodes_db

      # Shell out to osmosis to extract the nodes and store them in the sqlite
      puts "[Extract Nodes] Osmosis is running to extract the nodes"
      `osmosis --read-xml file="#{@filename}" --tag-filter reject-ways --tag-filter reject-relations --write-xml /tmp/osm-nodes.xml`

      puts "[Extract Nodes] Now we are parsing the XML and putting everything in the sqlite db ... Please stand by (this might take a while)"
      parser = ::Nokogiri::XML::SAX::Parser.new(Document::NodeDocument.new(sqlite_connection))
      parser.parse File.open('/tmp/osm-nodes.xml', 'r')
      puts '[Extract Nodes] done!'
    end

    def extract_streets
      # osmosis --read-xml file="koeln-regbez.osm" --tag-filter reject-nodes --way-key keyList=highway --tag-filter accept-ways name="*" --tag-filter reject-relations --write-xml koeln-strassen.osm
    end

    def extract_house_numbers
      # osmosis --read-xml file="koeln-regbez.osm" --tag-filter accept-nodes addr:housenumber="*" --tag-filter accept-relations addr:housenumber="*" --tag-filter accept-ways addr:housenumber="*" --write-xml koeln-hausnummern.osm
    end

    def extract_borders
      # osmosis --read-xml file="koeln-regbez.osm" --tag-filter reject-nodes --tag-filter accept-relations boundary=administrative --tag-filter accept-ways boundary=administrative --write-xml koeln-grenzen.osm
    end

    def extract_states
      # osmosis --read-xml file=koeln-grenzen.osm --tag-filter reject-nodes --tag-filter accept-relations admin_level=4 --tag-filter accept-ways admin_level=4 --write-xml koeln-bundesland.osm
    end

    def extract_cities
      # osmosis --read-xml file=koeln-grenzen.osm --tag-filter reject-nodes --tag-filter accept-relations admin_level=8 --tag-filter accept-ways admin_level=8 --write-xml koeln-staedte.osm
    end

    def extract_zip_codes
      # Bodo Magic
    end

    private
    def sqlite_connection
      @db ||= ::SQLite3::Database.new('/tmp/nodes.sqlite3')
    end

    def setup_nodes_db
      sqlite_connection.execute "CREATE TABLE IF NOT EXISTS osm_nodes(id INTEGER PRIMARY KEY, lat DOUBLE, lon DOUBLE)"
      sqlite_connection.execute "DELETE FROM osm_nodes"
    end
  end
end