# frozen_string_literal: true

# The content the theme's spec draws: spec/fixtures/cms/snapshot.json when
# there is one (bin/rails oldmill:snapshot, from the site the theme is for),
# else a fresh site's (the CMS's block types and globals, a home page with
# every block it can hold). Loaded in a before block, as the CMS holds it.
module Oldmill
  module Content
    SNAPSHOT_PATH = Oldmill::Engine.root.join("spec/fixtures/cms/snapshot.json")
    SNAPSHOT = SNAPSHOT_PATH.exist? ? JSON.parse(SNAPSHOT_PATH.read) : nil
    PARTIALS = Oldmill::Engine.root.glob("app/views/website/blocks/_*.html.erb").map { it.basename.to_s[/\A_(\w+)\./, 1] }
    ENTRY_TEMPLATES = Oldmill::Engine.root.glob("app/views/website/entries/*.html.erb").map { it.basename.to_s.delete_suffix(".html.erb") }

    module_function

    def snapshot? = !SNAPSHOT.nil?

    def load!
      snapshot? ? load_snapshot! : load_fresh_site!
    end

    def load_snapshot!
      SNAPSHOT["block_types"].each { BlockType.find_or_initialize_by(slug: it["slug"]).update!(it) }
      collections = SNAPSHOT["collections"].to_h { [it["slug"], Collection.create!(it.except("categories_collection", "tags_collection"))] }
      SNAPSHOT["collections"].each do |collection|
        collections[collection["slug"]].update!(categories_collection: collections[collection["categories_collection"]], tags_collection: collections[collection["tags_collection"]])
      end
      SNAPSHOT["globals"].each { |global| Global.find_or_initialize_by(slug: global["slug"]).update!(global.except("fields").merge("schema" => {"fields" => global["fields"]})) }
      SNAPSHOT["forms"].each { Form.create!(it.merge("status" => "published")) } if defined?(Form)
      SNAPSHOT["pages"].each { |page| Page.find_or_initialize_by(path: page["path"]).update!(page.merge("status" => "published")) }
      SNAPSHOT["entries"].each do |entry|
        collection = collections.fetch(entry["collection"])
        category = entry["category"] && collection.categories_collection.entries.find_by!(slug: entry["category"])
        tags = collection.tags_collection ? collection.tags_collection.entries.where(slug: entry["tags"]).to_a : []
        collection.entries.create!(entry.except("collection", "category", "tags").merge("status" => "published", "category" => category, "tags" => tags))
      end
      Setting.set("general", SNAPSHOT["site"].merge("serving" => "website"))
    end

    def load_fresh_site!
      BlockType::Defaults.install!
      BlockType::Defaults.install!(Oldmill::BLOCK_TYPES)
      SiteBootstrap::STARTER_GLOBALS.each { Global.find_or_initialize_by(slug: it[:slug]).update!(it.slice(:name, :description, :icon, :schema, :data)) }
      # The site's own nav and footer (its "Order Online" link, quick links, socials), which the layout reads.
      Array(SNAPSHOT&.fetch("globals")).select { it["slug"].in?(%w[nav footer]) }.each do |global|
        Global.find_or_initialize_by(slug: global["slug"]).update!(global.except("fields").merge("schema" => {"fields" => global["fields"]}))
      end
      posts = Collection.create!(slug: "posts", name: "Posts", schema: {"fields" => [{"name" => "summary", "label" => "Summary", "type" => "string"}]})
      posts.entries.create!(slug: "hello", title: "Hello", status: "published", locale: "en", published_at: Time.current, body_markdown: "A **first** post.", frontmatter: {"summary" => "The first post."})
      Form.create!(slug: "contact", title: "Contact", status: "published", submit_label: "Send", fields: Form::TEMPLATES.first[:fields]) if defined?(Form)
      # Its images and partners left empty, as an editor could leave them, so not validated.
      Page.new(slug: "home", path: "home", title: "Home", status: "published", locale: "en", blocks: every_block).save!(validate: false)
      Setting.set("general", {"title" => "Acme", "email" => "hello@acme.test", "phone" => "(555) 010-0100", "address_line1" => "1 Main St", "city" => "Springfield", "serving" => "website"})
    end

    # A block of every type the theme draws, from the type's defaults, with
    # whatever a required field the defaults leave out needs.
    def every_block
      BlockType.where(slug: PARTIALS).sort_by { [(it.slug == "hero") ? 0 : 1, it.slug] }.map { {"type" => it.slug, "version" => 1, "data" => filled(it.fields, it.defaults.to_h)} }
    end

    def filled(fields, data)
      Array(fields).each_with_object(data.deep_dup) do |field, out|
        next if out[field["name"]].present? || !field["required"]

        out[field["name"]] = case field["type"]
        when "repeater" then [filled(field["of"], {})]
        when "blocks" then [{"type" => "text", "version" => 1, "data" => {"body" => "Nested text."}}]
        when "select" then Array(field["options"]).first.to_s
        when "link" then {"kind" => "url", "value" => "/"}
        when "record_refs", "string_list" then []
        when "integer" then 1
        when "asset" then nil
        else (field["name"] == "collection_slug") ? "posts" : field["label"].to_s
        end
      end
    end
  end
end
