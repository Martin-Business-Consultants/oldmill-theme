# Old Mill Brewpub & Grill theme

oldmillbrew.com, drawn by Libre Publish: the site's layout, a partial per
block type, the beer, dish and special pages, its forms and form emails, and
its stylesheet and scripts. Plain ERB and CSS and an importmap; nothing is
built. It started as the
[theme starter](https://github.com/Martin-Business-Consultants/libre-publish-theme-starter)
and keeps everything the starter does the way the CMS expects it. How themes
work: Libre Publish's docs/themes.md.

The design, content model and layout are the Astro site's
([oldmill](https://github.com/Martin-Business-Consultants/oldmill)), drawn
from the same CMS content: stone and amber, dark by default with a light
"limestone" mode a visitor can switch to, Fraunces over Inter with IBM Plex
Mono for the ledger details. Fonts are served from the theme, not Google.

## What draws what

| Address | From |
| --- | --- |
| `/`, `/about`, `/menu`, `/beers`, `/events`, `/visit`, `/careers`, `/privacy` | the page's blocks (`app/views/website/blocks/_<type>`) |
| `/careers` | its blocks, then the published form with the page's slug (`careers`), unless a Form block on the page already draws it |
| `/beers/<slug>`, `/food/<slug>`, `/specials/<slug>` | `app/views/website/entries/<collection>` |
| `/beer-categories/…`, `/food-categories/…`, `/food-tags/…` | nothing: the pools have no pages (404), so nothing links to them |
| anything else | the CMS's `not-found` page, with a 404 and noindex |
| header, footer | the `nav` and `footer` globals (both still draw without them) |

The tap list, the menu and the week's specials are the `beers`, `food` and
`specials` collections, not the blocks' own lists: beers newest first; dishes
by their section (`food-categories`, by `position`), dietary marks read from
the title ("(GF)"); specials grouped by `day`, only those `active`, today's
tab open in Plainwell time (a script re-picks it on the visitor's clock,
since a cached page can outlive the day). The blocks' own `beers` and
`categories` stand in only where those collections are missing.

The pages' SEO panels hold `seo_title` and `seo_description` (and the 404's
`no_index`), the names the site's import gave them; the theme reads those
when `meta_title` and `meta_description` are blank. Settings › General has
no phone or address: the home hero takes them from the `footer` global.

A block field called `name` (an event's, a beer's, a dish's) is read as
`data["name"]`: `data.name` is `Website::Fields`' own name for the record.

## From the starter

- **Its own files** at `/_oldmill/<file>?v=<digest>` (`Oldmill::AssetsController`),
  not the asset pipeline, so an install that hasn't compiled a theme added
  from Settings › Plugins still draws every page. Scripts are every `.js` in
  `app/javascript/oldmill`, in an importmap of the theme's own; `site.js`
  imports the rest.
- **The helper** (`app/helpers/oldmill_helper.rb`): the site's name, links
  without the preview's inline-edit marks (`oldmill_href`, `oldmill_tel`,
  `oldmill_mailto`), the title, Branding's logo and favicon (the mill's own
  otherwise), and the forms.
- **Form and FAQ block types**, installed when the theme is switched on
  (`lib/oldmill/block_types.rb`), and a partial for every core block type.
- **Forms**: `website/shared/_form` draws any of the site's forms, every
  field type, in the mill's design; `forms.js` posts it in place with the
  honeypot, Turnstile or reCAPTCHA as Settings › Forms has them, and the
  visit's attribution (UTM tags, click ids, landing page) for the fields
  that keep it. The form **emails** (`website/emails/form`) are in the
  site's limestone palette and amber.
- **The 404**, the web manifest, a skip link, `lang` from what's shown.

Settings › Themes › Customize: the colors a first-time visitor sees (dark or
light), and whether the sun/moon switch is shown.

## Working on it

Clone it beside a Libre Publish checkout and link it in, with the live
site's content:

    bin/theme link ../oldmill-theme
    bin/pull oldmill --without-people      # then, in this copy only: Settings › General › How the site is served: Website
    bin/rails runner themes/oldmill/script/import.rb   # the theme's block types, if the copy predates them
    bin/dev

The live CMS serves the Astro site over the API, so a pulled copy comes
over "API only"; switch the copy to Website to see the theme.

## Check it

    bin/rails oldmill:snapshot                             # the content the spec draws (after bin/pull)
    bin/rspec themes/oldmill/spec
    bundle exec herb lint themes/oldmill --fail-level warning
    bin/rubocop themes/oldmill
    bundle exec brakeman --add-engines-path themes/oldmill

`spec/fixtures/cms/snapshot.json` is the CMS's content model and live
content. `spec/requests/website_spec.rb` is the starter's: every page,
entry, block type (from its defaults, and in the editor's preview) and form,
the globals, the 404 and the theme's files. `spec/requests/oldmill_spec.rb`
is this site's: the pages' SEO titles, the tap list, menu and specials in
the Astro site's order, the events' names, the careers form and its emails,
links in the editor's preview, and the design settings.
`spec/system/forms_spec.rb` posts a form in headless Chrome
(`spec/support/oldmill_browser.rb` starts it on a machine without root).

## Releasing it

The repository is `Martin-Business-Consultants/oldmill-theme`. Bump
`lib/oldmill/version.rb`, tag `v<version>` (the CMS compares the two), and
publish a GitHub release. In the site's admin, Settings › Plugins › Add a
plugin with `Martin-Business-Consultants/oldmill-theme` installs it; Settings
› Themes shows later versions. If the site has Settings › Security policy
on, allow Turnstile (`challenges.cloudflare.com`) or reCAPTCHA there for its
forms.

Proprietary. Copyright Martin Business Consultants.
