# frozen_string_literal: true

require "rails_helper"

# The theme against the CMS it draws: spec/fixtures/cms/snapshot.json is the
# content model and live content of oldmillbrew.com (block types,
# collections with their style and section pools, globals and the careers
# form, with their fields, and every live page and entry). Every page and
# entry is drawn from it, so a template that reads a field the CMS doesn't
# declare (Website::Fields) or a form field the form doesn't have fails
# here. Refresh it with bin/pull oldmill, then bin/rails oldmill:snapshot.
RSpec.describe "The Old Mill website", type: :request, website: true do
  SNAPSHOT = JSON.parse(Oldmill::Engine.root.join("spec/fixtures/cms/snapshot.json").read)
  PARTIALS = Oldmill::Engine.root.glob("app/views/website/blocks/_*.html.erb").map { it.basename.to_s[/\A_(\w+)\./, 1] }
  NAME = SNAPSHOT.dig("site", "title")

  before do
    switch_plugin :forms, on: true
    SNAPSHOT["block_types"].each { BlockType.create!(it) }
    collections = SNAPSHOT["collections"].to_h { [it["slug"], Collection.create!(it.except("categories_collection", "tags_collection"))] }
    SNAPSHOT["collections"].each do |collection|
      collections[collection["slug"]].update!(categories_collection: collections[collection["categories_collection"]], tags_collection: collections[collection["tags_collection"]])
    end
    SNAPSHOT["globals"].each { |global| Global.create!(global.except("fields").merge("schema" => {"fields" => global["fields"]})) }
    SNAPSHOT["forms"].each { Form.create!(it.merge("status" => "published")) }
    SNAPSHOT["pages"].each { Page.create!(it.merge("status" => "published")) }
    SNAPSHOT["entries"].each do |entry|
      collection = collections.fetch(entry["collection"])
      category = entry["category"] && collection.categories_collection.entries.find_by!(slug: entry["category"])
      tags = collection.tags_collection ? collection.tags_collection.entries.where(slug: entry["tags"]).to_a : []
      collection.entries.create!(entry.except("collection", "category", "tags").merge("status" => "published", "category" => category, "tags" => tags))
    end
    Setting.set("general", SNAPSHOT["site"].merge("serving" => "website"))
  end

  def html = Nokogiri::HTML5(response.body)

  SNAPSHOT["pages"].reject { it["path"] == "not-found" }.each do |page|
    path = (page["path"] == "home") ? "/" : "/#{page["path"]}"

    it "draws #{path}, every one of its blocks" do
      get path

      expect(response).to have_http_status(:ok)
      seo = page["seo"].to_h
      title = seo["meta_title"].presence || seo["seo_title"].presence || "#{page["title"]} | #{NAME}"
      expect(html.at_css("title").text).to eq(title)
      expect(html.at_css("meta[name=description]")&.[]("content")).to eq(seo["meta_description"].presence || seo["seo_description"]) if seo["seo_description"]
      page["blocks"].each { expect(PARTIALS).to include(it["type"]) }
    end
  end

  SNAPSHOT["entries"].group_by { it["collection"] }.each do |collection, entries|
    drawn = Oldmill::Engine.root.join("app/views/website/entries/#{collection}.html.erb").exist?

    it "#{drawn ? "draws" : "has no pages for"} every #{collection} entry" do
      entries.each do |entry|
        get "/#{collection}/#{entry["slug"]}"

        expect(response).to have_http_status(drawn ? :ok : :not_found)
        expect(html.at_css("h1").text).to include(entry["title"].gsub(/\s*\((GF|GS|V)\)/i, "").strip.tr("'", "’").first(12)) if drawn
      end
    end
  end

  it "has a partial only for block types the CMS has" do
    expect(PARTIALS - SNAPSHOT["block_types"].map { it["slug"] }).to be_empty
  end

  it "draws every block type it has a partial for, from the type's defaults" do
    blocks = SNAPSHOT["block_types"].select { PARTIALS.include?(it["slug"]) }.map { {"type" => it["slug"], "version" => it["version"], "data" => it["defaults"].to_h} }
    Page.new(slug: "every-block", path: "every-block", title: "Every block", status: "published", locale: "en", blocks:).save!(validate: false)

    get "/every-block"

    expect(response).to have_http_status(:ok)
  end

  it "lists the beers on tap newest first, each to its page" do
    get "/beers"

    beers = SNAPSHOT["entries"].select { it["collection"] == "beers" }.sort_by { it["published_at"].to_s }.reverse
    expect(html.css(".beer-tile").map { it["href"] }).to eq(beers.map { "/beers/#{it["slug"]}" })
  end

  it "lays the menu out by section, in the sections' own order" do
    get "/menu"

    sections = SNAPSHOT["entries"].select { it["collection"] == "food-categories" }.sort_by { it.dig("frontmatter", "position") || 999 }
    filed = SNAPSHOT["entries"].select { it["collection"] == "food" }.filter_map { it["category"] }.uniq
    expect(html.css("#menu [role=tab]").map { it.text.strip }).to eq(sections.select { filed.include?(it["slug"]) }.map { it["title"] })
    expect(html.css("#menu .dish--link").size).to eq(SNAPSHOT["entries"].count { it["collection"] == "food" && it["category"] })
  end

  it "shows only active specials, a tab per day, today's open in Plainwell time" do
    travel_to Time.find_zone("America/New_York").local(2026, 10, 12, 23, 30) do # a Monday night in Plainwell, Tuesday in UTC
      get "/"
    end

    active = SNAPSHOT["entries"].select { it["collection"] == "specials" && it.dig("frontmatter", "active") == true }
    expect(html.css("#specials .special").size).to eq(active.size)
    open = html.at_css("#specials [role=tab][aria-selected=true]")
    expect(open["data-day"]).to eq("Monday") if active.any? { it.dig("frontmatter", "day") == "Monday" }
    expect(html.css("#specials [data-today]:not([hidden])").map { it.ancestors("[data-day]").first["data-day"] }).to eq(["Monday"])
  end

  it "draws its 404 from the CMS's not-found page, never indexed" do
    get "/no-such-page"

    expect(response).to have_http_status(:not_found)
    not_found = SNAPSHOT["pages"].find { it["path"] == "not-found" }
    expect(html.at_css("h1").text).to include(not_found["blocks"].first.dig("data", "heading_highlight"))
    expect(html.at_css("meta[name=robots]")["content"]).to start_with("noindex")
  end

  it "takes the nav and footer from their globals" do
    get "/"

    nav = SNAPSHOT["globals"].find { it["slug"] == "nav" }["data"]
    expect(html.css(".nav__menu .nav-link").map(&:text)).to eq(nav["items"].map { it["label"] })
    expect(html.at_css(".nav__menu a.button")["href"]).to eq(nav["cta_url"])
    footer = SNAPSHOT["globals"].find { it["slug"] == "footer" }["data"]
    expect(html.css(".footer__links a").map(&:text)).to eq(footer["quick_links"].map { it["label"] })
  end

  it "puts the careers form under the careers page, and posts it to the Forms plugin with every field it draws" do
    get "/careers"
    form = html.at_css("form[data-form]")
    names = form.css("input, select, textarea").map { it["name"].to_s.delete_suffix("[]") }.compact - [Form::HONEYPOT_FIELD]
    careers = Form.find_by!(slug: "careers")

    expect(names).to match_array(careers.fields.map { it["name"] })

    answers = careers.fields.to_h do |field|
      [field["name"], field["options"].present? ? field["options"].first["value"] : {"email" => "ann@example.com", "tel" => "(269) 555-0123"}.fetch(field["type"], "Ann")]
    end
    post form["action"], params: answers, as: :json
    expect(response).to have_http_status(:created)
    expect(FormSubmission.last.data).to include("email" => "ann@example.com")

    post form["action"], params: answers.except("email"), as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "shows Cloudflare Turnstile on its forms when Settings › Forms has the keys, and loads it only then" do
    get "/careers"
    expect(response.body).not_to include("cf-turnstile", "challenges.cloudflare.com")

    Setting.set(Forms::SETTING_KEY, {"captcha_provider" => "turnstile", "turnstile_site_key" => "0x4AAA-site", "turnstile_secret_key" => "0x4AAA-secret"})
    get "/careers"

    expect(html.at_css("form[data-form] .cf-turnstile")["data-sitekey"]).to eq("0x4AAA-site")
    expect(response.body.scan("challenges.cloudflare.com/turnstile/v0/api.js").size).to eq(1)
  end

  it "designs the form's emails, filled in per submission" do
    form = Form.find_by!(slug: "careers")
    email = form.emails.find_or_initialize_by(kind: "confirmation")
    email.update!(subject: "Thanks, {{full_name}}", enabled: true, blocks: [
      {"type" => "email_heading", "version" => 1, "data" => {"text" => "Thank you, {{full_name}}", "level" => "h1"}},
      {"type" => "email_submission", "version" => 1, "data" => {"title" => "What you sent", "skip_empty" => true}}
    ])
    submission = form.submissions.create!(data: {"full_name" => "Ann", "email" => "ann@example.com", "notes" => "Line <b>cook</b>"}, meta: {}, ip: "127.0.0.1")

    mail = FormSubmissionMailer.with(form_email: email, submission:, recipients: ["ann@example.com"]).deliver.message
    body = (mail.html_part || mail).body.decoded

    expect(email.site_template_status).to eq(:theme)
    expect(mail.subject).to eq("Thanks, Ann")
    expect(body).to include("Thank you, Ann", NAME.gsub("&", "&amp;"))
    expect(body.scan("data-cms-repeat").size + body.scan("{{").size).to eq(0)
  end

  it "starts dark, lets a visitor switch, and follows Customize" do
    get "/"
    expect(html.at_css("html")["data-theme"]).to eq("dark")
    expect(html.css("[data-theme-toggle]")).to be_present

    Website::Design.update(Website.theme, {"color_scheme" => "light", "theme_toggle" => "0"})
    get "/"
    expect(html.at_css("html")["data-theme"]).to eq("light")
    expect(html.css("[data-theme-toggle]")).to be_empty
  end

  it "serves its own scripts, stylesheet and fonts, none of the admin's, with nothing compiled" do
    get "/"
    page = html

    importmap = JSON.parse(page.at_css("script[type=importmap]").text)["imports"]
    expect(importmap.keys).to all(start_with("oldmill"))
    expect(importmap.values).to all(start_with("/_oldmill/"))
    expect(response.body).not_to include("litewind", "/assets/application-", "/assets/oldmill/")

    stylesheet = page.at_css("link[rel=stylesheet]")["href"]
    get stylesheet
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/css")
    expect(response.headers["Cache-Control"]).to include("immutable")
    expect(response.body).to include('url("fraunces.woff2")')

    (importmap.values + [page.at_css("link[as=font]")["href"]]).each do |path|
      get path
      expect(response).to have_http_status(:ok), path
    end
    get "/_oldmill/../../oldmill.gemspec"
    expect(response).to have_http_status(:not_found)
    get "/_oldmill/README.md"
    expect(response).to have_http_status(:not_found)
  end
end
