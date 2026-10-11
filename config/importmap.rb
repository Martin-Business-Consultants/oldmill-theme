# frozen_string_literal: true

# The website's scripts (Website.theme.importmap), apart from the admin's.
pin "oldmill", to: "oldmill/site.js"
pin_all_from Oldmill::Engine.root.join("app/javascript/oldmill"), under: "oldmill", to: "oldmill"
