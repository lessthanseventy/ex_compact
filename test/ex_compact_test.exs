defmodule ExCompactTest do
  use ExUnit.Case, async: true

  test "compact/1 handles a mix of patterns in one text block" do
    input = """
    ** (RuntimeError) oops
        (my_app 0.1.0) lib/my_app/foo.ex:1: MyApp.Foo.bar/0
        (stdlib 5.0) gen_server.erl:100: :gen_server.handle_msg/6
        (stdlib 5.0) proc_lib.erl:250: :proc_lib.init_p_do_apply/3

    Some normal text in between.

    [error] GenServer MyApp.Worker terminating
    ** (RuntimeError) broke
        (my_app 0.1.0) lib/my_app/worker.ex:42: MyApp.Worker.handle_info/2
        (stdlib 5.0) gen_server.erl:1123: :gen_server.try_dispatch/4
    Last message: :tick
    State: %{x: 1}
    """
    result = ExCompact.compact(input, app: :my_app)
    # Both patterns compacted
    assert result =~ "MyApp.Foo.bar/0"
    assert result =~ "MyApp.Worker.handle_info/2"
    # OTP noise removed from both
    refute result =~ ":proc_lib.init_p_do_apply/3"
    # Normal text preserved
    assert result =~ "Some normal text in between."
  end

  test "compact/1 returns unchanged text when nothing matches" do
    input = "Hello world\nNothing to see here."
    assert ExCompact.compact(input) == input
  end

  test "compact/1 handles compiler warnings mixed with test output" do
    input = """
    Compiling 3 files (.ex)

    warning: variable "x" is unused (if the variable is not meant to be used, prefix it with an underscore)
      lib/my_app/foo.ex:10:5

    ....F...

      1) test something (MyApp.FooTest)
         test/my_app/foo_test.exs:5
         Assertion with == failed
         left:  1
         right: 2

    Finished in 0.1 seconds (0.1s async, 0.0s sync)
    8 tests, 1 failure

    Randomized with seed 12345
    """
    result = ExCompact.compact(input, [])
    # Failure preserved
    assert result =~ "test something (MyApp.FooTest)"
    assert result =~ "foo_test.exs:5"
    # Noise stripped
    refute result =~ "Randomized with seed"
  end

  test "compact/1 handles Ecto queries mixed with other output" do
    input = """
    [debug] QUERY OK source="users" db=2.5ms
    SELECT u0."id" FROM "users" AS u0
    ** (RuntimeError) something failed
        (my_app 0.1.0) lib/my_app/foo.ex:1: MyApp.Foo.bar/0
        (stdlib 5.0) gen_server.erl:100: :gen_server.handle_msg/6
    """
    result = ExCompact.compact(input, app: :my_app)
    refute result =~ "QUERY OK"
    assert result =~ "RuntimeError"
    assert result =~ "MyApp.Foo.bar/0"
  end
end
