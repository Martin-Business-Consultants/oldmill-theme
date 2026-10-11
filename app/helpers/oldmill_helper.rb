# frozen_string_literal: true

# The theme's own vocabulary on top of WebsiteHelper: the beer list, the
# food menu and the week's specials as the collections hold them, the words
# around them, its icons and buttons, and the forms it draws by hand.
module OldmillHelper
  ICONS = Oldmill::Engine.root.join("app/assets/images/oldmill/icons")
  DAYS = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday].freeze
  # The pub's day, not the visitor's: the specials run on Plainwell time.
  TIME_ZONE = "America/New_York"
  DIETARY_MARKS = /\s*\((GF|GS|V)\)/i
  DIETARY_LABELS = {"GF" => "Gluten-free", "GS" => "Gluten-sensitive", "V" => "Vegetarian"}.freeze

  def oldmill_nav = website_global(:nav)

  def oldmill_footer = website_global(:footer)

  def oldmill_name = website_settings["title"].presence || "Old Mill Brewpub & Grill"

  # The "Order Online" link (the nav global's), or nil.
  def oldmill_order = (oldmill_nav.cta_url.presence && {label: oldmill_nav.cta_label.presence || "Order Online", href: oldmill_nav.cta_url})

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

  # A link typed into a text field: a page ("/menu/", the Astro site's
  # slashed form) at its address here ("/menu"), anything else as written.
  # In the editor's preview a text field carries its inline-edit markers
  # (Website::InlineEdit); an address is followed, not edited in place.
  def oldmill_href(url)
    url = url.to_s.delete(INLINE_EDIT_MARKS).strip
    return if url.empty? || !SafeUrl.safe?(url)

    url.match?(%r{\A/[^/?#]+.*/\z}) ? url.chomp("/") : url
  end
  INLINE_EDIT_MARKS = [Website::InlineEdit::START, Website::InlineEdit::FINISH, *Website::InlineEdit::DIGITS].join

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
  OLDMILL_ICON_CACHE = {} # rubocop:disable Style/MutableConstant

  # "(269) 204-6601" as a tel: link's href.
  def oldmill_tel(phone) = "tel:#{phone.to_s.gsub(/[^+\d]/, "")}"

  def oldmill_directions(address) = "https://www.google.com/maps/search/?api=1&query=#{ERB::Util.url_encode(address.to_s.gsub(/\s*\n\s*/, ", "))}"

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
      image_tag("oldmill/logo.webp", alt:, width: 160, height: 80, **options)
  end

  def oldmill_favicon_href
    id = Setting.get("branding")["favicon_id"].presence
    (id && website_image_url(id, width: 192)) || asset_path("oldmill/favicon.png")
  end

  # Cloudflare Turnstile ({site_key:, theme:}) when Settings › Forms has it
  # set up (the Forms plugin then refuses a submission without its token),
  # else nil.
  def oldmill_turnstile
    captcha = Forms.public_captcha if defined?(Forms) && Forms.respond_to?(:public_captcha)
    {site_key: captcha[:site_key], theme: captcha[:theme] || "auto"} if captcha && captcha[:provider] == "turnstile"
  end

  # The published form a page shows under its blocks: the one with the
  # page's own slug (the careers page, the careers form). Nil without one,
  # or without the Forms plugin.
  def oldmill_page_form(page)
    defined?(Form) && Form.find_by(slug: page.slug, status: "published")
  end

  # A form field's control, by its type as the form defines it. Choices are
  # the form's (FormChoices works out those taken from a collection).
  def oldmill_form_control(field, id:)
    name = field["name"]
    required = field["required"].present?
    attributes = {class: "field__input", id:, name:, required:}
    choices = defined?(FormChoices) ? FormChoices.for(field) : Array(field["options"])
    case field["type"]
    when "textarea"
      tag.textarea("", rows: 5, placeholder: field["placeholder"], **attributes)
    when "select"
      prompt = tag.option(field["placeholder"].presence || "Choose one…", value: "", disabled: true, selected: true)
      tag.select(safe_join([prompt, *choices.map { tag.option(it["label"], value: it["value"]) }]), **attributes)
    when "radio", "checkbox"
      return tag.input(type: "checkbox", value: "yes", class: "field__check", id:, name:, required:) if field["type"] == "checkbox" && choices.empty?

      tag.div(class: "field__choices", id:) do
        safe_join(choices.each_with_index.map do |choice, index|
          tag.label(class: "field__choice") do
            safe_join([tag.input(type: field["type"], name: (field["type"] == "checkbox") ? "#{name}[]" : name, value: choice["value"],
              required: required && field["type"] == "radio" && index.zero?), tag.span(choice["label"])])
          end
        end)
      end
    else
      autocomplete = {"full_name" => "name", "name" => "name", "first_name" => "given-name", "last_name" => "family-name"}[name] ||
        {"email" => "email", "tel" => "tel", "url" => "url"}[field["type"]]
      tag.input(type: field["type"].presence_in(%w[text email tel url file]) || "text", placeholder: field["placeholder"], autocomplete:, **attributes)
    end
  end

  # The year in the footer's copyright line.
  def oldmill_year = Time.current.in_time_zone(TIME_ZONE).year

  # Whether an href is the page being shown.
  def oldmill_current?(href)
    path = href.to_s.split(/[?#]/).first.to_s
    !path.empty? && (path.chomp("/").presence || "/") == (request.path.chomp("/").presence || "/")
  end
end
