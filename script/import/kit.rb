# frozen_string_literal: true

# What a theme's script/import.rb builds the site's content model from:
# field definitions inferred from the content they'll hold, and upserts for
# block types, collections, globals, pages and entries, each matched by its
# slug or path so a second run updates rather than duplicates. Rails is
# loaded (bin/rails runner), so the CMS's models are at hand.
module Oldmill
  module Import
    module_function

    # Fields by these names hold an asset's id.
    IMAGE_NAMES = /(\A|_)(image|photo|logo|icon_image|screenshot|avatar|thumbnail)(_id)?\z/

    # Field definitions for sample hashes (the data of every block of a type,
    # say): every key any of them has, typed by what it holds. `overrides`, by
    # name ("a.b" for a nested one), wins: {"tone" => {"type" => "select", "options" => %w[light dark]}}.
    def fields_for(samples, overrides = {}, prefix = nil)
      samples = Array(samples).grep(Hash)
      samples.flat_map(&:keys).uniq.map do |key|
        path = [prefix, key].compact.join(".")
        field = {"name" => key.to_s, "label" => key.to_s.humanize}.merge(type_for(samples.map { it[key] }, overrides, path))
        field["type"] = "asset" if %w[integer string].include?(field["type"]) && key.to_s.match?(IMAGE_NAMES)
        field.merge(overrides[path].to_h.except("of"))
      end
    end

    # A field's type from its values. A list is a list even when every sample
    # is empty, or some are "" (a source's "none"): typed as a string, the
    # CMS would store an empty one as "".
    def type_for(values, overrides = {}, path = nil)
      present = values.compact
      lists = present.grep(Array)
      return list_type(lists, overrides, path) if lists.any? && (present - [""]).all?(Array)

      sample = present.find { it != "" }
      case sample
      when nil then {"type" => "string"}
      when true, false then {"type" => "boolean"}
      when Integer then present.all?(Integer) ? {"type" => "integer"} : {"type" => "string"}
      when Float then {"type" => "string"}
      when Hash
        return {"type" => "link"} if sample.keys.map(&:to_s).sort == %w[kind value]

        {"type" => "group", "of" => fields_for(present, overrides, path)}
      when String
        long = present.any? { it.to_s.length > 90 || it.to_s.include?("\n") }
        markdown = present.any? { it.to_s.match?(/(^#+ |\*\*|\]\(|^\s*[-*] )/) }
        {"type" => markdown ? "markdown" : (long ? "text" : "string")}
      else {"type" => "string"}
      end
    end

    def list_type(lists, overrides, path)
      items = lists.flatten(1)
      return {"type" => "string_list"} if items.empty? || items.none?(Hash)

      {"type" => "repeater", "of" => fields_for(items, overrides, path)}
    end

    # Data held to its fields' types: a number in a text field as text, a
    # list field never "".
    def conform(data, fields)
      return data unless data.is_a?(Hash)

      by_name = Array(fields).index_by { it["name"] }
      data.to_h do |key, value|
        field = by_name[key.to_s]
        value = case field&.dig("type")
        when "string", "text", "markdown" then value.is_a?(Numeric) ? value.to_s : value
        when "string_list", "record_refs" then Array(value.presence)
        when "group" then conform(value, field["of"])
        when "repeater" then Array(value.presence).map { conform(it, field["of"]) }
        else value
        end
        [key.to_s, value]
      end
    end

    # A link field's value: a URL, an anchor, or a page by its path.
    def link(value) = value.to_s.start_with?("/") && !value.include?("#") ? {"kind" => "page", "value" => value.delete_prefix("/").presence || "home"} : {"kind" => "url", "value" => value.to_s}

    # A block for a page's blocks.
    def block(type, data) = {"type" => type.to_s, "version" => 1, "data" => data}

    # A block type from the blocks that use it: its fields inferred from their
    # data, its defaults the first one's.
    def block_type(slug, label:, blocks:, category: "Sections", description: "", icon: "LayoutTemplate", overrides: {})
      samples = blocks.map { it["data"] }
      fields = fields_for(samples, overrides)
      BlockType.find_or_initialize_by(slug: slug.to_s).tap do |type|
        type.update!(label:, category:, description:, icon:, fields:, defaults: conform(samples.first.to_h, fields))
      end
    end

    # A collection, its fields inferred from its entries' frontmatter.
    def collection(slug, name:, entries:, overrides: {}, **attributes)
      fields = fields_for(entries.map { it[:frontmatter] || it["frontmatter"] }, overrides)
      Collection.find_or_initialize_by(slug: slug.to_s).tap do |collection|
        collection.update!(name:, schema: {"fields" => fields}, **attributes)
      end
    end

    # An entry, published unless it says otherwise, held to its collection's fields.
    def entry(collection, slug:, title:, frontmatter: {}, status: "published", **attributes)
      collection.entries.find_or_initialize_by(slug: slug.to_s).tap do |entry|
        entry.update!(title:, status:, frontmatter: conform(frontmatter, collection.fields),
          published_at: entry.published_at || attributes.delete(:published_at) || Time.current, **attributes)
      end
    end

    # A page at a path ("home" is /), its blocks held to their types' fields.
    def page(path, title:, blocks:, status: "published", **attributes)
      types = BlockType.where(slug: blocks.map { it["type"] }).index_by(&:slug)
      blocks = blocks.map { it.merge("data" => conform(it["data"], types[it["type"]]&.fields)) }
      Page.find_or_initialize_by(path: path.to_s).tap do |page|
        page.update!(slug: path.to_s.split("/").last, title:, blocks:, status:, locale: page.locale || "en", **attributes)
      end
    end

    # A global's data (nav, footer, or one of the theme's own).
    def global(slug, data, name: slug.to_s.humanize, fields: nil)
      fields ||= fields_for([data])
      Global.find_or_initialize_by(slug: slug.to_s).tap do |global|
        global.update!(name:, schema: {"fields" => fields}, data: conform(data, fields))
      end
    end
  end
end
