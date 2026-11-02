# 9. Themes and styles

Macaw renders classes and leaves the look to stylesheets, with one rule: **colors come
from the theme**. This chapter covers themes (`Macaw.Layers.Theme`), compiling them to a
stylesheet, colors, and the stylesheets a surface needs.

**What you'll learn:**

- the built-in themes and what a theme holds: series, furniture, roles, ramps, fonts;
- resolving a theme's values for CSS and for canvases;
- building your own theme, and the contracts it's held to;
- compiling themes to one static stylesheet (`Macaw.Layers.Theme.Sheet`);
- themes as documents (`Macaw.Layers.Theme.Document`);
- colors as terms (`Macaw.Layers.Color`): literals, typed colors, data colors and
  contrast;
- styling surfaces and drawn-state notices.

## What a theme holds

A theme is a struct of named **slots**:

- `series_1` … `series_n`: categorical colors, which promise only to be *distinct*;
- the **furniture**: `axis`, `grid`, `text`, `background`, `surface`;
- the five **roles**: `good`, `warning`, `bad`, `info`, `neutral`, which carry *meaning*
  (a schema's `status` names them, chapter 3);
- `font_family`, `font_size`, `label_size`, `title_size`;
- four **ramps** with fixed meanings: `status`, `thermal`, `diverging`, `sequential`;
- a color table of names, and a palette of whole styles for components that draw.

Its colors are **color terms**, `%Macaw.Layers.Color{}` (below), and **every name in it
is a string**: the theme's own name, its slots, roles, ramps, colors and styles. Every
function that takes a name takes either spelling, so `:warning` and `"warning"` are one
name; what a theme answers is the string. Four are built in:

```elixir
alias Macaw.Layers.Theme

{Theme.default().name, Theme.dark().name, Theme.color_safe().name, Theme.print().name}
#=> {"default", "dark", "color_safe", "print"}

{Theme.builtin(:dark) == Theme.dark(), Theme.builtin("dark") == Theme.dark(), Theme.builtin(:neon)}
#=> {true, true, nil}

{Theme.role_names(), Theme.ramp_names()}
#=> {["good", "warning", "bad", "info", "neutral"], ["status", "thermal", "diverging", "sequential"]}
```

`color_safe` uses a blue-orange-red status ramp that survives the common color-vision
deficiencies; `print` is for paper, with hatched role fills.

## Resolving values

`Theme.resolve(theme, slot, mode)` is the one way anything reads a theme:

- `:css` gives a custom-property reference with the theme's value as its fallback, for
  HTML and SVG output;
- `:literal` gives the value itself, for a canvas or an image: a color as a
  `%Macaw.Layers.Color{}`, which `Macaw.Layers.Color.to_css/1` writes as CSS text.

```elixir
import Macaw.Layers.Color, only: [sigil_RGB: 2]
alias Macaw.Layers.Color

theme = Theme.default()

{Theme.resolve(theme, :axis, :css), Theme.resolve(theme, :font_size, :css)}
#=> {"var(--mw-axis, #666666)", "var(--mw-font-size, 10px)"}

warning = Theme.resolve(theme, :warning, :literal)
{warning == ~RGB"#bd7407", Color.to_css(warning)}
#=> {true, "#bd7407"}

{Theme.resolve(theme, {:series, 11}, :css), Theme.resolve(theme, :red, :css)}
#=> {"var(--mw-series-1, #3b6fa8)", "var(--mw-red, #c23238)"}
```

Series positions cycle: on ten colors, `{:series, 11}` is `series_1`. Because a `:css`
reference carries its fallback, output renders in its theme even without a stylesheet,
and a stylesheet class on any ancestor switches it. A component reads its theme from
its context (`assigns.context.theme`), which a surface fills from `render`'s `theme:`
option. `Theme.slots/1` lists a theme's slots, and `css_name/1` gives a slot's property:

```elixir
Theme.css_name(:series_1)
#=> "--mw-series-1"
```

`Theme.ink/2` picks a readable text color to draw on a given color, always at least
4.5:1 contrast:

```elixir
{Theme.ink(theme, ~RGB"#3b6fa8"), Theme.ink(theme, ~RGB"#eeeeee")}
#=> {~RGB"#ffffff", ~RGB"#333333"}
```

(`~RGB"#ffffff"` in a `#=>` line is the struct the sigil builds:
`%Macaw.Layers.Color{r: 255.0, g: 255.0, b: 255.0, opacity: 1.0}`, as `iex` shows it.)

### Ramps and styles

A component that draws data reads more than single colors. `Theme.ramp/3` is a color
at a position along a ramp, for heat maps and gradients; `Theme.style/2` is a whole style
from the palette (fill, stroke, dash, marker), so a series or a role looks the same in
every component:

```elixir
Theme.ramp(theme, :thermal, 0.25)
#=> ~RGB"#8da5cb"

Theme.style(theme, :warning)
#=> %{fill: %{color: {:color, "warning"}, type: :solid},
#    marker: %{shape: :triangle},
#    stroke: %{color: {:color, "warning"}, dash: "6 3", type: :solid}}

Theme.style_names(theme) |> Enum.take(3)
#=> ["style_1", "style_2", "style_3"]
```

A style's words (`:solid`, `:triangle`) are atoms of a closed vocabulary, kept as given;
its names, such as the color it paints with, are strings.

A role's style carries a dash and a marker shape as well as a color, its **cue**, so
meaning never rests on color alone.

## Your own theme

`Theme.new/1` is the default theme with your fields replaced; `colors`, `ramps`, `styles`
and `defaults` merge key by key. `merge/2` does the same over any theme. Its colors are
color terms, and its names may be atoms or strings, normalized to strings once, here. A
theme of your own may add names to its color table:

```elixir
house =
  Theme.new(
    name: :house,
    series: [~RGB"#0b5394", ~RGB"#e69138", ~RGB"#38761d"],
    colors: %{brand: ~RGB"#0b5394"},
    font_family: "Inter, sans-serif"
  )

{house.name, Theme.resolve(house, :brand, :css), Theme.color_name?(house, "brand")}
#=> {"house", "var(--mw-brand, #0b5394)", true}

Theme.merge(Theme.dark(), axis: ~RGB"#999999").axis
#=> ~RGB"#999999"
```

**A string is never a color.** `Theme.new(axis: "#999999")` raises `ArgumentError`,
saying to read the text with `Color.parse!/1` or to write `~RGB"#999999"`. A host's
`"info"` in `colors` replaces the library's `info`, since they're one name.

A theme is held to **contracts** when it's built: the status ramp must stay ordered and
distinguishable, roles must keep contrast with the background. A theme that breaks one
raises `ArgumentError` naming it, as does an empty `series`. `Theme.check/1` and
`violations/1` re-check a theme you hold:

```elixir
{Theme.check(house), Theme.violations(house)}
#=> {:ok, []}
```

**A theme refuses unsafe text.** Its stylesheet writes a font family into CSS, and an
adopter writes a palette entry's `class` into markup, so a `font_family` (or an entry's
`font.family`) may not hold `<`, `>`, `/`, `;`, `{`, `}`, `\`, a control character or an
open quote, and a `class` must be CSS class names. `Theme.new/1` and `merge/2` raise
`ArgumentError` for such text, and a theme document answers `{:unsafe, kind}` at its
path (below). `Macaw.Layers.Untrusted` holds the checks, for your own text:

```elixir
alias Macaw.Layers.Untrusted

