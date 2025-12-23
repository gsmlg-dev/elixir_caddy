defmodule Caddy.Config.Global.TimeoutsTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Global.Timeouts
  alias Caddy.Caddyfile

  doctest Caddy.Config.Global.Timeouts

  describe "new/1" do
    test "creates empty timeouts with defaults" do
      timeouts = Timeouts.new()

      assert timeouts.read_body == nil
      assert timeouts.read_header == nil
      assert timeouts.write == nil
      assert timeouts.idle == nil
    end

    test "creates timeouts with specified values" do
      timeouts = Timeouts.new(read_body: "10s", idle: "2m")

      assert timeouts.read_body == "10s"
      assert timeouts.idle == "2m"
      assert timeouts.read_header == nil
      assert timeouts.write == nil
    end

    test "creates timeouts with all values" do
      timeouts =
        Timeouts.new(
          read_body: "10s",
          read_header: "5s",
          write: "30s",
          idle: "2m"
        )

      assert timeouts.read_body == "10s"
      assert timeouts.read_header == "5s"
      assert timeouts.write == "30s"
      assert timeouts.idle == "2m"
    end
  end

  describe "Caddyfile protocol" do
    test "renders empty string for empty timeouts" do
      timeouts = %Timeouts{}
      result = Caddyfile.to_caddyfile(timeouts)

      assert result == ""
    end

    test "renders single timeout option" do
      timeouts = %Timeouts{read_body: "10s"}
      result = Caddyfile.to_caddyfile(timeouts)

      assert result == "timeouts {\n  read_body 10s\n}"
    end

    test "renders multiple timeout options" do
      timeouts = %Timeouts{read_body: "10s", read_header: "5s"}
      result = Caddyfile.to_caddyfile(timeouts)

      assert result =~ "timeouts {"
      assert result =~ "read_body 10s"
      assert result =~ "read_header 5s"
    end

    test "renders all timeout options in correct order" do
      timeouts = %Timeouts{
        read_body: "10s",
        read_header: "5s",
        write: "30s",
        idle: "2m"
      }

      result = Caddyfile.to_caddyfile(timeouts)

      assert result ==
               """
               timeouts {
                 read_body 10s
                 read_header 5s
                 write 30s
                 idle 2m
               }
               """
               |> String.trim_trailing()
    end

    test "renders only non-nil options" do
      timeouts = %Timeouts{read_body: "10s", write: "30s"}
      result = Caddyfile.to_caddyfile(timeouts)

      assert result =~ "read_body 10s"
      assert result =~ "write 30s"
      refute result =~ "read_header"
      refute result =~ "idle"
    end
  end
end
