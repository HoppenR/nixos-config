self: super:
let
  kitty-unwrapped = super.kitty;
  kitty-wrapped = super.stdenv.mkDerivation {
    pname = "kitty";
    version = kitty-unwrapped.version;
    src = ./.;
    nativeBuildInputs = [ super.makeWrapper ];
    installPhase = ''
      mkdir -p $out/bin
      makeWrapper ${kitty-unwrapped}/bin/kitty $out/bin/kitty \
        --add-flags "--single-instance"
    '';
    meta = kitty-unwrapped.meta // {
      description = "Kitty wrapped to always use --single‑instance";
    };
  };
in
{
  inherit kitty-unwrapped;
  kitty = super.symlinkJoin {
    name = "kitty-${kitty-unwrapped.version}";
    meta = kitty-wrapped.meta;
    paths = [
      kitty-wrapped
      kitty-unwrapped
    ];
  };
}