{Untrusted.font_family?("Inter, sans-serif"), Untrusted.font_family?("Inter;}body{color:red"), Untrusted.class?("wide tall")}
#=> {true, false, true}
```

## One stylesheet for every theme

`Macaw.Layers.Theme.Sheet` compiles themes to custom properties scoped by a class,
`.mw-theme-<name>`. Every element under that class draws in that theme, so a page
switches theme by changing one class. `auto:` adds `.mw-theme-auto`, which follows the
viewer's light or dark preference:

```elixir
alias Macaw.Layers.Theme.Sheet

Sheet.rule(house) |> String.split("\n") |> Enum.take(2)
#=> [".mw-theme-house {", "  --mw-series-1: #0b5394;"]

sheet = Sheet.stylesheet([Theme.default(), Theme.dark(), house], auto: {Theme.default(), Theme.dark()})

~r/^\.mw-theme-[a-z-]+/m |> Regex.scan(sheet) |> List.flatten() |> Enum.uniq()
#=> [".mw-theme-default", ".mw-theme-dark", ".mw-theme-house", ".mw-theme-auto"]

sheet =~ "--mw-bad:"
#=> true
```

`Sheet.auto/2` is the `.mw-theme-auto` rule alone, if you assemble a sheet yourself.
Each rule also has a forced-colors block, so Windows high-contrast mode maps the
furniture to the system's colors. The sheet's bytes depend only on its themes, so serve
it at its content address, like the layouts' and the table's:

```elixir
String.starts_with?(Macaw.Component.Stylesheet.path(sheet), "/assets/")
#=> true
```

## Styling a surface

Put the theme's class on an ancestor of your surfaces, serve the layout's, the table's
and the theme stylesheets, and style the rest of Macaw's classes with the theme's
properties. A minimal stylesheet of your own might be:

```css
.mw-surface { color: var(--mw-text); background: var(--mw-background); font-family: var(--mw-font-family); }
.mw-cell { background: var(--mw-surface); padding: 0.75rem; overflow: auto; }
.mw-drawn { color: var(--mw-text); }
.mw-role-good { color: var(--mw-good); }
.mw-role-warning { color: var(--mw-warning); }
.mw-role-bad { color: var(--mw-bad); }
.mw-role-info { color: var(--mw-info); }
.mw-role-neutral { color: var(--mw-neutral); }
.mw-glyph::before { content: "●"; }
```

The table's own stylesheet, `Macaw.Builtin.Table.stylesheet/0`, styles the table: its
caption, cells, header and select buttons, striped rows, the focus ring and the sorted
column's mark. Every color in it is one of these custom properties (`--mw-text`,
`--mw-background`, `--mw-grid`, `--mw-axis`, `--mw-surface`, `--mw-info`), with the
default theme's value as its fallback, so a theme class on an ancestor restyles it with
no rule of yours:

```elixir
Enum.all?(~w(--mw-text --mw-background --mw-grid --mw-axis --mw-surface --mw-info), &(Macaw.Builtin.Table.stylesheet() =~ "var(#{&1},"))
#=> true
```

`macaw` 0.3.0 ships no styles for the drawn-state notices: the classes are there for
you. Each state's glyph name (`mw-glyph-square`, `mw-glyph-cross`, …) comes
from its role's cue, so you can give each a distinct shape and states never differ by
color alone:

```elixir
{Theme.cue(:warning), Macaw.Component.Drawn.glyph(:down)}
#=> {%{dash: "6 3", glyph: :triangle}, :cross}
```

### Extensions

A theme's color table and palette are **closed**: a name neither the library nor a
registered extension defines is a fault. A package whose components draw things of their
own (a chart's lanes, a map's water) registers the names with an extension, a module of
`Macaw.Layers.Theme.Extension`, giving each a default:

```elixir
defmodule MyApp.ThemeNames do
  @moduledoc "Theme names MyApp's components draw with."
  @behaviour Macaw.Layers.Theme.Extension

  @impl true
  def name, do: "my_app"

  import Macaw.Layers.Color, only: [sigil_RGB: 2]

  @impl true
  def styles, do: %{lane: {:furniture, %{stroke: %{type: :solid, color: {:color, :lane}}}}}

  @impl true
  def colors, do: %{lane: ~RGB"#8a8f99"}
