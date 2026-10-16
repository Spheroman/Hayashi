# Plymouth theme "hayashi": a solid background and a Material-style circular
# spinner (a 270-degree arc with round ends). Colors are hex without "#".
{ lib, stdenvNoCC, librsvg
, background ? "0a100d"  # the shell's surface
, foreground ? "dee7e2"  # text, for passphrase prompts
, accent ? "88d8ae"      # the shell's primary
, size ? 48              # spinner diameter in px
}:

let
  channel = hex: i: (builtins.fromTOML "v = 0x${builtins.substring i 2 hex}").v;
  # Plymouth wants each channel as a 0-1 float.
  float = hex: i: toString ((channel hex i) / 255.0);
in
stdenvNoCC.mkDerivation {
  pname = "hayashi-plymouth-theme";
  version = "0.1.0";

  dontUnpack = true;
  nativeBuildInputs = [ librsvg ];

  installPhase = ''
    runHook preInstall
    dir=$out/share/plymouth/themes/hayashi
    mkdir -p $dir

    # Circumference of r=20 is 125.66; the visible arc is 75% of it.
    cat > spinner.svg <<'EOF'
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
      <circle cx="24" cy="24" r="20" fill="none" stroke="#${accent}" stroke-width="4"
              stroke-linecap="round" stroke-dasharray="94.25 125.66" transform="rotate(-90 24 24)"/>
    </svg>
    EOF
    rsvg-convert -w ${toString (size * 2)} -h ${toString (size * 2)} spinner.svg -o $dir/spinner.png

    substitute ${./plymouth/hayashi.script} $dir/hayashi.script \
      --replace-fail @bgR@ ${float background 0} \
      --replace-fail @bgG@ ${float background 2} \
      --replace-fail @bgB@ ${float background 4} \
      --replace-fail @fgR@ ${float foreground 0} \
      --replace-fail @fgG@ ${float foreground 2} \
      --replace-fail @fgB@ ${float foreground 4} \
      --replace-fail @size@ ${toString size}

    cat > $dir/hayashi.plymouth <<EOF
    [Plymouth Theme]
    Name=Hayashi
    Description=The Hayashi shell's boot splash
    ModuleName=script

    [script]
    ImageDir=$dir
    ScriptFile=$dir/hayashi.script
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Plymouth boot splash matching Hayashi's shell";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
