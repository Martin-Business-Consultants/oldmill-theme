# frozen_string_literal: true

module Oldmill
  # A theme is an engine like a plugin: its views and helpers join the app's,
  # and it registers with Website, which turns the public site on. Its files
  # are served by the theme itself (Oldmill::AssetsController), so it works
  # however it was installed; its scripts get an importmap of their own
  # (the theme helper's oldmill_javascript_tags), so the admin's never reach a
  # visitor.
  class Engine < ::Rails::Engine
    # The theme's files, ahead of the website's catch-all.
    initializer "oldmill.routes" do |app|
      app.routes.append do
        get "_oldmill/*path", to: "oldmill/assets#show", format: false, as: :oldmill_asset
      end
    end

    config.to_prepare do
      # A plugin too, so Settings › Plugins installs it from its GitHub
      # release, updates it, and switches the site on and off.
      Cms::Plugins.register :oldmill, name: "Old Mill Brewpub & Grill", version: Oldmill::VERSION,
        description: "The oldmillbrew.com website, as a theme: switch it off and the CMS is headless.",
        author: "Martin Business Consultants", enabled_by_default: true, requires: ">= 1.33",
        homepage: "https://github.com/Martin-Business-Consultants/oldmill-theme"
      # Block types the theme draws beyond the core's and the site's own,
      # installed the first time it's switched on (an existing block type is
      # left as it is).
      Cms::Plugins.block_types :oldmill, Oldmill::BLOCK_TYPES
      Website.register :oldmill, name: "Old Mill Brewpub & Grill", version: Oldmill::VERSION,
        views: Oldmill::Engine.root.join("app/views"),
        # Settings › Themes › Customize. The mill is stone and lamplight by
        # default; a visitor can still flip it with the sun/moon button.
        design: [
          {name: "color_scheme", label: "Colors", type: "select", default: "dark",
           options: {"dark" => "dark", "light" => "light"},
           help: "What a first-time visitor sees: the dark mill, or limestone by day."},
          {name: "theme_toggle", label: "Let visitors switch between dark and light", type: "boolean", default: true}
        ]
    end
  end
end
