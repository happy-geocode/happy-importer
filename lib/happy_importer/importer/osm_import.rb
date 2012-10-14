# encoding: utf-8
module HappyImporter
  module Importer
    class OsmImport

      # Don't change the order of this,
      # it is important. It is the order
      # of the "REGIONALSCHLUESSEL"
      # See this for details:
      # http://de.wikipedia.org/wiki/Amtlicher_Gemeindeschl%C3%BCssel#L.C3.A4nder_der_Bundesrepublik_Deutschland
      BUNDESLAENDER = [
        "Schleswig-Holstein",
        "Hamburg",
        "Niedersachsen",
        "Bremen",
        "Nordrhein-Westfalen",
        "Hessen",
        "Rheinland-Pfalz",
        "Baden-Württemberg",
        "Bayern",
        "Saarland",
        "Berlin",
        "Brandenburg",
        "Mecklenburg-Vorpommern",
        "Sachsen",
        "Sachsen-Anhalt",
        "Thüringen"
      ]

      BUNDESLAND_REFS = [
        "51529",
        "62782",
        "62771",
        "62718",
        "62761",
        "62650",
        "62341",
        "62611",
        "2145268",
        "62372",
        "62422",
        "62504",
        "28322",
        "62467",
        "62607",
        "62366"
      ]

      def initialize(filename, osm_type, check_for_city = false)
        @filename = filename
        @osm_type = osm_type
        @check_for_city = check_for_city
      end

      def extract_osm(arango)
        doc = Document::OsmBordersDocument.new
        parser = ::Nokogiri::XML::SAX::Parser.new(doc)
        parser.parse File.open(@filename, 'r')
        File.open("/tmp/import-#{@osm_type}#{@check_for_city ? "_big" : ""}.json", "w") do |output|
          doc.relations.each do |key, relation|
            name = name_from_relation(relation[:tags])
            poly = Polygon.new
            unless relation[:ways].nil?
              relation[:ways].each do |way|
                poly.points += points_from_way doc.ways[way], arango
              end
            end

            if @osm_type == "city"
              center = poly.centroid
              state_name = state_for_regionalschluessel(relation[:tags]["de:regionalschluessel"])
              if !state_name.nil? && !poly.points.empty? && (!@check_for_city || relation[:tags]["de:place"] == "city")
                entry = {
                  id: key,
                  name: name,
                  name_normalized: name.normalize_for_parsec,
                  country_ref: nil,
                  country_name: "DE",
                  state_name: state_name,
                  state_ref: BUNDESLAND_REFS[BUNDESLAENDER.index(state_name)],
                  center: {
                    lat: center.lat,
                    lon: center.lon
                  },
                  radius: poly.radius
                }
                output.puts(entry.to_json)
              end
            elsif @osm_type == "state" && BUNDESLAENDER.include?(name) && !poly.points.empty?
              center = poly.centroid
              entry = {
                id: key,
                name: name,
                name_normalized: name.normalize_for_parsec,
                country_ref: nil,
                country_name: "DE",
                center: {
                  lat: center.lat,
                  lon: center.lon
                },
                radius: poly.radius
              }
              output.puts(entry.to_json)
            end
          end
        end
      end

      def name_from_relation(tags)
        tags["nat_name:de"] || tags["name:de"] || tags["nat_name"] || tags["name"]
      end

      def points_from_way(way, arango)
        return [] if way.nil?
        points = []

        if arango.nil?
          # Dummy Data
          points << OpenStruct.new(lat: 0, lon: 0)
          points << OpenStruct.new(lat: 0, lon: 1)
          points << OpenStruct.new(lat: 1, lon: 1)
        else
          # Get the lat/lon from the arango db
          result = @arango.query("FOR i IN locations FILTER i.osm_id IN [#{way[:points].join(", ")}] RETURN i")
          result.each do |line|
            points << OpenStruct.new(lat: line["lat"], lon: line["lon"])
          end
        end

        points
      end

      def state_for_regionalschluessel(schluessel)
        return nil if schluessel.nil?
        BUNDESLAENDER[schluessel[0..1].to_i - 1]
      end
    end
  end
end
