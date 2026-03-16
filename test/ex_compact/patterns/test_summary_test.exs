defmodule ExCompact.Patterns.TestSummaryTest do
  use ExUnit.Case, async: true

  alias ExCompact.Patterns.TestSummary

  @verbose_run """
  Running ExUnit with seed: 54321, max_cases: 16

  ............................................................................................
  ............................................................................................
  ............................................................................................
  .......F.....F.............

    1) test something (MyApp.SomeTest)
       test/my_app/some_test.exs:10
       Assertion with == failed
       left:  1
       right: 2

    2) test other thing (MyApp.OtherTest)
       test/my_app/other_test.exs:20
       ** (MatchError) no match

  Finished in 2.5 seconds (1.0s async, 1.5s sync)
  300 tests, 2 failures

  Randomized with seed 54321
  """

  test "compacts verbose test run to just failures and summary" do
    result = TestSummary.compact(@verbose_run, [])
    assert result =~ "test something (MyApp.SomeTest)"
    assert result =~ "test other thing (MyApp.OtherTest)"
    assert result =~ "300 tests, 2 failures"
    refute result =~ "....."
    refute result =~ "Randomized with seed"
    refute result =~ "Running ExUnit with seed"
  end

  test "passes through text with no test summary" do
    input = "Normal output"
    assert TestSummary.compact(input, []) == input
  end
end
