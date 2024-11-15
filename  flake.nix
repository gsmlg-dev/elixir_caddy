{
  nixConfig = {
    # extra-substituters = "https://cache.nixos.org/";
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  } @ inputs :
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      elixir_caddy = pkgs.callPackage ./default.nix { inherit system; };
    in {
      packages.elixir_caddy = elixir_caddy;

      formatter = pkgs.alejandra;

      devShells.default = pkgs.mkShell {
        name = "Elixir Caddy Dev Shell";

        buildInputs = [
          pkgs.figlet
          pkgs.elixir
        ];

        shellHook = ''
        figlet -w 120 -f starwars Elixir Caddy
        figlet -w 120 -f starwars Dev Shell
        export EDITOR=vim

        '';
      };
    });
}
