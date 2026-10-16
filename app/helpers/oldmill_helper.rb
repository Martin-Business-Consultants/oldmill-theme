# frozen_string_literal: true

# The theme's own vocabulary on top of WebsiteHelper: what every theme needs
# (its files at the address the theme serves them from, the site's name,
# links, the title and favicon, and the forms), then the beer list, the food
# menu and the week's specials as the collections hold them, the words around
# them, and its icons and buttons. Each helper is named for the theme, so two
# themes linked side by side never shadow each other's.
module OldmillHelper
  ICONS = Oldmill::Engine.root.join("app/assets/images/oldmill/icons")
  # Inline editing (the editor's preview) marks editable text with invisible
  # characters; an address or a phone number can't carry them.
  INLINE_EDIT_MARKS = [Website::InlineEdit::START, Website::InlineEdit::FINISH, *Website::InlineEdit::DIGITS].join.freeze
  # The attribution a form keeps, for the fields its form declares
  # (forms.js fills them from the visit).
  ATTRIBUTION = %w[utm_source utm_medium utm_campaign utm_term utm_content gclid fbclid msclkid landing_path referrer form_path].freeze
  DIGESTS = {} # rubocop:disable Style/MutableConstant
  OLDMILL_ICON_CACHE = {} # rubocop:disable Style/MutableConstant
  DAYS = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday].freeze
  # The pub's day, not the visitor's: the specials run on Plainwell time.
  TIME_ZONE = "America/New_York"
  DIETARY_MARKS = /\s*\((GF|GS|V)\)/i
  DIETARY_LABELS = {"GF" => "Gluten-free", "GS" => "Gluten-sensitive", "V" => "Vegetarian"}.freeze

  # ── The theme's files ──

  # A file of the theme's ("site.css", "hero.webp") at the address the theme
  # serves it from (Oldmill::AssetsController), with its digest so it can be
  # cached for good and a changed file gets a new address.
  def oldmill_asset_path(name)
    file = Oldmill::AssetsController.find(name) or raise ArgumentError, "the theme has no file #{name} (app/assets/*/oldmill, app/javascript/oldmill)"
    digest = Rails.env.production? ? (DIGESTS[name] ||= oldmill_digest(file)) : oldmill_digest(file)
    "/_oldmill/#{name}?v=#{digest}"
  end

  # The theme's scripts as ES modules (every .js in app/javascript/oldmill),
  # each preloaded, then site.js, which imports the rest. Its own importmap:
  # none of the admin's scripts reach a visitor.
  def oldmill_javascript_tags
    modules = Oldmill::AssetsController.files.keys.select { it.end_with?(".js") }.sort
    imports = modules.to_h { ["oldmill/#{it.delete_suffix(".js")}", oldmill_asset_path(it)] }
    nonce = content_security_policy_nonce
    safe_join([
      tag.script(ERB::Util.json_escape({imports:}.to_json).html_safe, type: "importmap", nonce:), # rubocop:disable Rails/OutputSafety -- our own paths, JSON-escaped
      *imports.values.map { tag.link(rel: "modulepreload", href: it, nonce:) },
      tag.script('import "oldmill/site"'.html_safe, type: "module", nonce:) # rubocop:disable Rails/OutputSafety -- a constant
    ], "\n")
  end

  # ── The site ──

  def oldmill_name = website_settings["title"].presence || "Old Mill Brewpub & Grill"

  # The language of what's shown: the record's own locale, else the site's.
  def oldmill_locale(record = nil) = record.try(:locale).presence || website_settings["default_locale"].presence || "en"

  # A global's data, or nil when the site doesn't have it (a fresh site, or
  # one whose content hasn't been copied yet), so the layout still draws.
  def oldmill_global(slug)
    website_global(slug)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def oldmill_nav = oldmill_global(:nav)

  def oldmill_footer = oldmill_global(:footer)

  # The "Order Online" link (the nav global's), or nil.
  def oldmill_order
    href = oldmill_href(oldmill_nav&.cta_url) or return
    {label: oldmill_nav.cta_label.presence || "Order Online", href:}
  end

  # Whether the theme draws a collection's entries (website/entries/<slug>):
  # an entry of one it doesn't is a 404, so nothing links to it.
  def oldmill_draws?(collection_slug) = lookup_context.exists?("website/entries/#{collection_slug}", [], false)

  # The beers on tap: the beers collection, newest first, as oldmillbrew.com lists them.
  def oldmill_beers = @oldmill_beers ||= oldmill_newest_first(website_entries(:beers))

  # The food menu: each section of the food collection (its category), in
  # the sections' own order, the dishes in each newest first.
  def oldmill_menu
    @oldmill_menu ||= begin
      dishes = oldmill_newest_first(website_entries(:food)).select(&:category)
      dishes.group_by(&:category)
        .sort_by { |section, _| [website_fields(section).position || 999, section.title.to_s] }
        .map { |section, items| {name: website_plain_text(section.title), slug: section.slug, items:} }
    end
  end

  # The week's specials: every active entry of the specials collection, by the
  # day it runs, Monday to Sunday (days without one left out).
  def oldmill_specials_week
    @oldmill_specials_week ||= begin
      active = website_entries(:specials).select { |special| website_truthy?(website_fields(special).active) && DAYS.include?(website_fields(special).day) }
      active.group_by { website_fields(it).day }.sort_by { |day, _| DAYS.index(day) }.to_h
    end
  end

  # Today, in Plainwell. The page opens today's specials; a script re-picks
  # the day on the visitor's clock, since a cached page can outlive it.
  def oldmill_today = Time.current.in_time_zone(TIME_ZONE).strftime("%A")

  # Entries imported from WordPress have a publish date; ones added in the
  # CMS since tie on none, and the latest edit breaks it.
  def oldmill_newest_first(entries) = entries.sort_by { [-(it.published_at || Time.zone.at(0)).to_f, -it.updated_at.to_f] }

  # "Mexican Street Corn Dip (GS) (V)" → ["Mexican Street Corn Dip", ["GS", "V"]].
  def oldmill_dietary(title)
    plain = oldmill_texturize(website_plain_text(title))
    [plain.gsub(DIETARY_MARKS, "").strip, plain.scan(DIETARY_MARKS).flatten.map(&:upcase)]
  end

  def oldmill_dietary_label(marks) = marks.map { DIETARY_LABELS[it] || it }.join(" · ")

  # A dish that's on the daily menu but not the Sunday one says so.
  def oldmill_weekdays_only?(dish)
    tags = dish.tags.map(&:slug)
    tags.any? && tags.exclude?("sunday")
  end

  # A beer's ABV as "5.3%", or nil.
  def oldmill_abv(beer)
    abv = website_fields(beer).abv.to_s.strip
    abv.presence && (abv.end_with?("%") ? abv : "#{abv}%")
  end

  # An entry's text (its body) as one line, typeset as WordPress set the
  # same copy on oldmillbrew.com.
  def oldmill_body_text(entry) = oldmill_texturize(website_plain_text(entry.body_markdown))

  # WordPress's typographic touch-ups: a free-standing "--" is an em dash,
  # one touching a word an en dash, single quotes are curly, a double quote
  # after a number an inch mark.
  def oldmill_texturize(text)
    text.to_s.gsub(/(^|\s)--(?=\s)/, '\1—').gsub("--", "–").gsub(/(^|[\s(])'(?=\p{L})/, '\1‘').tr("'", "’").gsub(/(\d)"/, '\1″')
  end

  # A heading with its highlighted words ("Brewed In" + "History"), the
  # highlight in amber, italic where the design sets it so.
  # amber: false leaves it in the heading's color, as the Astro site's
  # calls to action and event sections do.
  def oldmill_heading(heading, highlight = nil, italic: false, amber: true)
    parts = [(heading if heading.present?), (tag.span(highlight, class: class_names("highlight": amber, "highlight--italic": italic)) if highlight.present?)]
    safe_join(parts.compact, " ")
  end

  # A paragraph of inline HTML as the site's import left it ("Built in
  # <strong>1869</strong>, …"): its inline tags kept, everything else
  # dropped. Rich text from the editor (starting with a tag) as it is.
  def oldmill_paragraph(value)
    text = value.to_s.strip
    return "" if text.empty?
    return website_rich_text(text) if text.start_with?("<")

    tag.p(sanitize(text, tags: %w[strong b em i u a br span], attributes: %w[href]))
  end

  # The <head>: the SEO panel, then what this CMS's pages carry under the
  # names the site's import gave them (seo_title, seo_description, no_index).
  def oldmill_seo_tags(record, description: nil, image: nil, title: nil, noindex: false)
    legacy = record.respond_to?(:seo) ? record.seo.to_h.stringify_keys : {}
    website_seo_tags(record, title: legacy["seo_title"].presence || title || (record.title && "#{record.title} | #{oldmill_name}"),
      description: legacy["seo_description"].presence || description,
      image: image || oldmill_share_image, noindex: noindex || website_truthy?(legacy["no_index"]))
  end

  # A beer's, dish's or special's meta description: led by its name so no
  # two pages share one, with where it sits on the menu when its own copy is
  # short, cut at a word near 155 characters.
  def oldmill_item_description(name:, body:, context:)
    lead = body.present? ? "#{name}: #{body.strip.sub(/[.\s]+\z/, "")}." : "#{name}."
    text = (lead.length < 110) ? "#{lead} #{context}" : lead
    (text.length <= 158) ? text : "#{text[0, 155].sub(/\s+\S*\z/, "")}…"
  end

  # The share image when a record has none: General's default.
  def oldmill_share_image = website_settings["default_og_image"].presence

  # An href from a link field ({kind, value}) or a link typed into a text
  # field: a page ("/menu/", the Astro site's slashed form) at its address
  # here ("/menu"), anything else as written. In the editor's preview a text
  # field carries its inline-edit markers (Website::InlineEdit); an address
  # is followed, not edited in place. Nothing for an empty or unsafe one.
  def oldmill_href(link)
    link = {"kind" => "url", "value" => link} unless link.is_a?(Hash)
    link = link.to_h.stringify_keys
    href = website_href(link.merge("value" => oldmill_plain(link["value"]))) or return
    href.match?(%r{\A/[^/?#]+.*/\z}) ? href.chomp("/") : href
  end

  def oldmill_plain(text) = text.to_s.delete(INLINE_EDIT_MARKS).strip

  # Opens in a new tab: an address on another site.
  def oldmill_external?(href) = href.to_s.match?(%r{\Ahttps?://})

  def oldmill_link_options(href) = oldmill_external?(href) ? {target: "_blank", rel: "noopener noreferrer"} : {}

  # A button: a link with `href:`, else a <button>. Variants: primary
  # (amber), outline (a hairline over the dark), social (stone, amber on
  # hover).
  # icon: before the label; icon_after: after it.
  def oldmill_button(label = nil, href: nil, variant: :primary, icon: nil, icon_after: nil, type: :button, **options, &block)
    label = capture(&block) if block
    options[:class] = ["button", "button--#{variant}", options[:class]].compact.join(" ")
    content = safe_join([(oldmill_icon(icon) if icon), tag.span(label), (oldmill_icon(icon_after) if icon_after)].compact)
    href ? link_to(content, href, **oldmill_link_options(href), **options) : button_tag(content, type:, **options)
  end

  # An icon (app/assets/images/oldmill/icons), inline so it takes the text's
  # color and costs no request. Decorative unless given a `label`.
  def oldmill_icon(name, label: nil, **options)
    svg = (OLDMILL_ICON_CACHE[name.to_s] ||= ICONS.join("#{name}.svg").read.strip)
    attributes = {class: ["icon", options.delete(:class)].compact.join(" "), focusable: "false"}
    attributes.merge!(label ? {role: "img", "aria-label": label} : {"aria-hidden": "true"})
    svg.sub("<svg", "<svg #{tag.attributes(attributes)}").html_safe # rubocop:disable Rails/OutputSafety -- the theme's own files
  end

  # "tel:+12692046601" from however the number is written; nil without one.
  def oldmill_tel(phone = website_settings["phone"])
    digits = oldmill_plain(phone).gsub(/[^\d+]/, "")
    "tel:#{digits}" if digits.present?
  end

  # "mailto:mgmt@oldmillbrew.com"; nil without one.
  def oldmill_mailto(email)
    address = oldmill_plain(email)
    "mailto:#{address}" if address.present?
  end

  def oldmill_directions(address) = "https://www.google.com/maps/search/?api=1&query=#{ERB::Util.url_encode(oldmill_plain(address).gsub(/\s*\n\s*/, ", "))}"

  # An image field, or what an import left in its place: an Active Storage
  # URL (about_intro's image_url) of a file in the media library. The asset's
  # id, or nil.
  def oldmill_image(id, url = nil)
    return id if id.present?

    signed = url.to_s[%r{/blobs/(?:redirect/|proxy/)?([^/]+)/}, 1] or return
    blob = ActiveStorage::Blob.find_signed(signed) or return
    ActiveStorage::Attachment.find_by(blob_id: blob.id, record_type: "Asset")&.record_id
  end

  # The Branding logo, else the mill's own.
  def oldmill_logo(**options)
    alt = oldmill_name
    website_image_tag(Setting.get("branding")["logo_id"], alt:, sizes: "10rem", loading: :eager, **options) ||
      image_tag(oldmill_asset_path("logo.webp"), alt:, width: 160, height: 80, **options)
  end

  def oldmill_favicon_href
    id = Setting.get("branding")["favicon_id"].presence
    (id && website_image_url(id, width: 192)) || oldmill_asset_path("favicon.png")
  end

  # ── Forms (the Forms plugin) ──

  # A published form by slug, or nil (no Forms plugin, or no such form).
  def oldmill_form(slug)
    return unless defined?(Form) && Cms::Plugins.enabled?(:forms)

    Form.find_by(slug: oldmill_plain(slug), status: "published")
  end

  # The published form a page shows under its blocks: the one with the
  # page's own slug (the careers page, the careers form), unless one of its
  # blocks already draws it.
  def oldmill_page_form(page)
    form = oldmill_form(page.slug) or return
    form unless Array(page.blocks).any? { it["type"] == "form" && oldmill_plain(it.dig("data", "form")) == form.slug }
  end

  # Where a form posts (the Forms plugin's public endpoint).
  def oldmill_form_action(form) = "/api/forms/#{form.slug}/submissions"

  # A choice field's options as the form defines them (a collection's
  # entries too, for one that lists them).
  def oldmill_choices(field) = defined?(FormChoices) ? FormChoices.for(field) : Array(field["options"]).select { it.is_a?(Hash) }

  # The spam check Settings › Forms has set up ({provider:, site_key:,
  # theme:}), or nil. The Forms plugin refuses a submission without its token
  # when one is, so a form that doesn't draw it never gets through.
  def oldmill_captcha = defined?(Forms) && Forms.respond_to?(:public_captcha) ? Forms.public_captcha : nil

  # A select for a choice field: a prompt, then the form's choices.
  def oldmill_select(field, id:, required:)
    prompt = tag.option(field["placeholder"].presence || "Select one…", value: "", disabled: required, selected: true)
    choices = oldmill_choices(field).map { tag.option(it["label"], value: it["value"]) }
    tag.select(safe_join([prompt, *choices]), id:, name: field["name"], required:, class: "field__input")
  end

  # Autofill hints for the fields browsers know how to fill.
  def oldmill_autocomplete(field)
    {"full_name" => "name", "name" => "name", "first_name" => "given-name", "last_name" => "family-name"}[field["name"]] ||
      {"email" => "email", "tel" => "tel", "url" => "url"}[field["type"]]
  end

  # A field the form keeps for attribution: filled by the page, never shown.
  def oldmill_attribution?(field) = ATTRIBUTION.include?(field["name"])

  # The hidden attribution inputs, for the fields the form declares.
  def oldmill_attribution(form)
    safe_join(ATTRIBUTION.filter_map do |name|
      next unless form.fields.any? { it["name"] == name }

      tag.input(type: "hidden", name:, value: (name == "form_path") ? request.path : nil, data: {attribution: name})
    end)
  end

  # The year in the footer's copyright line.
  def oldmill_year = Time.current.in_time_zone(TIME_ZONE).year

  # Whether an href is the page being shown.
  def oldmill_current?(href)
    path = href.to_s.split(/[?#]/).first.to_s
    !path.empty? && (path.chomp("/").presence || "/") == (request.path.chomp("/").presence || "/")
  end

  private

  def oldmill_digest(file) = Digest::SHA1.file(file).hexdigest[0, 10]
end
