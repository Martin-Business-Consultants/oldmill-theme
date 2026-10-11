# frozen_string_literal: true

module Oldmill
  # A theme is an engine like a plugin: its views and helpers join the app's,
  # its assets join Propshaft's load path (app/assets/*/oldmill, so they
  # never collide with the admin's), and it registers with Website, which
  # turns the public site on. Its scripts get an importmap of their own
  # (config/importmap.rb), so the admin's never reach a visitor.
  class Engine < ::Rails::Engine
    initializer "oldmill.importmap", before: "importmap" do |app|
      app.config.assets.paths << root.join("app/javascript")
    end

    config.to_prepare do
      # A plugin too, so Settings › Plugins installs it from its GitHub
      # release, updates it, and switches the site on and off.
      Cms::Plugins.register :oldmill, name: "Old Mill Brewpub & Grill", version: Oldmill::VERSION,
        description: "The oldmillbrew.com website, as a theme: switch it off and the CMS is headless.",
        author: "Martin Business Consultants", enabled_by_default: true, requires: ">= 1.14",
        homepage: "https://github.com/Martin-Business-Consultants/oldmill-theme"
      Website.register :oldmill, name: "Old Mill Brewpub & Grill", version: Oldmill::VERSION,
        views: Oldmill::Engine.root.join("app/views"),
        importmap: Importmap::Map.new.draw(Oldmill::Engine.root.join("config/importmap.rb")),
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
