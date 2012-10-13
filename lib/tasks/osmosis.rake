namespace :osmosis do
  desc 'Imports the nodes from a .osm file and puts them in a SQLite3 database'
  task :nodes do
    file = ENV['IMPORT']

    if !file
      puts "Usage: rake osmosis:nodes IMPORT=<YOUR_OSM_XML_FILE.osm>"
    else
      puts "Extracting nodes from #{file}"
      
    end
  end
end