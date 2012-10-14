require 'happy_importer'

namespace :import do
  desc 'Imports everything from an OSM file ... yeah!'
  task :osm do
    file = ENV['IMPORT']
    plz  = ENV['PLZ']

    if !HappyImporter::Importer::OsmosisImport.osmosis_available?
      puts "You need to install 'osmosis'. Use homebrew, apt or what-ever you want..."
    elsif !file && !plz && !File.exist?(file) && !File.exist?(plz)
      puts "Usage: rake import:nodes IMPORT=<YOUR_OSM_XML_FILE.osm> PLZ=<PLZ.sql>"
      puts "       the PLZ.sql File can be downloaded here:"
      puts "       http://sourceforge.net/projects/mapbender/files/Data/PLZ/plz.zip/download"
    else
      # Import all the stuff from the OSM file
      import = HappyImporter::Importer::OsmosisImport.new(file)
      import.extract_nodes
      import.extract_borders
      import.extract_streets
      import.extract_states
      import.extract_cities

      # Import the data from the PLZ (ZipCode) file
      plz_import = HappyImporter::Importer::PlzImport.new(plz)
      plz_import.extract_plz_codes

      # Clean Up all the temporary osm.xml files
      import.cleanup
    end
  end
end
