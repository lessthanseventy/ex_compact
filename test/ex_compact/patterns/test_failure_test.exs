defmodule ExCompact.Patterns.TestFailureTest do
  use ExUnit.Case, async: true

  alias ExCompact.Patterns.TestFailure

  @sample_failure """
  Compiling 3 files (.ex)

  ..........

    1) test creates a user (MyApp.AccountsTest)
       test/my_app/accounts_test.exs:10
       Assertion with == failed
       code:  assert result == {:ok, %User{}}
       left:  {:error, %Ecto.Changeset{}}
       right: {:ok, %User{}}
       stacktrace:
         test/my_app/accounts_test.exs:15: (test)

    2) test updates a user (MyApp.AccountsTest)
       test/my_app/accounts_test.exs:20
       ** (MatchError) no match of right hand side value: {:error, :not_found}
       stacktrace:
         test/my_app/accounts_test.exs:25: (test)

  Finished in 0.3 seconds (0.1s async, 0.2s sync)
  50 tests, 2 failures

  Randomized with seed 12345
  """

  test "compacts test failures to essentials" do
    result = TestFailure.compact(@sample_failure, [])
    assert result =~ "test creates a user"
    assert result =~ "accounts_test.exs:10"
    assert result =~ "left:"
    assert result =~ "right:"
    refute result =~ "Compiling 3 files"
    refute result =~ ".........."
    refute result =~ "Randomized with seed"
  end

  test "passes through text with no test failures" do
    input = "Normal output here"
    assert TestFailure.compact(input, []) == input
  end
end
