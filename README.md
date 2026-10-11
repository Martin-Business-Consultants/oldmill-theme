# Old Mill Brewpub & Grill theme

oldmillbrew.com, drawn by Libre Publish: the site's layout, a partial per
block type, the beer, dish and special pages, its form emails, and its
stylesheet and scripts. Plain ERB and CSS and an importmap; nothing is
built. How themes work: Libre Publish's docs/themes.md.

The design, content model and layout are the Astro site's
([oldmill](https://github.com/Martin-Business-Consultants/oldmill)), drawn
from the same CMS content: stone and amber, dark by default with a light
"limestone" mode a visitor can switch to, Fraunces over Inter with IBM Plex
Mono for the ledger details. Fonts are served from the theme, not Google.

## What draws what

| Address | From |
| --- | --- |
| `/`, `/about`, `/menu`, `/beers`, `/events`, `/visit`, `/careers`, `/privacy` | the page's blocks (`app/views/website/blocks/_<type>`) |
| `/careers` | its blocks, then the published form with the page's slug (`careers`) |
| `/beers/<slug>`, `/food/<slug>`, `/specials/<slug>` | `app/views/website/entries/<collection>` |
| anything else | the CMS's `not-found` page, with a 404 and noindex |
| header, footer | the `nav` and `footer` globals |

The tap list, the menu and the week's specials are the `beers`, `food` and
`specials` collections, not the blocks' own lists: beers newest first; dishes
by their section (`food-categories`, by `position`), dietary marks read from
the title ("(GF)"); specials grouped by `day`, only those `active`, today's
tab open in Plainwell time (a script re-picks it on the visitor's clock,
since a cached page can outlive the day). The blocks' own `beers` and
`categories` stand in only where those collections are missing.

The pages' SEO panels hold `seo_title` and `seo_description` (and the 404's
`no_index`), the names the site's import gave them; the theme reads those
when `meta_title` and `meta_description` are blank.

Settings › Themes › Customize: the colors a first-time visitor sees (dark or
light), and whether the sun/moon switch is shown.

## Working on it

Clone it beside a Libre Publish checkout and link it in, with the live
site's content:

    bin/theme link ../oldmill-theme
    bin/pull oldmill --without-people      # then, in this copy only: Settings › General › How the site is served: Website
    bin/dev

The live CMS serves the Astro site over the API, so a pulled copy comes
over "API only"; switch the copy to Website to see the theme. Then:

    bin/rspec themes/oldmill/spec                          # every page, from the snapshot
    bundle exec herb lint themes/oldmill --fail-level warning
    bin/rails oldmill:snapshot                             # refresh the snapshot from this install (after bin/pull)

`spec/fixtures/cms/snapshot.json` is the CMS's content model and live
content. The spec draws every page and entry from it, and every block type
from its defaults, so a template reading a field the CMS doesn't declare
fails here before it breaks a page.

## Installing it

In the site's Libre Publish admin: Settings › Plugins › Add a plugin, and
give `Martin-Business-Consultants/oldmill-theme`. It installs the latest
release and restarts; the site is at `/` while the theme is switched on and
the site is served as Website (Settings › General). Publish a release here
(bump `lib/oldmill/version.rb`, tag `v0.1.0`, and a GitHub release) and the
theme's Update button takes it.

Proprietary. Copyright Martin Business Consultants.
