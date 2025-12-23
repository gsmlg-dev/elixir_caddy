defmodule Caddy.Config.Global.LogTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Global.Log
  alias Caddy.Caddyfile

  doctest Caddy.Config.Global.Log

  describe "new/1" do
    test "creates empty log with defaults" do
      log = Log.new()

      assert log.name == nil
      assert log.output == nil
      assert log.format == nil
      assert log.level == nil
      assert log.include == nil
      assert log.exclude == nil
    end

    test "creates log with specified values" do
      log = Log.new(output: "stdout", format: :json)

      assert log.output == "stdout"
      assert log.format == :json
    end

    test "creates named log" do
      log = Log.new(name: "admin", output: "stdout")

      assert log.name == "admin"
      assert log.output == "stdout"
    end
  end

  describe "Caddyfile protocol" do
    test "renders empty string for empty log" do
      log = %Log{}
      result = Caddyfile.to_caddyfile(log)

      assert result == ""
    end

    test "renders default log block" do
      log = %Log{output: "stdout"}
      result = Caddyfile.to_caddyfile(log)

      assert result == "log {\n  output stdout\n}"
    end

    test "renders named log block" do
      log = %Log{name: "admin", output: "stdout"}
      result = Caddyfile.to_caddyfile(log)

      assert result == "log admin {\n  output stdout\n}"
    end

    test "renders output option" do
      log = %Log{output: "file /var/log/caddy/access.log"}
      result = Caddyfile.to_caddyfile(log)

      assert result =~ "output file /var/log/caddy/access.log"
    end

    test "renders format option as atom" do
      log = %Log{output: "stdout", format: :json}
      result = Caddyfile.to_caddyfile(log)

      assert result =~ "format json"
    end

    test "renders level option" do
      log = %Log{output: "stdout", level: :INFO}
      result = Caddyfile.to_caddyfile(log)

      assert result =~ "level INFO"
    end

    test "renders include option with single value" do
      log = %Log{output: "stdout", include: ["http.*"]}
      result = Caddyfile.to_caddyfile(log)

      assert result =~ "include http.*"
    end

    test "renders include option with multiple values" do
      log = %Log{output: "stdout", include: ["http.*", "admin.*"]}
      result = Caddyfile.to_caddyfile(log)

      assert result =~ "include http.* admin.*"
    end

    test "renders exclude option" do
      log = %Log{output: "stdout", exclude: ["http.log.access"]}
      result = Caddyfile.to_caddyfile(log)

      assert result =~ "exclude http.log.access"
    end

    test "renders all options in correct order" do
      log = %Log{
        output: "stdout",
        format: :json,
        level: :INFO,
        include: ["http.*"],
        exclude: ["http.log.access"]
      }

      result = Caddyfile.to_caddyfile(log)

      # Check order: output, format, level, include, exclude
      assert result =~ ~r/output.*format.*level.*include.*exclude/s
    end

    test "does not render empty include list" do
      log = %Log{output: "stdout", include: []}
      result = Caddyfile.to_caddyfile(log)

      refute result =~ "include"
    end

    test "does not render empty exclude list" do
      log = %Log{output: "stdout", exclude: []}
      result = Caddyfile.to_caddyfile(log)

      refute result =~ "exclude"
    end
  end
end
