defmodule Caddy.ConfigTest do
  use ExUnit.Case
  alias Caddy.Config

  test "test caddy conifg paths" do
    Config.ensure_path_exists()

    Config.paths()
    |> Enum.each(fn path ->
      assert File.exists?(path)
    end)
  end
end