end
```

```elixir
extended = Theme.new(name: :house_lanes, extensions: [MyApp.ThemeNames])
{Theme.resolve(extended, :lane, :css), Theme.color_name?(theme, :lane)}
#=> {"var(--mw-lane, #8a8f99)", false}
```

Extensions are given explicitly, never discovered, and two extensions adding one name
raise `ArgumentError` naming both. An extension may name things by atom or string; the
theme holds strings. One whose styles use words of their own (atoms beyond the
library's) declares them in its optional `words/0`, so the theme's JSON reader can read
them back.

## Themes as documents

A theme is a document too: its value is the `%Theme{}`, and its JSON form, at version
2, is the adapter, read through the same gates as a surface (chapter 8). A literal color
is written `{"$rgb": "#0b5394"}` and a theme color `{"$color": "green"}`. A host's theme
can be stored, edited and shipped:

```elixir
alias Macaw.Layers.Theme.Document

{:ok, theme_json} = Document.to_json(house)
{theme_json =~ ~s("brand":{"$rgb":"#0b5394"}), Document.from_json(theme_json) == {:ok, house}}
#=> {true, true}

Document.from_map(%{theme: "dark"}) == {:ok, Theme.dark()}
#=> true

Document.from_json(~s({"$version":2,"theme":{"name":"x","axis":3}}))
#=> {:error, [{[:theme, :axis], {:type, :color}}]}

Document.from_json(~s({"$version":2,"theme":{"name":"x","font_family":"Inter;}body{color:red"}}))
#=> {:error, [{[:theme, :font_family], {:unsafe, :font_family}}]}
```

`from_map/2` judges a value with no form written or read, so it takes no `limits:`;
those are `from_json/2`'s. A theme whose extensions add words of their own is read back
with `Document.from_json(json, extensions: [...])`.

A theme document stacks over a built-in like any fragment, which is how a host's
theme is a layer over `default`. `Document.to_map/1`, `from_map/2`, `fragment/1` and
`node/1` work as the surface's do.

## Colors

`Macaw.Layers.Color` works with two kinds of color, and both are terms. A **literal
color** is a `%Macaw.Layers.Color{}` struct with float channels, one term for one color
whatever built it. In code, write it with the `~RGB` sigil, checked when the module
compiles; at an edge where text comes in, read it with `parse!/1` (which raises naming
the text) or `parse/1` (`nil` for text that isn't a color), from hex, `rgb()`, `hsl()` or
a CSS name. `to_css/1` writes it back out as CSS, and `to_hex/1` as hex:

```elixir
blue = Color.parse!("#3b6fa8")
{blue == ~RGB"#3b6fa8", Color.to_css(blue), Color.parse("nope")}
#=> {true, "#3b6fa8", nil}

