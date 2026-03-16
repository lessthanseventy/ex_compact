defmodule ExCompact.Patterns.EctoLogTest do
  use ExUnit.Case, async: true

  alias ExCompact.Patterns.EctoLog

  @sample_output """
  [debug] QUERY OK source="users" db=2.5ms decode=0.5ms queue=0.1ms idle=1000.0ms
  SELECT u0."id", u0."name" FROM "users" AS u0 WHERE (u0."id" = $1) [42]
  [debug] QUERY OK source="posts" db=1.2ms
  SELECT p0."id", p0."title" FROM "posts" AS p0 WHERE (p0."user_id" = $1) [42]
  Some important output here
  [debug] QUERY ERROR source="users" db=5.0ms
  INSERT INTO "users" ("name") VALUES ($1) ["bad"]
  More important output
  """

  test "strips debug QUERY OK lines and their SQL" do
    result = EctoLog.compact(@sample_output, [])
    refute result =~ "QUERY OK"
    refute result =~ "SELECT u0"
    refute result =~ "SELECT p0"
  end

  test "keeps QUERY ERROR lines" do
    result = EctoLog.compact(@sample_output, [])
    assert result =~ "QUERY ERROR"
    assert result =~ "INSERT INTO"
  end

  test "preserves non-Ecto output" do
    result = EctoLog.compact(@sample_output, [])
    assert result =~ "Some important output here"
    assert result =~ "More important output"
  end

  test "passes through text with no Ecto logs" do
    input = "Normal output\nno queries here"
    assert EctoLog.compact(input, []) == input
  end
end
