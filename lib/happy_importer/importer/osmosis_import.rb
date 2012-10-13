# encoding: utf-8

require 'JSON'

module HappyImporter
  module Importer
    class OsmosisImporter

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


        puts '[Extract Nodes] done!'
      end

      def extract_streets
        if File.exist?('/tmp/osm-streets.xml')
          puts '[Extract Streets] We already have the streets ... Skipping'
        else
          puts "[Extract Streets] Osmosis is running to extract the streets"
          `osmosis --read-xml file="#{filename}" --tag-filter reject-nodes --way-key keyList=highway --tag-filter accept-ways name="*" --tag-filter reject-relations --write-xml /tmp/osm-streets.xml`
        end
      end

      def extract_house_numbers
        if File.exist?('/tmp/osm-house-numbers.xml')
          puts '[Extract House Numbers] We already have the house numbers ... Skipping'
        else
          puts "[Extract House Numbers] Osmosis is running to extract the house number points"

          # Do not use nodes ... This will speed things up ... We just use the official places marked as house numbers in OpenStreetMap
          `osmosis --read-xml file="#{@filename}" --tag-filter reject-nodes --tag-filter accept-relations addr:housenumber="*" --tag-filter accept-ways addr:housenumber="*" --write-xml /tmp/osm-house-numbers.xml`
          #`osmosis --read-xml file="#{@filename}" --tag-filter accept-nodes addr:housenumber="*" --tag-filter accept-relations addr:housenumber="*" --tag-filter accept-ways addr:housenumber="*" --write-xml /tmp/osm-house-numbers.xml`
        end
      end

      def extract_borders
        if File.exist?('/tmp/osm-borders.xml')
          puts '[Extract Temporary Borders] We already have the borders ... Skipping'
        else
          puts "[Extract Temporary Borders] Osmosis is running to extract all the borders in the file"
          `osmosis --read-xml file="#{@filename}" --tag-filter reject-nodes --tag-filter accept-relations boundary=administrative --tag-filter accept-ways boundary=administrative --write-xml /tmp/osm-borders.xml`
        end
      end

      def extract_states
        if File.exist?('/tmp/osm-states.xml')
          puts '[Extract States] We already have the state borders ... Skipping'
        else
          puts '[Extract States] Exrtracting the state borders from the temporary borders file"'
          `osmosis --read-xml file=/tmp/osm-borders.xml --tag-filter reject-nodes --tag-filter accept-relations admin_level=4 --tag-filter accept-ways admin_level=4 --write-xml /tmp/osm-states.xml`
          puts '[Extract States] Osmosis is done ... Now we parse the XML'
        end
      end

      def extract_cities
        if File.exist?('/tmp/osm-cities.xml')
          puts '[Extract Cities] We already have the city borders ... Skipping'
        else
          puts "[Extract Cities] Osmosis is running to extract the city borders from the temporary borders file"
          `osmosis --read-xml file=/tmp/osm-borders.xml --tag-filter reject-nodes --tag-filter accept-relations admin_level=8 --tag-filter accept-ways admin_level=8 --write-xml /tmp/osm-cities.xml`
        end
      end

      # Cleanup all the shit
      def cleanup
        files = %w{/tmp/osm-nodes.xml /tmp/osm-streets.xml /tmp/osm-house-numbers.xml /tmp/osm-borders.xml /tmp/osm-states.xml /tmp/osm-cities.xml /tmp/temp-nodes.csv}

        files.each do |file|
          puts "[Cleanup] #{file}"
          File.delete(file) if File.exist? file
        end
      end
    end
  end
end
