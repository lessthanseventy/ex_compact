defmodule ExCompact.Patterns.CompilerWarningTest do
  use ExUnit.Case, async: true

  alias ExCompact.Patterns.CompilerWarning

  @simple_warnings """
  Compiling 12 files (.ex)

  warning: function do_thing/1 is unused
    lib/my_app/helpers.ex:88:3

  warning: variable "result" is unused (if the variable is not meant to be used, prefix it with an underscore)
    lib/my_app/worker.ex:42:7

  """

  @boxdraw_warning """
  warning: MyApp.OldModule.deprecated_fn/2 is deprecated. Use MyApp.NewModule.better_fn/2 instead
  │
  │     MyApp.OldModule.deprecated_fn(a, b)
  │
  └─ lib/my_app/caller.ex:15:5

  """

  test "compacts simple warnings to one line each" do
    result = CompilerWarning.compact(@simple_warnings, [])
    assert result =~ "warning: function do_thing/1 is unused"
    assert result =~ "lib/my_app/helpers.ex:88:3"
    assert result =~ "warning: variable \"result\" is unused"
    assert result =~ "lib/my_app/worker.ex:42:7"
    # Should not have the parenthetical suggestion
    refute result =~ "if the variable is not meant to be used"
  end

  test "compacts box-drawing deprecation warnings" do
    result = CompilerWarning.compact(@boxdraw_warning, [])
    assert result =~ "deprecated_fn/2 is deprecated"
    assert result =~ "lib/my_app/caller.ex:15:5"
    # Box drawing stripped
    refute result =~ "│"
    refute result =~ "└"
  end

  test "passes through text with no warnings" do
    input = "Normal output here"
    assert CompilerWarning.compact(input, []) == input
  end
end
