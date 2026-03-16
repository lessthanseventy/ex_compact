defmodule ExCompact.Patterns.Pattern do
  @moduledoc false
  @callback compact(text :: String.t(), opts :: keyword()) :: String.t()
end
