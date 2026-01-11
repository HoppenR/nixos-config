self: super:
let
  kitty-unwrapped = super.kitty;
  kitty = super.stdenv.mkDerivation {
    pname = "kitty";
    version = kitty-unwrapped.version;
    src = ./.;
    nativeBuildInputs = [ super.makeWrapper ];
    installPhase = ''
      mkdir -p $out/bin
      ln --symbolic ${kitty-unwrapped}/bin/kitten $out/bin/kitten
      makeWrapper ${kitty-unwrapped}/bin/kitty $out/bin/kitty \
        --append-flags "--single-instance"
    '';
    meta = kitty-unwrapped.meta // {
      description = "Kitty wrapped to always use --single‑instance";
    };
  };
in
{
  inherit
    kitty-unwrapped
    kitty
    ;
}
