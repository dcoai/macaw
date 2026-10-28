defmodule Macaw do
  @moduledoc """
  Macaw's core: composing pages out of independent components that share typed data and
  interactive state through one source contract (spec/00).

  `macaw` v0.1.0 holds the first slice: **surfaces with a grid**, validated and rendered
  complete without a socket (spec/06 §3), and the built-in table.

    * `Macaw.Surface`: the surface document, its cells, validation, fetching and rendering;
    * `Macaw.Grid`: the 12-column grid, its reading order, classes and static stylesheet;
    * `Macaw.Registry`: a host's registry of components, built from enabled packages;
    * `Macaw.Builtin`: the built-in components, a package like any other.

  It is built on `macaw_layers` (documents and themes), `macaw_data` (data and sources) and
  `macaw_component` (the component contract), which other libraries use without the core.
  """
end
