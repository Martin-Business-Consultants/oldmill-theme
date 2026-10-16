# frozen_string_literal: true

# The system specs' headless Chrome, made to start on a machine without root
# where it otherwise can't: Ubuntu 23.10+ refuses it the user namespaces its
# sandbox needs (AppArmor only grants them to /opt/google/chrome), so it runs
# without one; and where the libraries it links (libatk, libgbm…) aren't
# installed, a private copy extracted into the cache is put on the path, as
# the migration does for libvips:
#
#   cd ~/.cache/mbc-theme-migrate/chrome && apt-get download libasound2t64 \
#     libatk1.0-0t64 libatk-bridge2.0-0t64 libatspi2.0-0t64 libgbm1 libxcomposite1 \
#     libxdamage1 libxfixes3 libxrandr2 libxi6 libxres1 && for d in *.deb; do dpkg-deb -x $d root; done
module Oldmill
  module Browser
    LIBS = File.join(ENV.fetch("XDG_CACHE_HOME", File.expand_path("~/.cache")), "mbc-theme-migrate/chrome/root/usr/lib/x86_64-linux-gnu")

    module_function

    def prepare!
      return unless File.directory?(LIBS)
      return if ENV["LD_LIBRARY_PATH"].to_s.split(":").include?(LIBS)

      ENV["LD_LIBRARY_PATH"] = [LIBS, ENV["LD_LIBRARY_PATH"].presence].compact.join(":")
    end

    # Chrome as Selenium Manager finds it: the installed one, else its download.
    def chrome_path
      @chrome_path ||= Selenium::WebDriver::SeleniumManager.binary_paths("--browser", "chrome")["browser_path"].presence
    end
  end
end

RSpec.configure do |config|
  config.before(type: :system) do |example|
    next unless example.metadata[:file_path].start_with?(Oldmill::Engine.root.join("spec").to_s, "./themes/oldmill/")

    Oldmill::Browser.prepare!
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400] do |options|
      options.add_argument("--no-sandbox")
      # With no Chrome installed, Selenium Manager downloads one, but Rails
      # pins chromedriver's path first, so Selenium never asks it where that
      # Chrome is and chromedriver "cannot find Chrome binary".
      options.binary ||= Oldmill::Browser.chrome_path
    end
  end
end
