let
  lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked;
in
with import (builtins.fetchTarball {
  name = lock.rev;
  url = "https://github.com/${lock.owner}/${lock.repo}/archive/${lock.rev}.tar.gz";
  sha256 = lock.narHash;
}) {};

import ./nix/packages.nix {
  pkgs = {
    inherit lib stdenv fetchurl makeWrapper callPackage;
  };
}
