require "test_helper"

class Nibble::Forms::ContentOptionsCheckTest < ActiveSupport::TestCase
  setup do
    @themes = Pathname(Dir.mktmpdir("nibble-themes"))
    theme_file("collections/services.yml", title: "Services", route: "/services/{slug}", blueprints: [ "service" ], taxonomies: [ "kinds" ])
    theme_file("blueprints/collections/services/service.yml", title: "Service", tabs: { main: { sections: [ { fields: [
      { handle: "title", field: { type: "text" } },
      { handle: "code", field: { type: "text" } },
      { handle: "steps", field: { type: "grid", fields: [ { handle: "name", field: { type: "text" } } ] } },
      { handle: "kinds", field: { type: "terms", taxonomies: [ "kinds" ] } },
      { handle: "related", field: { type: "entries", collections: [ "services" ] } }
    ] } ] } })
    theme_file("collections/areas.yml", title: "Areas", route: "/areas/{slug}", structure: { max_depth: 2 }, blueprints: [ "area" ])
    theme_file("blueprints/collections/areas/area.yml", title: "Area", tabs: { main: { sections: [ { fields: [ { handle: "title", field: { type: "text" } } ] } ] } })
    theme_file("taxonomies/kinds.yml", title: "Kinds", route: "/kinds/{slug}", blueprints: [ "kind" ])
    theme_file("blueprints/taxonomies/kinds/kind.yml", title: "Kind", tabs: { main: { sections: [ { fields: [ { handle: "title", field: { type: "text" } } ] } ] } })
  end

  teardown { FileUtils.rm_rf(@themes) }

  def theme_file(relative, content)
    path = @themes.join("check", "schema", relative)
    FileUtils.mkdir_p(path.dirname)
    path.write(content.deep_stringify_keys.to_yaml)
  end

  def problems(file)
    config = Nibble::Config.new({ "theme" => "check", "locales" => [ { "code" => "en", "default" => true } ] }, themes_path: @themes,
      site_schema_path: Rails.root.join("test/nibble_themes/no_site_schema"))
    Nibble::Check.run(config:, static: true).problems.map { |problem| problem.to_s.sub(%r{\A.*/check/schema/}, "") }
      .grep(/\A#{Regexp.escape(file)}/).map { |problem| problem.delete_prefix("#{file}: ") }
  end

  def choice(options, type: "select", **extra) = { type:, options:, **extra }

  test "options from content, a tree parent, a relationship parent and an `in` message pass" do
    theme_file("forms/enquiry.yml", title: "Enquiry", fields: [
      { handle: "kind", field: choice({ from: "terms:kinds" }, type: "checkboxes") },
      { handle: "service", field: choice({ from: "entries:services", value: "code", label: "title", sort: "title", limit: 50, parent: { field: "kind", by: "kinds" } },
                                         messages: { in: "Choose a service of that kind." }) },
      { handle: "region", field: choice({ from: "entries:areas", where: { parent_id: { null: true } } }) },
      { handle: "suburb", field: choice({ from: "entries:areas", parent: "region" }, type: "radio") },
      { handle: "size", field: choice({ from: "Small", to: "Large" }) }
    ])

    assert_empty problems("forms/enquiry.yml")
  end

  test "check refuses a source that isn't a query, a missing or non-scalar value or label, and a limit past 200" do
    theme_file("forms/broken.yml", title: "Broken", fields: [
      { handle: "nowhere", field: choice({ from: "entries:missing" }) },
      { handle: "filtered", field: choice({ from: "entries:services", where: { code: "a" } }) },
      { handle: "valued", field: choice({ from: "entries:services", value: "steps", label: "nope", limit: 500, order: "title" }) }
    ])

    found = problems("forms/broken.yml")
    [
      "field 'nowhere' options.from: no collection 'missing'",
      "field 'filtered' options.where.code: isn't filterable (only columns and relationship fields are)",
      "field 'valued' options.order isn't an options key; use from, where, not, sort, limit, value, label, parent",
      "field 'valued' options.limit must be a whole number from 1 to 200",
      "field 'valued' options names 'steps', which isn't a column or a single-value field of entries:services",
      "field 'valued' options names 'nope', which isn't a column or a single-value field of entries:services"
    ].each { |message| assert_includes found, message }
  end

  test "check refuses a parent that isn't a content choice, a tree across collections, a `by` that can't point at the parent, and a circle" do
    theme_file("forms/parents.yml", title: "Parents", fields: [
      { handle: "name", field: { type: "text" } },
      { handle: "kind", field: choice({ from: "terms:kinds" }) },
      { handle: "service", field: choice({ from: "entries:services" }) },
      { handle: "by_text", field: choice({ from: "entries:services", parent: "name" }) },
      { handle: "flat_tree", field: choice({ from: "entries:services", parent: "service" }) },
      { handle: "cross_tree", field: choice({ from: "entries:areas", parent: "service" }) },
      { handle: "wrong_by", field: choice({ from: "entries:services", parent: { field: "kind", by: "related" } }) },
      { handle: "first", field: choice({ from: "entries:areas", parent: "second" }) },
      { handle: "second", field: choice({ from: "entries:areas", parent: "first" }) }
    ])

    found = problems("forms/parents.yml")
    [
      "field 'by_text' options.parent names 'name', which isn't another choice field of this form with options from content",
      "field 'flat_tree' options.parent 'service' must take options from the same structured collection to follow the tree; give `by` to follow a relationship instead",
      "field 'cross_tree' options.parent 'service' must take options from the same structured collection to follow the tree; give `by` to follow a relationship instead",
      "field 'wrong_by' options.parent.by 'related' must be a terms field of entries:services that can point at terms:kinds",
      "field 'first' options.parent goes round in a circle: first → second → first"
    ].each { |message| assert_includes found, message }
  end

  test "options from content belong to a form only: an entry or a global has no visitor's locale or published view to draw them from" do
    theme_file("collections/posts.yml", title: "Posts", route: "/posts/{slug}", blueprints: [ "post" ])
    theme_file("blueprints/collections/posts/post.yml", title: "Post", tabs: { main: { sections: [ { fields: [
      { handle: "title", field: { type: "text" } },
      { handle: "service", field: choice({ from: "entries:services" }) }
    ] } ] } })
    theme_file("globals/site.yml", title: "Site", blueprint: { title: "Site", tabs: { main: { sections: [ { fields: [
      { handle: "featured", field: choice({ from: "entries:services" }) }
    ] } ] } } })

    assert_includes problems("blueprints/collections/posts/post.yml"), "field 'service' takes its options from content, which only a form's field can"
    assert_includes problems("globals/site.yml"), "field 'featured' takes its options from content, which only a form's field can"
  end
end
