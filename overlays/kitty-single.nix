self: super: {
  kitty-unwrapped = super.kitty;

  kitty = super.symlinkJoin {
    name = "kitty-${super.kitty.version}";
    paths = [ super.kitty ];
    nativeBuildInputs = [ super.makeWrapper ];

    meta = super.kitty.meta;

    postBuild = ''
      wrapProgram $out/bin/kitty \
        --add-flags "--single-instance"
    '';
  };
}
