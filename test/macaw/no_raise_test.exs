defmodule Macaw.NoRaiseTest do
  # Errors are values (spec/00 §4.3, #243): a reader of a document or of attrs written by a
  # host answers `{:ok, value}` or `{:error, faults}` on any input, and never raises. The
  # generators mix the readers' own keys and words with junk at every depth, so the
  # input reaches past the first type check.
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Macaw.{Registry, Surface}
  alias Macaw.Test.Rows

  @now ~U[2026-11-01 00:00:00Z]
  @registry Registry.new!([Macaw.Builtin])

  defp sources do
    rows = for i <- 1..5, do: %{"t" => @now, "v" => i * 1.0, "host" => "h#{i}"}
    %{"lat" => {%Rows{rows: rows, name: "lat"}, nil}}
  end

  # Any term a host might write: scalars, the readers' own atoms, and lists, maps and
  # tuples of them.
  defp junk do
    leaf =
      one_of([
        constant(nil),
        boolean(),
        integer(-3..30),
        float(min: -2.0, max: 2.0),
        string(:alphanumeric, max_length: 6),
        member_of(["", "lat", "t", "v", "host", "macaw.table", "asc", "desc", "a b", "$x"]),
        member_of([:grid, :stack, :flow, :areas, :columns, :order, :template, :area, :x, :w]),
        atom(:alphanumeric)
      ])

    tree(leaf, fn child ->
      one_of([
        list_of(child, max_length: 3),
        map_of(one_of([child, key()]), child, max_length: 3),
        tuple({child, child}),
        list_of(tuple({key(), child}), max_length: 3)
      ])
    end)
  end

  defp key do
    member_of([
      :name,
      :title,
      :layout,
      :cells,
      :component,
      :kind,
      :settings,
      :slots,
      :source,
      :fields,
      :params,
      :place,
      :x,
      :y,
      :w,
      :h,
      :area,
      :columns,
      :order,
      :template
    ])
  end

  defp maybe(gen), do: one_of([gen, junk()])

  defp place do
    maybe(
      optional_map(%{
        x: maybe(integer(-1..30)),
        y: maybe(integer(-1..30)),
        w: maybe(integer(0..30)),
        h: maybe(integer(0..30)),
        area: maybe(member_of(["a", "b", "t"]))
      })
    )
  end

  defp slot do
    maybe(
      optional_map(%{
        source: maybe(constant("lat")),
        fields: maybe(map_of(member_of(["x", "y", "label", "columns"]), junk(), max_length: 2)),
        params: maybe(map_of(string(:alphanumeric, max_length: 3), junk(), max_length: 2))
      })
    )
  end

  defp cell do
    maybe(
      optional_map(%{
        component: maybe(member_of(["macaw.table", "macaw.nope", "nope"])),
        kind: junk(),
        settings: maybe(map_of(member_of(["sort", "order", "x"]), junk(), max_length: 2)),
        slots: maybe(map_of(member_of(["rows", "x"]), slot(), max_length: 2)),
        source: maybe(constant("lat")),
        fields: junk(),
        params: junk(),
        place: place()
      })
    )
  end

  defp layout do
    kind = member_of([:grid, :stack, :flow, :areas, :nope])

    options =
      list_of(
        tuple({member_of([:columns, :order, :template]), maybe(list_of(maybe(list_of(junk()))))}),
        max_length: 2
      )

    maybe(one_of([kind, tuple({kind, options}), tuple({kind, junk()})]))
  end

  defp surface do
    optional_map(%{
      name: maybe(member_of(["ops", "a b", ""])),
      title: junk(),
      layout: layout(),
      cells:
        maybe(
          one_of([
            map_of(member_of(["t", "u", "a", "b"]), cell(), max_length: 3),
            list_of(cell(), max_length: 3)
          ])
        )
    })
  end

  defp value?({:ok, _value}), do: true
  defp value?({:error, [_ | _]}), do: true
  defp value?(_other), do: false

  @tag verifies: "errors-values"
  property "a surface's attrs answer a value from new/1, validate/3 and show/2, never a raise" do
    check all(attrs <- one_of([surface(), junk()]), max_runs: 300) do
      result = Surface.new(attrs)
      assert value?(result), inspect(result)

      env = [sources: sources(), registry: @registry, now: @now, ceiling: 1_000]
      assert value?(Surface.show(attrs, env))

      with {:ok, surface} <- result do
        assert value?(Surface.validate(surface, @registry, sources()))
      end
    end
  end

  @tag verifies: "errors-values"
  property "a surface's document answers a value from from_map/1 and from_json/2, never a raise" do
    check all(attrs <- surface(), version <- maybe(constant(1)), max_runs: 300) do
      assert value?(Surface.from_map(%{version: version, surface: attrs}))
      assert value?(Surface.from_map(attrs))

      # The JSON a host could be sent: string keys, tags spelled as text.
      json = JSON.encode!(%{"$version" => jsonable(version), "surface" => jsonable(attrs)})
      assert value?(Surface.from_json(json))
    end
  end

  @tag verifies: "errors-values"
  property "any text is a value from from_json/2" do
    check all(text <- one_of([string(:printable, max_length: 40), constant("{\"surface\":")])) do
      assert value?(Surface.from_json(text))
    end
  end

  # A term as JSON could carry it: atoms as text, tuples as lists, keys as strings.
  defp jsonable(term) when is_map(term),
    do: Map.new(term, fn {k, v} -> {json_key(jsonable(k)), jsonable(v)} end)

  defp jsonable(term) when is_list(term), do: Enum.map(term, &jsonable/1)
  defp jsonable(term) when is_tuple(term), do: term |> Tuple.to_list() |> jsonable()

  defp jsonable(term) when is_atom(term) and term not in [nil, true, false],
    do: Atom.to_string(term)

  defp jsonable(term), do: term

  defp json_key(key) when is_binary(key), do: key
  defp json_key(key), do: JSON.encode!(key)
end
