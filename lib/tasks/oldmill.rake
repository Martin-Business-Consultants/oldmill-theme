# frozen_string_literal: true

namespace :oldmill do
  # The theme's spec draws every page from spec/fixtures/cms/snapshot.json.
  # This refreshes it from the content this install holds: pull the live
  # site first (bin/pull oldmill), so a change to the content model there
  # shows up as a failing spec here before it shows up as a broken page.
  # Live content only, and no one's personal details (no submissions).
  desc "Refresh spec/fixtures/cms/snapshot.json from this install's content (after bin/pull)"
  task snapshot: :environment do
    keep = ->(record, *keys) { record.attributes.slice(*keys) }
    collections = Collection.order(:slug).to_a
    by_id = collections.index_by(&:id)
    snapshot = {
      "block_types" => BlockType.order(:slug).map { keep.(it, "slug", "label", "category", "version", "fields", "defaults") },
      "collections" => collections.map do |collection|
        keep.(collection, "slug", "name", "enable_blocks", "schema").merge(
          "categories_collection" => by_id[collection.categories_collection_id]&.slug, "tags_collection" => by_id[collection.tags_collection_id]&.slug)
      end,
      "globals" => Global.order(:slug).map { keep.(it, "slug", "name", "data").merge("fields" => it.fields) },
      "pages" => Page.live.order(:path).map { keep.(it, "path", "slug", "title", "locale", "blocks", "frontmatter", "seo") },
      # Pools first (food sections, beer styles), so the entries filed under them can name them.
      "entries" => CollectionEntry.live.includes(:collection, :category, :tags).sort_by { [it.collection.categories_collection_id || it.collection.tags_collection_id ? 1 : 0, it.collection.slug, it.id] }.map do |entry|
        keep.(entry, "slug", "title", "locale", "frontmatter", "body_markdown", "seo", "published_at")
          .merge("collection" => entry.collection.slug, "category" => entry.category&.slug, "tags" => entry.tags.map(&:slug))
      end,
      "forms" => (defined?(Form) ? Form.where(status: "published").order(:slug).map { keep.(it, "slug", "title", "fields", "submit_label", "success_message") } : []),
      "site" => Setting.get("general").slice("title", "description", "phone", "email", "address_line1", "city", "state", "zip")
    }
    path = Oldmill::Engine.root.join("spec/fixtures/cms/snapshot.json")
    path.write(JSON.pretty_generate(snapshot))
    puts "#{path}: #{snapshot.transform_values(&:size).to_h}"
  end
end
