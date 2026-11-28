# Ladybird from upstream's official AppImage.
#
# Why not pkgs.ladybird: nixpkgs only carries a source snapshot
# (0-unstable-2026-11-01) and the 2026.48.0 bump needs an unreleased PR
# (NixOS/nixpkgs#584562: new llvm-libc headers, dependency changes) plus a
# 40-70 min C++ build. Upstream ships a signed x86_64 AppImage and publishes
# its SHA-256 at https://download.ladybird.org/releases.json, so we wrap that
# instead: a fetch and a wrapper, no compile.
#
# The two pinned values below are rewritten by scripts/update-ladybird.sh,
# which `mcli update` runs before rebuilding — so a normal system update also
# moves Ladybird to the newest upstream release.
{
  appimageTools,
  fetchurl,
  lib,
  symlinkJoin,
}:
let
  pname = "ladybird";
  version = "2026.48.0";

  src = fetchurl {
    url = "https://download.ladybird.org/linux/${version}/ladybird-${version}-Linux-x86_64.AppImage";
    hash = "sha256-LJAotIckux3DhYva9YonPIPbXm2WvgsLWWbLKh7IwPw=";
  };

  # Unpacked copy, only used for the .desktop file and icon.
  contents = appimageTools.extract {inherit pname version src;};

  wrapped = appimageTools.wrapType2 {
    inherit pname version src;
    # The AppImage bundles Qt but expects the host's GL/X11/Wayland stack;
    # the FHS env needs them named explicitly on NixOS.
    extraPkgs = pkgs: [
      pkgs.libglvnd
      pkgs.libxcb
      pkgs.libGL
      pkgs.wayland
    ];
  };
in
  symlinkJoin {
    name = "${pname}-${version}";
    paths = [wrapped];

    postBuild = ''
      # buildFHSEnv names the launcher after the derivation; expose a stable
      # name, plus the capitalised one the old nixpkgs package used
      # (BROWSER=Ladybird in modules/home/apps/xdg.nix).
      if [ ! -e $out/bin/${pname} ]; then
        ln -s "$(ls -d $out/bin/* | head -1)" $out/bin/${pname}
      fi
      ln -sf $out/bin/${pname} $out/bin/Ladybird

      # Upstream's desktop file is already org.ladybird.Ladybird.desktop, the
      # name modules/home/apps/xdg.nix registers as the web handler; only the
      # Exec line has to point at the wrapper.
      mkdir -p $out/share/applications $out/share/icons/hicolor/scalable/apps
      cp ${contents}/org.ladybird.Ladybird.desktop $out/share/applications/
      cp ${contents}/org.ladybird.Ladybird.svg \
        $out/share/icons/hicolor/scalable/apps/org.ladybird.Ladybird.svg
      substituteInPlace $out/share/applications/org.ladybird.Ladybird.desktop \
        --replace-fail "Exec=Ladybird %U" "Exec=$out/bin/${pname} %U"
    '';

    meta = {
      description = "Ladybird web browser (official upstream AppImage)";
      homepage = "https://ladybird.org/";
      license = lib.licenses.bsd2;
      mainProgram = pname;
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
