module HappyImporter
  module Document
    class OsmBordersDocument < Nokogiri::XML::SAX::Document

      def initialize
        @relations = {}
        @ways = {}
        @current_node = nil
        @current_type = nil
      end

      def start_element name, attrs = []
        attributes = Hash[attrs]
        case name
          when 'way'
            @current_type = :way
            @current_node = {}
            @ways[attributes["id"]] = @current_node
          when 'nd'
            if @current_type == :way
              @current_node[:points] = [] if @current_node[:points].nil?
              @current_node[:points] << attributes["ref"]
            end
          when 'relation'
            @current_type = :relation
            @current_node = {}
            @relations[attributes["id"]] = @current_node
          when 'member'
            if @current_type == :relation && attributes["type"] == "way" && attributes["role"] == "outer"
              @current_node[:ways] = [] if @current_node[:ways].nil?
              @current_node[:ways] << attributes["ref"]
            end
          when 'tag'
            if @current_type == :relation
              @current_node[:tags] = {} if @current_node[:tags].nil?
              @current_node[:tags][attributes["k"]] = attributes["v"]
            end
        end
      end

      def end_element name
        #puts "#{name} ended"
      end

      def ways
        @ways
      end

      def relations
        @relations
      end
    end
  end
end
