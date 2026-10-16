# frozen_string_literal: true

require "rails_helper"
require_relative "../support/oldmill_content"

# The theme against the CMS it draws (spec/support/oldmill_content.rb says
# from what). A template that reads a field the CMS doesn't declare
# (Website::Fields), a block type the theme has no partial for, or a form
# field the form doesn't have fails here, not on the live site.
RSpec.describe "The website", type: :request, website: true do
  before do
    switch_plugin :forms, on: true if Cms::Plugins.manifests.key?(:forms)
    # Another theme linked beside this one (bin/theme link) is switched off, as on a real install.
    Website.themes.each_key { |key| switch_plugin key.to_sym, on: key == "oldmill" if Cms::Plugins.manifests.key?(key.to_sym) }
    Oldmill::Content.load!
  end

  def html = Nokogiri::HTML5(response.body)

  it "draws every page, each block of it, with one h1, a title and its robots" do
    Page.live.find_each do |page|
      next if page.slug.in?(%w[404 not-found])

      path = (page.path == "home") ? "/" : "/#{page.path}"
      get path

      expect(response).to have_http_status(:ok), "#{path}: #{response.status}"
      Array(page.blocks).each { expect(Oldmill::Content::PARTIALS).to include(it["type"]), "#{path} has a #{it["type"]} block and no partial for it" }
      expect(html.css("main h1").size).to eq(1), "#{path} has #{html.css("main h1").size} h1s"
      expect(html.at_css("title").text).to be_present
      expect(html.at_css("meta[name=robots]")["content"]).to start_with(page.seo.to_h["noindex"] ? "noindex" : "index")
      expect(html.at_css("html")["lang"]).to eq(page.locale.presence || "en")
    end
  end

  it "draws the entries of every collection it has a template for, and no others" do
    CollectionEntry.live.includes(:collection).find_each do |entry|
      drawn = Oldmill::Content::ENTRY_TEMPLATES.include?(entry.collection.slug)
      get entry.public_path

      expect(response).to have_http_status(drawn ? :ok : :not_found), entry.public_path
    end
  end

  it "has a partial for every block type an editor can add, and only for ones the CMS has" do
    addable = BlockType.where(deprecated: false).pluck(:slug) - ["pattern"]
    expect(addable - Oldmill::Content::PARTIALS).to be_empty
    expect(Oldmill::Content::PARTIALS - BlockType.pluck(:slug)).to be_empty
  end

  it "draws every block type it has a partial for, from the type's defaults" do
    Page.new(slug: "every-block", path: "every-block", title: "Every block", status: "published", locale: "en", blocks: Oldmill::Content.every_block).save!(validate: false)

    get "/every-block"

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("— —")
  end

  it "draws every block in the editor's preview, with its inline-edit marks" do
    sign_in_as create(:user)
    home = Page.find_by!(path: "home")
    blocks = Oldmill::Content.every_block.each_with_index.to_h { |block, index| [index.to_s, {"_json" => block.to_json}] }

    patch page_path(home.slug, website_preview: 1), params: {page: {title: home.title, slug: home.slug, status: "published", lock_version: home.lock_version, blocks:}}

    expect(response).to have_http_status(:ok)
  end

  it "takes the nav and footer from their globals" do
    get "/"

    nav = Global.find_by!(slug: "nav").data
    expect(html.css("header nav[aria-label=Main] a").map { it.text.strip }).to eq(Array(nav["items"]).map { it["label"] })
    footer = Global.find_by!(slug: "footer").data
    labels = Array(footer["columns"]).flat_map { |column| Array(column["items"]).map { it["label"] } }
    expect(html.css("footer nav a").map { it.text.strip }).to eq(labels)
  end

  it "still draws without its globals, before a site's content is in" do
    Global.where(slug: %w[nav footer]).delete_all

    get "/"

    expect(response).to have_http_status(:ok)
  end

  it "draws its 404 never indexed" do
    get "/no-such-page"

    expect(response).to have_http_status(:not_found)
    expect(html.at_css("meta[name=robots]")["content"]).to start_with("noindex")
  end

  it "draws every published form with exactly its fields, a honeypot and where to post" do
    skip "no Forms plugin" unless defined?(Form)

    Form.where(status: "published").find_each do |form|
      Page.create!(slug: "form-#{form.slug}", path: "form-#{form.slug}", title: form.title, status: "published", locale: "en",
        blocks: [{"type" => "form", "version" => 1, "data" => {"form" => form.slug, "heading" => form.title}}])

      get "/form-#{form.slug}"

      drawn = html.at_css("form[data-form='#{form.slug}']")
      expect(drawn["action"]).to eq("/api/forms/#{form.slug}/submissions")
      names = drawn.css("input, select, textarea").filter_map { it["name"]&.delete_suffix("[]") }.uniq - ["_hp"]
      expect(names.sort).to eq(form.fields.map { it["name"] }.sort)
      expect(drawn.at_css("input[name=_hp]")).to be_present
    end
  end

  it "takes a submission the way forms.js sends it" do
    skip "no Forms plugin" unless defined?(Form)

    form = Form.find_by!(status: "published")
    data = form.fields.to_h do |field|
      value = case field["type"]
      when "email" then "ann@example.com"
      when "url" then "https://example.com"
      when "select", "radio" then FormChoices.for(field).first&.dig("value")
      else "Something"
      end
      [field["name"], value]
    end

    post "/api/forms/#{form.slug}/submissions", params: data, headers: {"Accept" => "application/json"}

    expect(response).to have_http_status(:created), response.body
  end

  it "serves its own files, its scripts from its own importmap, and its web manifest" do
    get "/"

    stylesheet = html.at_css("link[rel=stylesheet]")["href"]
    expect(stylesheet).to match(%r{\A/_oldmill/site\.css\?v=\h+\z})
    get stylesheet
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/css")

    get "/"
    imports = JSON.parse(html.at_css("script[type=importmap]").text)["imports"]
    expect(imports.keys).to include("oldmill/site", "oldmill/forms")
    imports.each_value do |path|
      get path
      expect(response).to have_http_status(:ok)
    end

    get "/_oldmill/../../config/routes.rb"
    expect(response).to have_http_status(:not_found)

    get "/site.webmanifest"
    expect(JSON.parse(response.body)["name"]).to be_present
  end
end
