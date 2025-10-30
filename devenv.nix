{ pkgs, lib, config, inputs, ... }:

let
  pkgs-stable = import inputs.nixpkgs-stable { system = pkgs.stdenv.system; };
  pkgs-unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.system; };
in
{
  env.GREET = "Elixir Caddy";

  packages = [
    pkgs-stable.git
    pkgs-stable.figlet
    pkgs-stable.lolcat
  ];

  languages.elixir.enable = true;
  languages.elixir.package = pkgs-stable.beam27Packages.elixir;

  scripts.hello.exec = ''
    figlet -w 120 $GREET | lolcat
  '';

  enterShell = ''
    hello
  '';

}
