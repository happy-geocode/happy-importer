require 'happy_importer'

namespace :import do
  desc 'Imports the nodes from a .osm file and puts them in a DB'
  task :nodes do
    file = ENV['IMPORT']

    if !file
      puts "Usage: rake import:nodes IMPORT=<YOUR_OSM_XML_FILE.osm>"
    else
      puts "Extracting nodes from #{file}"
      import = HappyImporter::Importer::OsmosisImport.new(file)
      import.extract_nodes
    end
  end

  desc 'Imports the streets'
  task :streets do
    file = ENV['IMPORT']

    if !file
      puts "Usage: rake import:streets IMPORT=<YOUR_OSM_XML_FILE.osm>"
    else
      puts "Extracting streets from #{file}"
      import = HappyImporter::Importer::OsmosisImport.new(file)
      import.extract_streets
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
      import = HappyImporter::Importer::PlzImport.new(file)
      import.extract_plz_codes
    end
  end

  desc 'Import the reduces osm sets for city and state'
  task :reduced_osm do
    file = ENV['IMPORT']
    osm_type = ENV['OSM_TYPE']
    if !file || !osm_type
      puts "Usage: rake import:reduced_osm IMPORT=<osm-cities.xml> OSM_TYPE=<state|city>"
    else
      puts "Extracting #{osm_type} from #{file}"
      import = HappyImporter::Importer::OsmImport.new(file, osm_type)
      import.extract_osm
    end
  end
end
