# frozen_string_literal: true

# oldmillbrew.com's content already lives in its CMS (oldmill.librepublish.com),
# where the Astro site read it over the API: pages, the beers, food and
# specials collections with their pools, the nav, footer and general
# globals, and the careers form. Nothing needs importing: bin/pull brings a
# copy of it here,
#
#   bin/pull oldmill --without-people
#
# and switching the theme on there installs its own block types (Form, FAQ).
# A copy where the theme was switched on before it had them gets them from
# this (an existing block type is left as it is):
#
#   bin/rails runner themes/oldmill/script/import.rb
#
# Then bin/rails oldmill:snapshot, and the theme's spec draws every page.
# script/import/kit.rb is the starter's, for a section that ever has to be
# brought in from elsewhere.
installed = BlockType.install_plugin_pack(:oldmill, Oldmill::BLOCK_TYPES)
puts "The theme's block types: #{Oldmill::BLOCK_TYPES.map { it[:slug] }.join(", ")} (#{installed.to_i} new)."
