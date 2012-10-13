# encoding: utf-8

require 'JSON'

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
    end

    def extract_cities
      puts "[Extract States] Osmosis is running to extract the cities from the temporary borders file"
      `osmosis --read-xml file=/tmp/osm-borders.xml --tag-filter reject-nodes --tag-filter accept-relations admin_level=8 --tag-filter accept-ways admin_level=8 --write-xml /tmp/osm-cities.xml`
    end

    # Importiert deutsche PLZ in die Zip-Tabelle
    def extract_plz_codes
      File.open("zip.json", "w") do |output|
        File.open(@filename, encoding:"iso-8859-15").each_line{ |s|
          match = s.encode("utf-8").match(/INSERT INTO post_code_areas VALUES \(\d*, *'([^']*)', \d*, '([^']*)', 'SRID=[^;]*;MULTIPOLYGON\(\(\((.*)\)\)\)'\);/m)
          if match
            plz = match[1]
            city = match[2]
            state = bundesland_for_plz(match[1])

            polygon = Polygon.new
            match[3].scan(/(\d*\.\d*),(\d*\.\d*)/) do |lat, long|
              polygon.points << OpenStruct.new(lat: lat.to_f, long: long.to_f)
            end

            center = polygon.centroid
            output.puts({
              zip: plz,
              city: city,
              state_name: state,
              state_ref: nil,
              country: "DE",
              center: {
                lat: center.lat,
                long: center.long
              },
              radius: polygon.radius
            }.to_json)
          end
        }
      end
    end

    private
    def sqlite_connection
      @db ||= ::SQLite3::Database.new('/tmp/nodes.sqlite3')
    end

    def setup_nodes_db
      sqlite_connection.execute "CREATE TABLE IF NOT EXISTS osm_nodes(id INTEGER PRIMARY KEY, lat DOUBLE, lon DOUBLE)"
      sqlite_connection.execute "DELETE FROM osm_nodes"
    end

    def bundesland_for_plz(plz)
      unless @bundesland_file
        @bundesland_file = JSON.parse(File.read(File.expand_path("../german_plz_state.json", __FILE__)))
        @bundesland_file.each do |line|
          line["start"] = line["start"].to_i
          line["end"]   = line["end"].to_i
        end
      end
      plz = plz.to_i
      @bundesland_file.each do |line|
        if line["start"] <= plz && line["end"] >= plz
          return line["name"]
        end
      end
      return nil
    end

  end
end