{Color.contrast(blue, ~RGB"#ffffff") > 4.5, Color.value?(blue), Color.value?("#3b6fa8")}
#=> {true, true, false}
```

A string is never a color: no function of a theme or a schema takes `"#3b6fa8"` as one.
A component that writes a theme's literal into markup writes `Color.to_css/1` of it.

A **typed color** is a value that names a theme color and the adjustments made to it,
resolved against a theme only when drawn. It's what a component or a design stores, so
it follows the theme:

```elixir
lighter_red = Color.color(:red) |> Color.lighten(0.3)
#=> {:lighten, {:color, "red"}, 0.3}

{Color.resolve(lighter_red, theme, :literal), Color.resolve(Color.color(:bad), theme, :css)}
#=> {~RGB"#f36160", "var(--mw-bad, #c23238)"}
```

`darken/2`, `alpha/2`, `blend/1` and `contrast/1` build typed colors the same way, and
in `:css` mode they resolve to CSS relative-color expressions over the theme's custom
properties. Lightening and mixing work in OKLab, so steps look even.

`Macaw.Layers.Color.Vision` simulates the common color-vision deficiencies, to check a
palette or a data color the way some of your viewers will see it:

```elixir
alias Macaw.Layers.Color.Vision

Vision.deficiencies()
#=> [:protanopia, :deuteranopia, :tritanopia]

~RGB"#c23238" |> Vision.simulate(:deuteranopia) |> Color.to_hex()
#=> "#807433"
```

### Data colors

A schema may carry **data colors** (a team's color, a `:color` field), as color terms
(chapter 3). They're content, and a component may show one only with a non-color cue (a
label, a glyph) and only when it contrasts with the background. `Theme.data_color/2`
applies the guard, and refuses text as unreadable:

```elixir
{Theme.data_color(theme, ~RGB"#c23238"), Theme.data_color(theme, ~RGB"#ffff00"), Theme.data_color(theme, "#c23238")}
#=> {{:ok, ~RGB"#c23238"}, {:error, {:contrast, 1.07}}, {:error, :unreadable}}
```

Every Macaw page validates against the **`:roles`** profile, where drawing colors are
roles and theme values, never literals. `Theme.check_color/2` applies it:

```elixir
{Theme.check_color(~RGB"#ff0000", :roles), Theme.check_color({:color, "good"}, :roles)}
#=> {{:error, {:literal_color, ~RGB"#ff0000"}}, :ok}
```

## Pitfalls

- **Literal colors in components.** Use `Theme.resolve(context.theme, slot, :css)` or the
  theme's classes; the component kit flags literal colors without a cue.
- **A `<style>` element per component.** Never: one static sheet for all themes, served
  from your origin, keeps a strict Content Security Policy.
- **Color as the only signal.** Pair every role color with a glyph, dash or label.
- **Forgetting the class.** Without `.mw-theme-…` on an ancestor, the `var()` fallbacks
  draw the default theme.
- **Colors as text.** `"#c23238"` is a string; a theme raises for it. Write
  `~RGB"#c23238"`, or `Color.parse!/1` text where it comes in.
- **Matching a theme's names as atoms.** A theme answers `"warning"`, not `:warning`;
  match strings, or pass either spelling to its functions.

## Recap

- A theme holds series, furniture, roles, ramps and fonts, its colors as terms and its
  names as strings; four are built in.
- `resolve/3` gives CSS references with fallbacks, or literals.
- `Theme.new/1` and `merge/2` build your own, held to contracts.
- `Sheet.stylesheet/2` compiles every theme into one static, class-scoped stylesheet.
- A color is a term: `~RGB` and `Color.parse!/1` in, `Color.to_css/1` out; a string
  never is one. Data colors are content, shown with a cue under a contrast guard.

**Further reading:** [the literal color](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md#themes-color-parse), [typed colors](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md#themes-color-typed), [the colors' adapters](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md#themes-color-adapters), [the theme](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md#themes-theme), [a theme as a document](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md#themes-document), [resolution](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md#themes-resolution), [data colors](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md#themes-profile) and [delivery as a stylesheet](https://github.com/dcoai/macaw_layers/blob/main/spec/04-themes.md#themes-delivery) in `macaw_layers`' spec/04.

Next: [chapter 10, Surfaces in a Phoenix app](10-phoenix.md).
