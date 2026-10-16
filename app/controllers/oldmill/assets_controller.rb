# frozen_string_literal: true

module Oldmill
  # The theme's own files (its stylesheet, scripts, fonts and images), served
  # from the theme at /_oldmill/<name> rather than through the asset
  # pipeline. A theme installed from Settings › Plugins depends on the
  # install compiling its assets when it boots, and one that can't answers
  # every page with a 500 when the layout links a stylesheet it never
  # compiled. Served from here, the site works wherever the theme loads.
  # Addresses carry the file's digest (oldmill_asset_path, in the theme's
  # helper), so each can be cached for good.
  class AssetsController < ActionController::Base
    TYPES = {".css" => "text/css", ".js" => "text/javascript", ".woff2" => "font/woff2", ".woff" => "font/woff",
             ".webp" => "image/webp", ".avif" => "image/avif", ".png" => "image/png", ".jpg" => "image/jpeg",
             ".jpeg" => "image/jpeg", ".gif" => "image/gif", ".svg" => "image/svg+xml", ".ico" => "image/x-icon"}.freeze

    # Public, static files: no session, and scripts load from <script type="module">
    # (Rails would otherwise refuse a .js response to a GET as cross-origin).
    skip_forgery_protection

    # The asked-for name is only compared with the index's names: the file
    # sent is always one of the theme's.
    def show
      wanted = params[:path].to_s
      _name, file = self.class.files.find { |name, _file| name == wanted }
      return head(:not_found) unless file

      response.headers["Cache-Control"] = params[:v].present? ? "public, max-age=31536000, immutable" : "public, max-age=300"
      response.headers["Access-Control-Allow-Origin"] = "*" if file.extname.start_with?(".woff")
      # An SVG opened on its own runs no script and loads nothing.
      response.headers["Content-Security-Policy"] = "default-src 'none'; style-src 'unsafe-inline'" if file.extname == ".svg"
      send_file file, type: TYPES.fetch(file.extname, "application/octet-stream"), disposition: :inline
    end

    # Every file the theme serves, by its name ("site.css", "logo.png"): the
    # theme's own asset directories, indexed once in production (afresh each
    # time while you work on it, so a new file shows up). A name is only ever
    # looked up here, never turned into a path.
    DIRECTORIES = %w[app/assets/stylesheets/oldmill app/assets/fonts/oldmill app/assets/images/oldmill app/javascript/oldmill]
      .map { Oldmill::Engine.root.join(it) }.freeze

    def self.files
      return @files ||= index.freeze if Rails.env.production?

      index
    end

    def self.index
      DIRECTORIES.reverse.each_with_object({}) do |directory, index|
        directory.glob("**/*").select { it.file? && TYPES.key?(it.extname) }.each { index[it.relative_path_from(directory).to_s] = it }
      end
    end

    def self.find(name) = files[name.to_s]
  end
end
