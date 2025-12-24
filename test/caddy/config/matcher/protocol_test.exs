defmodule Caddy.Config.Matcher.ProtocolTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.Protocol
  alias Caddy.Caddyfile

  describe "new/1" do
    test "creates protocol matcher for https" do
      matcher = Protocol.new("https")
      assert matcher.protocol == "https"
    end

    test "creates protocol matcher for http" do
      matcher = Protocol.new("http")
      assert matcher.protocol == "http"
    end

    test "creates protocol matcher for grpc" do
      matcher = Protocol.new("grpc")
      assert matcher.protocol == "grpc"
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher" do
      matcher = Protocol.new("https")
      assert {:ok, ^matcher} = Protocol.validate(matcher)
    end

    test "returns error for empty protocol" do
      matcher = %Protocol{protocol: ""}
      assert {:error, "protocol cannot be empty"} = Protocol.validate(matcher)
    end

    test "returns error for nil protocol" do
      matcher = %Protocol{protocol: nil}
      assert {:error, "protocol cannot be empty"} = Protocol.validate(matcher)
    end
  end

  describe "Caddyfile protocol" do
    test "renders https protocol" do
      matcher = Protocol.new("https")
      assert Caddyfile.to_caddyfile(matcher) == "protocol https"
    end

    test "renders http protocol" do
      matcher = Protocol.new("http")
      assert Caddyfile.to_caddyfile(matcher) == "protocol http"
    end
  end
end
