# The raises macaw keeps, read by ci/raises.exs (dco-tek/macaw/macaw#243, spec/00 §4.3).
# Each entry names one function that raises, its class and why:
#
#   %{at: {Module, :fun, arity}, class: :bang | :compile | :mix_task | :invariant, reason: "..."}
#
# A raise outside the list fails the check, and so does an entry that matches no raise.
# Prefer answering a value.
[
  %{
    at: {Macaw.Registry, :new!, 2},
    class: :bang,
    reason: "new/2's twin, for a host's boot: raises exactly where new/2 answers faults"
  },
  %{
    at: {Macaw.Registry, :default!, 0},
    class: :bang,
    reason: "default/0's twin, for a host's boot"
  },
  %{
    at: {Macaw.Registry, :from_config!, 1},
    class: :bang,
    reason: "from_config/1's twin"
  },
  %{
    at: {Macaw.Surface, :build!, 2},
    class: :bang,
    reason: "build/2's twin, for a surface written in code"
  }
]
