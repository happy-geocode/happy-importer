module HappyImporter
  module Importer
    class OsmImport

      def initialize(filename, osm_type)
        @filename = filename
        @osm_type = osm_type
      end

      def extract_osm
        p @filename
      end
    end
  end
end
