# The shell's QML, installed to share/hayashi-shell. Quickshell runs it from
# there; see hm-shell.nix for how it gets linked into ~/.config/quickshell.
{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "hayashi-shell";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../shell;
    fileset = ../shell;
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/hayashi-shell
    cp -r . $out/share/hayashi-shell
    runHook postInstall
  '';

  meta = {
    description = "Hayashi's Material 3 Quickshell shell";
    homepage = "https://github.com/Spheroman/hayashi";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
