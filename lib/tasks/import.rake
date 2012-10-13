require 'happy_importer'

namespace :import do
  desc 'Imports the nodes from a .osm file and puts them in a SQLite3 database'
  task :nodes do
    file = ENV['IMPORT']

    if !file
      puts "Usage: rake import:nodes IMPORT=<YOUR_OSM_XML_FILE.osm>"
    else
      puts "Extracting nodes from #{file}"
      import = HappyImporter::Importer.new(file)
      import.extract_nodes
    end
  end

  desc 'Import the zip codes for germany and their shapes'
  task :plz do
    file = ENV['IMPORT']
    if !file
      puts "Usage: rake import:plz IMPORT=<PLZ.sql>"
      puts "       the PLZ.sql File can be downloaded here:"
      puts "       http://sourceforge.net/projects/mapbender/files/Data/PLZ/plz.zip/download"
    else
      puts "Extracting plz from #{file}"
      import = HappyImporter::Importer.new(file)
      import.extract_plz_codes
    end
  end
end
