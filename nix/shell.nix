# The shell's QML, installed to share/hayashi-shell, plus a `hayashi-shell`
# command that runs it.
#
#   hayashi-shell             start the shell (the store copy)
#   hayashi-shell ipc ...     talk to the running shell, e.g. `ipc call panels toggle`
#   hayashi-shell dev PATH    restart it from a working copy, for live editing
#   hayashi-shell dev off     restart it from the store copy again
#   hayashi-shell status      print which copy is in use
#
# Dev mode is remembered in $XDG_STATE_HOME/hayashi-shell/dev-path, so it
# survives restarts until `dev off`.
{ lib, stdenvNoCC, runtimeShell, quickshell }:

stdenvNoCC.mkDerivation {
  pname = "hayashi-shell";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../shell;
    fileset = ../shell;
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/hayashi-shell $out/bin
    cp -r . $out/share/hayashi-shell

    cat > $out/bin/hayashi-shell <<'EOF'
    #!${runtimeShell}
    set -eu
    qs=${quickshell}/bin/qs
    store=@out@/share/hayashi-shell
    state="''${XDG_STATE_HOME:-$HOME/.local/state}/hayashi-shell"

    config() {
      if [ -f "$state/dev-path" ]; then cat "$state/dev-path"; else echo "$store"; fi
    }

    case "''${1:-}" in
      ipc)
        shift
        exec "$qs" ipc -p "$(config)" "$@"
        ;;
      dev)
        shift
        old=$(config)
        case "''${1:-}" in
          off) rm -f "$state/dev-path" ;;
          "") echo "usage: hayashi-shell dev PATH | off" >&2; exit 2 ;;
          *)
            [ -f "$1/shell.qml" ] || { echo "hayashi-shell: no shell.qml in $1" >&2; exit 1; }
            mkdir -p "$state"
            realpath "$1" > "$state/dev-path"
            ;;
        esac
        "$qs" kill -p "$old" >/dev/null 2>&1 || true
        exec "$qs" -p "$(config)" -d
        ;;
      status)
        config
        ;;
      *)
        exec "$qs" -p "$(config)" "$@"
        ;;
    esac
    EOF
    substituteInPlace $out/bin/hayashi-shell --replace-fail @out@ $out
    chmod +x $out/bin/hayashi-shell

    runHook postInstall
  '';

  meta = {
    description = "Hayashi's Material 3 Quickshell shell";
    homepage = "https://github.com/Spheroman/hayashi";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "hayashi-shell";
  };
}
