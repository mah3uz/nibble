module Nibble
  class Blueprint
    Section = Data.define(:display, :instructions, :collapsible, :collapsed, :fields)
    Tab = Data.define(:handle, :display, :sections)

    attr_reader :item, :tabs

    def self.for(item, schema: Nibble.schema) = schema.built_blueprint(item)

    def initialize(item, schema:)
      @item = item
      @schema = schema
      @tabs = build_tabs
      check_duplicates
    end

    def handle = item.handle
    def title = item["title"]
    def hidden? = item["hide"] == true
    def order = item["order"]
    def template = item["template"]

    def fields
      @fields ||= Fields.new(nil, schema: @schema, source: item.path, fields: tabs.flat_map(&:sections).map(&:fields).map(&:all).reduce({}, :merge))
    end

    def field(handle) = fields.get(handle)

    def to_publish_h
      {
        "handle" => handle,
        "title" => title,
        "tabs" => tabs.map do |tab|
          { "handle" => tab.handle, "display" => tab.display,
            "sections" => tab.sections.map do |section|
              { "display" => section.display, "instructions" => section.instructions, "collapsible" => section.collapsible,
                "collapsed" => section.collapsed, "fields" => section.fields.to_publish_a }
            end }
        end
      }
    end

    private

    def build_tabs
      item["tabs"].map do |tab_handle, tab|
        tab = tab.to_h
        sections = Array(tab["sections"]).each_with_index.map do |section, index|
          section = section.to_h
          key = "tabs.#{tab_handle}.sections.#{index}.fields"
          Section.new(display: section["display"], instructions: section["instructions"], collapsible: section["collapsible"] == true,
            collapsed: section["collapsed"] == true, fields: Fields.new(section["fields"], schema: @schema, source: item.path, key:))
        end
        Tab.new(handle: tab_handle, display: tab["display"] || tab_handle.humanize, sections:)
      end
    end

    def check_duplicates
      seen = {}
      tabs.each do |tab|
        tab.sections.each_with_index do |section, index|
          section.fields.handles.each do |handle|
            if seen[handle]
              raise SchemaError.new(file: item.path, key: "tabs.#{tab.handle}.sections.#{index}", reason: "field '#{handle}' is already defined in #{seen[handle]}")
            end

            seen[handle] = "tabs.#{tab.handle}"
          end
        end
      end
    end
  end
end
