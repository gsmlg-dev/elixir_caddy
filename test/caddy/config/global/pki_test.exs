defmodule Caddy.Config.Global.PKITest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Global.PKI
  alias Caddy.Caddyfile

  doctest Caddy.Config.Global.PKI

  describe "new/1" do
    test "creates pki with default ca_id" do
      pki = PKI.new()

      assert pki.ca_id == "local"
      assert pki.name == nil
      assert pki.root_cn == nil
      assert pki.intermediate_cn == nil
      assert pki.intermediate_lifetime == nil
    end

    test "creates pki with custom ca_id" do
      pki = PKI.new(ca_id: "internal")

      assert pki.ca_id == "internal"
    end

    test "creates pki with all values" do
      pki =
        PKI.new(
          ca_id: "local",
          name: "My Company CA",
          root_cn: "Root CA",
          intermediate_cn: "Intermediate CA",
          intermediate_lifetime: "30d"
        )

      assert pki.ca_id == "local"
      assert pki.name == "My Company CA"
      assert pki.root_cn == "Root CA"
      assert pki.intermediate_cn == "Intermediate CA"
      assert pki.intermediate_lifetime == "30d"
    end
  end

  describe "Caddyfile protocol" do
    test "renders empty string for empty pki (no CA options)" do
      pki = %PKI{}
      result = Caddyfile.to_caddyfile(pki)

      assert result == ""
    end

    test "renders pki block with name" do
      pki = %PKI{name: "My CA"}
      result = Caddyfile.to_caddyfile(pki)

      assert result =~ "pki {"
      assert result =~ "ca local {"
      assert result =~ ~s(name "My CA")
    end

    test "renders pki block with custom ca_id" do
      pki = %PKI{ca_id: "internal", name: "Internal CA"}
      result = Caddyfile.to_caddyfile(pki)

      assert result =~ "ca internal {"
    end

    test "renders root_cn with quotes" do
      pki = %PKI{root_cn: "My Company Root CA"}
      result = Caddyfile.to_caddyfile(pki)

      assert result =~ ~s(root_cn "My Company Root CA")
    end

    test "renders intermediate_cn with quotes" do
      pki = %PKI{intermediate_cn: "My Company Intermediate CA"}
      result = Caddyfile.to_caddyfile(pki)

      assert result =~ ~s(intermediate_cn "My Company Intermediate CA")
    end

    test "renders intermediate_lifetime without quotes" do
      pki = %PKI{name: "Test", intermediate_lifetime: "30d"}
      result = Caddyfile.to_caddyfile(pki)

      assert result =~ "intermediate_lifetime 30d"
      refute result =~ ~s(intermediate_lifetime "30d")
    end

    test "renders all options in correct order" do
      pki = %PKI{
        ca_id: "local",
        name: "My CA",
        root_cn: "Root CA",
        intermediate_cn: "Intermediate CA",
        intermediate_lifetime: "30d"
      }

      result = Caddyfile.to_caddyfile(pki)

      expected = """
      pki {
        ca local {
          name "My CA"
          root_cn "Root CA"
          intermediate_cn "Intermediate CA"
          intermediate_lifetime 30d
        }
      }
      """

      assert result == String.trim_trailing(expected)
    end

    test "renders only non-nil options" do
      pki = %PKI{name: "My CA", intermediate_lifetime: "30d"}
      result = Caddyfile.to_caddyfile(pki)

      assert result =~ ~s(name "My CA")
      assert result =~ "intermediate_lifetime 30d"
      refute result =~ "root_cn"
      refute result =~ "intermediate_cn"
    end
  end
end
