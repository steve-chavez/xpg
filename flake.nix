{
  description = "Develop PostgreSQL core and native extensions";

  nixConfig = {
    extra-substituters = [
      "https://nxpg.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nxpg.cachix.org-1:6HKVOmmG/ptPEogBAJ+zR6kRji5F4uHTNx7EGt7WBh0="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/24.05";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          xpgPkgs = import ./nix/packages.nix { inherit pkgs; };
        in
        xpgPkgs // {
          default = xpgPkgs.xpg;
        });

      apps = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          xpgPkgs = import ./nix/packages.nix { inherit pkgs; };
          mkApp = name: drv: {
            type = "app";
            program = "${drv}/bin/${name}";
          };
        in
        {
          default = mkApp "xpg" xpgPkgs.xpg;
          xpg = mkApp "xpg" xpgPkgs.xpg;
          xpg-core = mkApp "xpg-core" xpgPkgs.xpg-core;
        });
    };
}
