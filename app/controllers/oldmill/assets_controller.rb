# frozen_string_literal: true

module Oldmill
  # The theme's own files (its stylesheet, scripts, fonts and images), served
  # from the theme at /_oldmill/<name> rather than through the asset pipeline.
  # A theme installed from Settings › Plugins depends on the install compiling
  # its assets when it boots, and an install that can't (one seen on
  # 2026-10-11 served none of them) answers every page with a 500 when the
  # layout links a stylesheet it never compiled. Served from here, the site
  # works wherever the theme loads. Addresses carry the file's digest
  # (OldmillHelper#oldmill_asset_path), so each can be cached for good.
  class AssetsController < ActionController::Base
    TYPES = {".css" => "text/css", ".js" => "text/javascript", ".woff2" => "font/woff2", ".webp" => "image/webp",
             ".png" => "image/png", ".svg" => "image/svg+xml", ".jpg" => "image/jpeg"}.freeze

    # Public, static files: no session, and scripts load from <script type="module">
    # (Rails would otherwise refuse a .js response to a GET as cross-origin).
    skip_forgery_protection

    # The asked-for name is only compared with the index's names: the file
    # sent is always one of the theme's.
    def show
      wanted = params[:path].to_s
      self.class.files.each do |name, file|
        next unless name == wanted

        response.headers["Cache-Control"] = params[:v].present? ? "public, max-age=31536000, immutable" : "public, max-age=300"
        response.headers["Access-Control-Allow-Origin"] = "*" if file.extname == ".woff2"
        return send_file(file, type: TYPES.fetch(file.extname, "application/octet-stream"), disposition: :inline)
      end
      head :not_found
    end

    # Every file the theme serves, by its name ("site.css", "hero.webp"): the
    # theme's own asset directories, indexed once. A name is only ever looked
    # up here, never turned into a path.
    DIRECTORIES = %w[app/assets/stylesheets/oldmill app/assets/fonts/oldmill app/assets/images/oldmill app/javascript/oldmill]
      .map { Oldmill::Engine.root.join(it) }.freeze

    def self.files
      @files ||= DIRECTORIES.reverse.each_with_object({}) do |directory, index|
        directory.glob("**/*").select { it.file? && TYPES.key?(it.extname) }.each { index[it.relative_path_from(directory).to_s] = it }
      end.freeze
    end

    def self.find(name) = files[name.to_s]
  end
end
