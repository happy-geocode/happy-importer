# encoding: utf-8

require 'JSON'

module HappyImporter
  module Importer
    class OsmosisImport

      def initialize(filename)
        @filename = filename
        @nodes = nil

        # Connection to ArangoDB through Ashikawa-Core
        @arango = Ashikawa::Core::Database.new("http://localhost:8529")
      end

      def self.check_osmosis
        if `which osmosis`.empty?
          puts "You need to install osmosis. Use homebrew, apt or what-ever you want..."
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
        `arangoimp --collection locations --create-collection true --connect-timeout 60 --log.level debug --max-upload-size 1000000 --type csv --separator ';' /tmp/temp-nodes.csv`

        puts "#{Time.new} [Extract Nodes] We are done ... Now we can use arango to get the nodes"
      end

      def extract_streets
         if File.exist?('/tmp/osm-streets.xml')
          puts "#{Time.new} [Extract Streets] We already have the streets ... Skipping"
         else
           puts "#{Time.new} [Extract Streets] Osmosis is running to extract the streets"
           `osmosis --read-xml file="#{@filename}" --tag-filter reject-nodes --way-key keyList=highway --tag-filter accept-ways name="*" --tag-filter reject-relations --write-xml /tmp/osm-streets.xml`
         end

        puts "#{Time.new} [Extract Streets] The parser is starting to parse the streets"
        doc = Document::OsmStreetsDocument.new(@mysql)
        parser = ::Nokogiri::XML::SAX::Parser.new(doc)
        #parser.parse File.open('/tmp/osm/koeln-strassen.osm') # TODO: Ue the right temp file here

        parser.parse File.open('/tmp/osm-streets.xml')
        puts "#{Time.new} [Extract Streets] The parser is done with the streets osm ... No we have to connect the streets that belong together"

        # Let's iterate over the node<->street associations
        # When we find a node that belongs to more than one street and the streets have the same ids, let's connect them

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

        puts "#{Time.new} [Extract Streets] Done with the connection ... Saving to /tmp/osm-streets.json"
        File.open('/tmp/osm-streets.json','w') do |f|
          doc.streets.values.each do |street|
            f.puts street.to_json
          end
        end
        puts "#{Time.new} [Extract Streets] Done!"
      end

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

      def extract_borders
        if File.exist?('/tmp/osm-borders.xml')
          puts "#{Time.new} [Extract Temporary Borders] We already have the borders ... Skipping"
        else
          puts "#{Time.new} [Extract Temporary Borders] Osmosis is running to extract all the borders in the file"
          `osmosis --read-xml file="#{@filename}" --tag-filter reject-nodes --tag-filter accept-relations boundary=administrative --tag-filter accept-ways boundary=administrative --write-xml /tmp/osm-borders.xml`
          puts "#{Time.new} [Extract Temporary Borders] Done!"
        end
      end

      def extract_states
        if File.exist?('/tmp/osm-states.xml')
          puts "#{Time.new} [Extract States] We already have the state borders ... Skipping"
        else
          puts "#{Time.new} [Extract States] Extracting the state borders from the temporary borders file"
          `osmosis --read-xml file=/tmp/osm-borders.xml --tag-filter reject-nodes --tag-filter accept-relations admin_level=4 --tag-filter accept-ways admin_level=4 --write-xml /tmp/osm-states.xml`
          puts "#{Time.new} [Extract States] Osmosis is done ... Now we parse the XML"
        end
        import = HappyImporter::Importer::OsmImport.new("/tmp/osm-states.xml", "state")
        import.extract_osm(@arango)
        puts "#{Time.new} [Extract States] Done!"
      end

      def extract_cities
        if File.exist?('/tmp/osm-cities.xml')
          puts "#{Time.new} [Extract Cities] We already have the city borders ... Skipping"
        else
          puts "#{Time.new} [Extract Cities] Osmosis is running to extract the city borders from the temporary borders file"
          `osmosis --read-xml file=/tmp/osm-borders.xml --tag-filter reject-nodes --tag-filter accept-relations admin_level=8 --tag-filter accept-ways admin_level=8 --write-xml /tmp/osm-cities.xml`
          `osmosis --read-xml file=/tmp/osm-borders.xml --tag-filter reject-nodes --tag-filter accept-relations admin_level=6 --tag-filter accept-ways admin_level=6 --write-xml /tmp/osm-big-cities.xml`
        end
        import = HappyImporter::Importer::OsmImport.new("/tmp/osm-cities.xml", "city")
        import.extract_osm(@arango)
        import = HappyImporter::Importer::OsmImport.new("/tmp/osm-big-cities.xml", "city", true)
        import.extract_osm(@arango)
        puts "#{Time.new} [Extract Cities] Done!"
      end

      # Cleanup all the shit
      def cleanup
        files = %w{/tmp/osm-nodes.xml /tmp/osm-streets.xml /tmp/osm-house-numbers.xml /tmp/osm-borders.xml /tmp/osm-states.xml /tmp/osm-cities.xml /tmp/temp-nodes.csv}

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
