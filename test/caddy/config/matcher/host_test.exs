defmodule Caddy.Config.Matcher.HostTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.Host
  alias Caddy.Caddyfile

  describe "new/1" do
    test "creates host matcher with single host" do
      matcher = Host.new(["example.com"])
      assert matcher.hosts == ["example.com"]
    end

    test "creates host matcher with multiple hosts" do
      matcher = Host.new(["example.com", "*.example.com", "localhost"])
      assert matcher.hosts == ["example.com", "*.example.com", "localhost"]
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher" do
      matcher = Host.new(["example.com"])
      assert {:ok, ^matcher} = Host.validate(matcher)
    end

    test "returns error for empty hosts" do
      matcher = Host.new([])
      assert {:error, "hosts cannot be empty"} = Host.validate(matcher)
    end

    test "returns error for non-string hosts" do
      matcher = %Host{hosts: [123]}
      assert {:error, "all hosts must be strings"} = Host.validate(matcher)
    end
  end

  describe "Caddyfile protocol" do
    test "renders single host" do
      matcher = Host.new(["example.com"])
      assert Caddyfile.to_caddyfile(matcher) == "host example.com"
    end

    test "renders multiple hosts" do
      matcher = Host.new(["example.com", "*.example.com"])
      assert Caddyfile.to_caddyfile(matcher) == "host example.com *.example.com"
    end
  end
end
