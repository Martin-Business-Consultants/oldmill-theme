# frozen_string_literal: true

module Oldmill
  # The block types this theme adds to the core's (BlockType::Defaults in the
  # CMS), as the same hashes. The CMS installs them the first time the theme
  # is switched on (Cms::Plugins.block_types) and leaves them alone after, so
  # an editor's changes to one stay. Each has a partial in
  # app/views/website/blocks. A list is a string_list or a repeater, never a
  # string: a string field turns an empty list into "".
  BLOCK_TYPES = [
    {
      slug: "form", label: "Form", category: "Forms", icon: "ClipboardList",
      description: "One of the site's forms (Forms), with a heading and an intro. Answers go to Submissions.",
      fields: [
        {"name" => "form", "label" => "Form", "type" => "string", "required" => true,
         "help" => "The form's slug, as Forms lists it (e.g. \"contact\")."},
        {"name" => "heading", "label" => "Heading", "type" => "string"},
        {"name" => "body", "label" => "Intro", "type" => "text"}
      ],
      defaults: {"form" => "contact", "heading" => "Get in touch"}
    },
    {
      slug: "faq", label: "FAQ", category: "Content", icon: "CircleHelp",
      description: "Questions and answers, each opening in place. Search engines get them as an FAQ.",
      fields: [
        {"name" => "heading", "label" => "Heading", "type" => "string"},
        {"name" => "body", "label" => "Intro", "type" => "text"},
        {"name" => "items", "label" => "Questions", "type" => "repeater", "required" => true,
         "of" => [
           {"name" => "question", "label" => "Question", "type" => "string", "required" => true},
           {"name" => "answer", "label" => "Answer", "type" => "markdown", "required" => true}
         ]}
      ],
      defaults: {
        "heading" => "Questions",
        "items" => [
          {"question" => "A question your customers ask", "answer" => "A short, direct answer."},
          {"question" => "Another one", "answer" => "Answers can have **markdown** and [links](/)."}
        ]
      }
    }
  ].freeze
end
