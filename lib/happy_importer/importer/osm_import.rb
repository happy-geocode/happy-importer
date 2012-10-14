# encoding: utf-8
module HappyImporter
  module Importer
    class OsmImport

      # Don't change the order of this,
      # it is important. It is the order
      # of the "REGIONALSCHLUESSEL"
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

      def initialize(filename, osm_type)
        @filename = filename
        @osm_type = osm_type
      end

      # Fragen:
      # 2. Leider gibt es 44 Länder in der Datei, ohne Land-Bezeichnung :(
      def extract_osm
        doc = Document::OsmBordersDocument.new
        parser = ::Nokogiri::XML::SAX::Parser.new(doc)
        parser.parse File.open(@filename, 'r')
        doc.relations.values.each do |relation|
          name = name_from_relation(relation[:tags])
          #p name
          poly = Polygon.new
          unless relation[:ways].nil?
            relation[:ways].each do |way|
              poly.points += points_from_way doc.ways[way]
            end
          end

          if @osm_type == "city"
            entry = {
              name: name,
              country_ref: nil,
              country_name: "DE",
              state_name: state_for_regionalschluessel(relation[:tags]["de:regionalschluessel"]),
              state_ref: nil,
              center: {
                lat: nil,
                long: nil
              },
              radius: nil
            }
            p entry.inspect unless entry[:state_name].nil?
          elsif @osm_type == "state" && BUNDESLAENDER.include?(name)
            entry = {
              name: name,
              country_ref: nil,
              country_name: "DE",
              center: {
                lat: nil,
                long: nil
              },
              radius: nil
            }
            p entry.inspect
          end
        end
        #p doc.relations.values.count
      end

      def name_from_relation(tags)
        tags["nat_name:de"] || tags["name:de"] || tags["nat_name"] || tags["name"]
      end

      def points_from_way(way)
        return [] if way.nil?
        []
      end

      def state_for_regionalschluessel(schluessel)
        return nil if schluessel.nil?
        BUNDESLAENDER[schluessel[0..1].to_i - 1]
      end
    end
  end
end
