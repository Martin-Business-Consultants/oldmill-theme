# frozen_string_literal: true

require "rails_helper"
require_relative "../support/oldmill_content"
require_relative "../support/oldmill_browser"

# forms.js in a browser: a form sends without leaving the page, says so,
# and the answer is in Submissions with the visit's attribution; one the
# Forms plugin refuses shows why, beside the field.
RSpec.describe "The theme's forms", type: :system, website: true do
  before do
    skip "no Forms plugin" unless defined?(Form)

    switch_plugin :forms, on: true
    Website.themes.each_key { |key| switch_plugin key.to_sym, on: key == "oldmill" if Cms::Plugins.manifests.key?(key.to_sym) }
    Oldmill::Content.load_fresh_site!
    fields = [
      {"name" => "name", "label" => "Your name", "type" => "text", "required" => true},
      {"name" => "email", "label" => "Email", "type" => "email", "required" => true},
      {"name" => "topic", "label" => "Topic", "type" => "select", "required" => true,
       "options" => [{"value" => "general", "label" => "General inquiry"}, {"value" => "press", "label" => "Press"}]},
      {"name" => "message", "label" => "Message", "type" => "textarea"},
      {"name" => "utm_source", "label" => "Source", "type" => "text"}
    ]
    Form.find_by(slug: "contact")&.destroy!
    Form.create!(slug: "contact", title: "Contact", status: "published", submit_label: "Send it", success_message: "Got it, thanks.", fields:)
    Page.create!(slug: "contact", path: "contact", title: "Contact", status: "published", locale: "en",
      blocks: [{"type" => "form", "version" => 1, "data" => {"form" => "contact", "heading" => "Write to us"}}])
  end

  it "sends a form in place, with the visit's attribution" do
    visit "/contact?utm_source=newsletter"
    fill_in "Your name", with: "Ann"
    fill_in "Email", with: "ann@example.com"
    select "Press", from: "Topic"
    click_on "Send it"

    expect(page).to have_css(".form__status[data-kind=sent]", text: "Got it, thanks.")
    expect(page).to have_current_path("/contact?utm_source=newsletter")
    submission = Form.find_by!(slug: "contact").submissions.last
    expect(submission.data).to include("name" => "Ann", "email" => "ann@example.com", "topic" => "press", "utm_source" => "newsletter")
  end

  it "shows the plugin's reasons beside the fields" do
    visit "/contact"
    fill_in "Your name", with: "Ann"
    fill_in "Email", with: "ann@example.com"
    select "Press", from: "Topic"
    # Past the browser's own check, so the server's answer is the one shown.
    page.execute_script("document.querySelector('[name=email]').type = 'text'; document.querySelector('[name=email]').value = 'not-an-email'")
    click_on "Send it"

    expect(page).to have_css(".form__status[data-kind=error]")
    expect(page).to have_css(".form__error", text: "is not a valid email")
    expect(Form.find_by!(slug: "contact").submissions).to be_empty
  end
end
