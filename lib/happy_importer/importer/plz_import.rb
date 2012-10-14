module HappyImporter
  module Importer
    class PlzImport

      def initialize(filename)
        @filename = filename
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
              match[3].scan(/(\d*\.\d*),(\d*\.\d*)/) do |lat, lon|
                polygon.points << OpenStruct.new(lat: lat.to_f, lon: lon.to_f)
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
                  lon: center.lon
                },
                radius: polygon.radius
              }.to_json)
            end
          }
        end
      end

      private

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
end
