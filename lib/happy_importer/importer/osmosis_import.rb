# encoding: utf-8

require 'JSON'

module HappyImporter
  module Importer
    # This  class is the basis for all data importers that use OSM data (or an Osmosis export) as the base
    class OsmosisImport

      def initialize(filename)
        @filename = filename
        @nodes = nil

        # Connection to ArangoDB through Ashikawa-Core
        @arango = Ashikawa::Core::Database.new("http://localhost:8529")
      end

      # Check if osmosis is available on the system
      def self.osmosis_available?
        if `which osmosis`.empty?
          false
        else
          true
        end
      end

      # This function extracts the nodes from the OSM XML file and stores them away temporarily ...
      # We need the nodes to get the geocordinates of almost everything. Since Osmosis doesn't offer a way to
      # filter out all unneccessary nodes we have to go with all of them and just select what we need.
      #
      # This is sort of ugly ... But only the way how to transpose this...
      def extract_nodes
        # Shell out to osmosis to extract the nodes
        if File.exist?('/tmp/osm-nodes.xml')
          puts "#{Time.new} [Extract Nodes] We already have the node extraction ... Skipping"
        else
          puts "#{Time.new} [Extract Nodes] Osmosis is running to extract the nodes"
          `osmosis --read-xml file="#{@filename}" --tag-filter reject-ways --tag-filter reject-relations --write-xml /tmp/osm-nodes.xml`
        end

        # For a small amount of data, we can store everything in memory and just access a shared hash.
        # When we go any larger than a city OSM file, it no longer works on a standard machine, so we have
        # go other routes

        # puts "#{Time.new} [Extract Nodes] Now we are parsing the XML and putting everything into memory"
        # doc = Document::NodeDocument.new
        # parser = ::Nokogiri::XML::SAX::Parser.new doc
        # parser.parse File.open('/tmp/osm-nodes.xml', 'r')
        # @nodes = doc.nodes

        # ArangoDB will introduce Batch Insert Queries with version 1.1.0
        # http://www.arangodb.org/2012/10/07/feature-preview-batch-request-api-in-arangodb-1-1

        # Until then we have to rely on a CSV export and arangoimp to import the data

        # Store everything into a CSV file
        puts "#{Time.new} [Extract Nodes] Now we are parsing the XML and putting everything into a CSV file ... Please stand by (this might take a while)"
        f = File.open('/tmp/temp-nodes.csv', 'w')
        parser = ::Nokogiri::XML::SAX::Parser.new(Document::NodeDocumentCsv.new(f))
        parser.parse File.open('/tmp/osm-nodes.xml', 'r')
        f.close

        puts "#{Time.new} [Extract Nodes] Importing all the stuff into the ArangoDB"
        # Drop the collection
        `echo 'db._drop("locations")'|arangosh`
        # We need to increase the journal size (standard ~30mb) otherwise the machine will break when importing Germany
        `echo 'db._create("locations", { journalSize: 200000000 })'|arangosh`
        # CSV Import the data
        `arangoimp --collection locations --create-collection true --connect-timeout 60 --log.level debug --max-upload-size 1000000 --type csv --separator ';' /tmp/temp-nodes.csv`

        puts "#{Time.new} [Extract Nodes] We are done ... Now we can use arango to get the nodes"
      end


      # This function extracts all streets (highway=*) from the OSM file and puts them together in a datastructure
      # Since one street can be heavily divided in OpenStreetMap we put references to all other streets in the datastructure
      # that share the same name and at least one point. We use Ashikawa-Core to find all nodes that belong to a street so that
      # we can embed all points of a street into the datastructure, HOORAY for NoSQL document stores!
      def extract_streets
        # Shell out to osmosis to extract streets
        if File.exist?('/tmp/osm-streets.xml')
          puts "#{Time.new} [Extract Streets] We already have the streets ... Skipping"
        else
          puts "#{Time.new} [Extract Streets] Osmosis is running to extract the streets"
          `osmosis --read-xml file="#{@filename}" --tag-filter reject-nodes --way-key keyList=highway --tag-filter accept-ways name="*" --tag-filter reject-relations --write-xml /tmp/osm-streets.xml`
        end

        # Use a Nokogiri SAX Parser to parse the streets file that was generated by Osmosis
        puts "#{Time.new} [Extract Streets] The parser is starting to parse the streets"

        doc = Document::OsmStreetsDocument.new(@arango)
        parser = ::Nokogiri::XML::SAX::Parser.new(doc)

        parser.parse File.open('/tmp/osm-streets.xml')
        puts "#{Time.new} [Extract Streets] The parser is done with the streets osm ... No we have to connect the streets that belong together"

        # Let's iterate over the node<->street associations
        # When we find a node that belongs to more than one street and the streets share at least one node-id, let's reference them to each other

        doc.nodes.each do |key, array|
          if array.size > 1
            array.each do |streetA|
              array.each do |streetB|
                if streetA != streetB
                  doc.streets[streetA][:other_part_refs] << streetB if doc.streets[streetA][:name] == doc.streets[streetB][:name]
                  doc.streets[streetA][:other_part_refs].uniq!
                end
              end
            end
          end
        end

        # We have a hash in the form { id => {}, id => {}, ... } ... arangoimp needs one json object per line, let's transpose the data
        puts "#{Time.new} [Extract Streets] Done with the connection ... Saving to /tmp/import-streets.json"
        File.open('/tmp/import-streets.json','w') do |f|
          doc.streets.values.each do |street|
            f.puts street.to_json
          end
        end

        # We also have a hash of street points ... These are the connections between streets and points
        # We have extracted them from the streets so we can put a geo index on them to make the searches uber-fast
        puts "#{Time.new} [Extract Streets] Put all the streetpoints in a file ... Saving to /tmp/import-street_points.json"
        File.open('/tmp/import-street_points.json','w') do |f|
          doc.street_points.each do |street_point|
            f.puts street_point.to_json
          end
        end


        puts "#{Time.new} [Extract Streets] Done!"
      end

      # The house numbers in OSM aren't that great right now ... There is finally a standard, but in Germany a lot of them are missing.
      # Since we don't have a standard how the numbers could be interpolated (shame on you, government), there is no good way to guess the numbers.
      #
      # We have a good idea how to use the addresses of Points Of Interest (POIs) to match the location to the street to which they belong. But seriously,
      # parsing the whole dataset and everything in 48hrs is hard enough... We will continue to work on this since we really want to have this, at least for Cologne.

      # def extract_house_numbers
      #   if File.exist?('/tmp/osm-house-numbers.xml')
      #     puts "#{Time.new} [Extract House Numbers] We already have the house numbers ... Skipping"
      #   else
      #     puts "#{Time.new} [Extract House Numbers] Osmosis is running to extract the house number points"

      #     # Do not use nodes ... This will speed things up ... We just use the official places marked as house numbers in OpenStreetMap
      #     `osmosis --read-xml file="#{@filename}" --tag-filter reject-nodes --tag-filter accept-relations addr:housenumber="*" --tag-filter accept-ways addr:housenumber="*" --write-xml /tmp/osm-house-numbers.xml`
      #     #`osmosis --read-xml file="#{@filename}" --tag-filter accept-nodes addr:housenumber="*" --tag-filter accept-relations addr:housenumber="*" --tag-filter accept-ways addr:housenumber="*" --write-xml /tmp/osm-house-numbers.xml`
      #   end
      # end

      # This function extracts all ways and relations from the OSM file that are tagged as borders. Since osmosis doesn't give a good way to filter by multiple
      # tags we prepare a file here and use this for cities and states
      def extract_borders
        # Shell out to osmosis to extract borders
        if File.exist?('/tmp/osm-borders.xml')
          puts "#{Time.new} [Extract Temporary Borders] We already have the borders ... Skipping"
        else
          puts "#{Time.new} [Extract Temporary Borders] Osmosis is running to extract all the borders in the file"
          `osmosis --read-xml file="#{@filename}" --tag-filter reject-nodes --tag-filter accept-relations boundary=administrative --tag-filter accept-ways boundary=administrative --write-xml /tmp/osm-borders.xml`
          puts "#{Time.new} [Extract Temporary Borders] Done!"
        end
      end

      # This function extracts states from the OSM file. The German states ("Bundesländer") are surrounded by an admin_level=4 boundary. This might be different
      # In other states this might differ
      # See: http://wiki.openstreetmap.org/wiki/Tag:boundary%3Dadministrative
      def extract_states
        # Shell out to osmosis to extract states
        if File.exist?('/tmp/osm-states.xml')
          puts "#{Time.new} [Extract States] We already have the state borders ... Skipping"
        else
          puts "#{Time.new} [Extract States] Extracting the state borders from the temporary borders file"
          `osmosis --read-xml file=/tmp/osm-borders.xml --tag-filter reject-nodes --tag-filter accept-relations admin_level=4 --tag-filter accept-ways admin_level=4 --write-xml /tmp/osm-states.xml`
          puts "#{Time.new} [Extract States] Osmosis is done ... Now we parse the XML"
        end

        # Parse the file and connect it with the nodes so we have a polygon that describes the state boundaries
        #
        # Oh wait. We ware using ArangoDB 1.0.1 and they do not support polygons right now, so what do we do? We calculate the centroid
        # of the polygon and the radius to its furthest point. So we have a circle that we can use to approximate the state... We know,
        # it's not the best solution but it's a good-enough approximation.
        import = HappyImporter::Importer::OsmImport.new("/tmp/osm-states.xml", "state")
        import.extract_osm(@arango)
        puts "#{Time.new} [Extract States] Done!"
      end

      # Yeah ... This gave us a great headache ... The official documentation for borders (see above) said that all cities are admin_level=8
      # WROOOOONG! The 22 biggest cities were missing after the import ... Some fiddling around with the original data showed us:
      # When the city is a district itself (admin_level=6) there is no special city border. Hence we are importing the data twice ... This works
      def extract_cities
        # Shell out to osmosis to extract cities
        if File.exist?('/tmp/osm-cities.xml')
          puts "#{Time.new} [Extract Cities] We already have the city borders ... Skipping"
        else
          puts "#{Time.new} [Extract Cities] Osmosis is running to extract the city borders from the temporary borders file"
          `osmosis --read-xml file=/tmp/osm-borders.xml --tag-filter reject-nodes --tag-filter accept-relations admin_level=8 --tag-filter accept-ways admin_level=8 --write-xml /tmp/osm-cities.xml`
        end

        # Shell out to osmosis to extract big cities
        if File.exist?('/tmp/osm-big-cities.xml')
          puts "#{Time.new} [Extract Cities] We already have the city borders ... Skipping"
        else
          puts "#{Time.new} [Extract Cities] Osmosis is running to extract the city borders from the temporary borders file"
          `osmosis --read-xml file=/tmp/osm-borders.xml --tag-filter reject-nodes --tag-filter accept-relations admin_level=6 --tag-filter accept-ways admin_level=6 --write-xml /tmp/osm-big-cities.xml`
        end

        # Parse the file and connect it with the nodes so we have a polygon that describes the city boundaries
        import = HappyImporter::Importer::OsmImport.new("/tmp/osm-cities.xml", "city")
        import.extract_osm(@arango)

        # And the same for the big cities
        import = HappyImporter::Importer::OsmImport.new("/tmp/osm-big-cities.xml", "city", true)
        import.extract_osm(@arango)
        puts "#{Time.new} [Extract Cities] Done!"
      end

      # Cleanup all the shit we left behind
      def cleanup
        files = %w{/tmp/osm-nodes.xml /tmp/osm-streets.xml /tmp/osm-house-numbers.xml /tmp/osm-borders.xml /tmp/osm-states.xml /tmp/osm-cities.xml /tmp/temp-nodes.csv /tmp/osm-big-cities.xml}

        files.each do |file|
          puts "[Cleanup] #{file}"
          File.delete(file) if File.exist? file
        end

        # Drop the temporary ArangoDB collection
        puts "[Cleanup] Dropping the ArangoDB Collection"
        `echo 'db._drop("locations")'|arangosh`
      end
    end
  end
end
