# Surfex keeps the core's spec, tests and code aligned (spec/00 §4.1). Spec units are the
# spec's headings, identified by their `{#anchor}`; each carries its test hints. The core's
# first slice is built test first (#154); every other unit is deferred to its issue.
[
  sources: ["spec/*.md"],
  heading_ids: ~r/\{#(?<id>[a-z0-9-]+)\}\s*$/,
  tests: ["test/**/*_test.exs"],
  require: [code: [:implements, :excuses], test_hint: [:verifies]],
  adoption: :trust,
  # Type specs document the functions' contracts; the functions carry the relation
  # (a test can exercise a function, never a type).
  classes: [
    {"type", "types document the functions' contracts, which carry the relation"},
    {"index", "the package's root module: documentation that maps the library, no behavior"}
  ],
  rules: [
    %{class: "type", kinds: [:type]},
    %{class: "index", kinds: [:module], name: ~r/\AMacaw\z/}
  ],
  # Other libraries' modules the spec cites: real, outside this tree.
  known_external: %{
    "Macaw.Layers" => "macaw_layers, a library this one depends on",
    "Macaw.Layers.Theme.default/0" => "macaw_layers' default theme",
    "Macaw.Data" => "macaw_data, a library this one depends on",
    "Macaw.Data.Event" => "macaw_data's interaction event",
    "Macaw.Data.Ops" => "macaw_data's operations reached by stored functions",
    "Macaw.Data.Bounded" => "macaw_data's bounded runner",
    "Macaw.Data.Parameter.validate/2" => "macaw_data's parameter validation",
    "Macaw.Data.Source.describer/1" => "macaw_data's describe function",
    "Macaw.Data.Source.Finish.ceiling/2" => "macaw_data's ceiling rule",
    "Macaw.Data.Source.Finish.finish/4" => "macaw_data's finishing",
    "Macaw.Component" => "macaw_component, a library this one depends on",
    "Macaw.Component.budget/4" => "macaw_component's budget dispatch",
    "Macaw.Component.declarations/2" => "macaw_component's declarations dispatch",
    "Macaw.Component.kinds/0" => "macaw_component's kinds",
    "Macaw.Component.Package.components/1" => "macaw_component's package side",
    "Macaw.Component.Package.hooks/1" => "macaw_component's hooks of packages",
    "Macaw.Component.Slot.check/3" => "macaw_component's binding check",
    "Macaw.Live" => "macaw_live, the LiveView runtime, a library above this one",
    "Macaw.Plug" => "macaw_plug, a host library",
    "Macaw.Host" => "macaw_host, a host library",
    "Macaw.Auth" => "macaw_auth, a host library",
    "Macaw.Auth.Ash" => "macaw_auth_ash, a host library",
    "Macaw.Auth.viewer/1" => "macaw_auth's viewer for a host"
  },
  # Modules the spec names that the core doesn't have yet, each with its issue.
  documented_absences: %{
    {"Macaw.Builtin", "spec/05-components.md"} => "built with the table (#163)",
    {"Macaw.Builtin.Table", "spec/05-components.md"} => "built by #163",
    {"Macaw.Grid.classes/1", "spec/06-pages.md"} => "built by #160",
    {"Macaw.Grid.order/1", "spec/06-pages.md"} => "built by #160",
    {"Macaw.Grid.rows/0", "spec/06-pages.md"} => "built by #160",
    {"Macaw.Grid.size/3", "spec/06-pages.md"} => "built by #160",
    {"Macaw.Grid.stylesheet/0", "spec/06-pages.md"} => "built by #160",
    {"Macaw.Grid.stylesheet_path/0", "spec/06-pages.md"} => "built by #160",
    {"Macaw.Surface.fetch/2", "spec/06-pages.md"} => "built by #162",
    {"Macaw.Surface.render/2", "spec/06-pages.md"} => "built by #162",
    {"Macaw.Surface.render/3", "spec/06-pages.md"} => "built by #162",
    {"Macaw.Surface.validate/3", "spec/06-pages.md"} => "built by #161",
    {"Macaw.Builtin", "spec/12-registry.md"} => "built with the table (#163)",
    {"Macaw.Edit", "spec/13-writes.md"} => "macaw_edit, a later library (spec/13)",
    {"Macaw.Edit", "spec/00-overview.md"} => "macaw_edit, a later library (spec/13)",
    {"Macaw.Page", "spec/00-overview.md"} =>
      "named as how the core names concepts; pages are #165",
    {"Macaw.State", "spec/00-overview.md"} =>
      "named as how the core names concepts; state is #164"
  },
  spec_classes: [
    {"orientation",
     "describes the family, its words, its order of work and its open questions; asserts nothing a test checks",
     files: ["spec/00-overview.md", "spec/01-vocabulary.md", "spec/14-open.md", "spec/README.md"]},
    {"moved", "a pointer to a section that moved to macaw_component, which verifies it there"},
    {"architecture",
     "says which library holds what; the libraries' own specs and tests hold the claims"}
  ],
  # Units not built yet are deferred to their issue (`<!-- surfex: deferred #N -->`);
  # `mix surfex.status --issues` asks GitLab whether it is still open.
  issues: [
    command: ["glab", "issue", "view", "{n}", "--repo", "{project}", "-F", "json"],
    state: "state",
    project: "dco-tek/macaw_compose"
  ]
]
