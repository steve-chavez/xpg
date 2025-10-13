with import (builtins.fetchTarball {
    name = "24.05"; # May 31 2024
    url = "https://github.com/NixOS/nixpkgs/archive/refs/tags/24.05.tar.gz";
    sha256 = "sha256:1lr1h35prqkd1mkmzriwlpvxcb34kmhc9dnr48gkm8hh089hifmx";
}) {};
let
  ourPg = callPackage ./nix/postgresql {
    inherit lib;
    inherit stdenv;
    inherit fetchurl;
    inherit makeWrapper;
    inherit callPackage;
  };
  checked-shell-script = callPackage ./nix/checked-shell-script.nix {
    inherit lib;
  };
in
{
  xpg = callPackage ./nix/xpg.nix {
    inherit ourPg;
    inherit checked-shell-script;
  };
  xpgWithExtensions =
    { exts12 ? [] , exts13 ? [] , exts14 ? [], exts15 ? [], exts16? [], exts17? [], exts18? [] } :
    callPackage ./nix/xpg.nix {
      inherit ourPg;
      inherit checked-shell-script;
      inherit exts12;
      inherit exts13;
      inherit exts14;
      inherit exts15;
      inherit exts16;
      inherit exts17;
      inherit exts18;
    };
  xpg-core = callPackage ./nix/xpg-core.nix {
    inherit ourPg;
    inherit checked-shell-script;
  };
  postgresql_18 = ourPg.postgresql_18;
  postgresql_18_cassert = ourPg.postgresql_18_cassert;
  postgresql_17 = ourPg.postgresql_17;
  postgresql_17_cassert = ourPg.postgresql_17_cassert;
  postgresql_16 = ourPg.postgresql_16;
  postgresql_16_cassert = ourPg.postgresql_16_cassert;
  postgresql_15 = ourPg.postgresql_15;
  postgresql_15_cassert = ourPg.postgresql_15_cassert;
  postgresql_14 = ourPg.postgresql_14;
  postgresql_14_cassert = ourPg.postgresql_14_cassert;
  postgresql_13 = ourPg.postgresql_13;
  postgresql_13_cassert = ourPg.postgresql_13_cassert;
  postgresql_12 = ourPg.postgresql_12;
  postgresql_12_cassert = ourPg.postgresql_12_cassert;
}
