# The shell's QML, installed to share/hayashi-shell, plus a `hayashi-shell`
# command that runs it.
#
#   hayashi-shell             start the shell (the store copy) in the background,
#                             replacing any copy already running, from any build
#   hayashi-shell -f          the same, but attached to the terminal (debugging)
#   hayashi-shell msg WORD    fast keybind message: panels, launcher, lock or close
#   hayashi-shell ipc ...     talk to the running shell, e.g. `ipc call panels toggle`
#   hayashi-shell dev PATH    restart it from a working copy, for live editing
#   hayashi-shell dev off     restart it from the store copy again
#   hayashi-shell status      print which copy is in use
#
# Dev mode is remembered in $XDG_STATE_HOME/hayashi-shell/dev-path, so it
# survives restarts until `dev off`.
{ lib, stdenvNoCC, runtimeShell, quickshell, procps, socat }:

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

    # Stops every running copy of the shell: any store build (a rebuild
    # changes the path, so an old build can outlive a restart) and the dev
    # checkout, if one is set.
    stop_all() {
      ${procps}/bin/pkill -f -- '/bin/quickshell -p /nix/store/[^ ]*-hayashi-shell-[^ ]*/share/hayashi-shell( |$)' || true
      if [ -f "$state/dev-path" ]; then
        ${procps}/bin/pkill -f -x -- ".*/bin/quickshell -p $(cat "$state/dev-path")( .*)?" || true
      fi
      # Give them a moment to release the notification service and the session lock.
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        ${procps}/bin/pgrep -f -- '/bin/quickshell -p .*hayashi-shell' >/dev/null || break
        sleep 0.1
      done
    }

    case "''${1:-}" in
      msg)
        # One word over the shell's socket (a few ms). If the shell isn't
        # listening, fall back to qs ipc, which also reports the error.
        word="''${2:-}"
        sock="''${XDG_RUNTIME_DIR:-/tmp}/hayashi-shell.sock"
        if printf '%s\n' "$word" | ${socat}/bin/socat - "UNIX-CONNECT:$sock" 2>/dev/null; then exit 0; fi
        case "$word" in
          panels|launcher) exec "$qs" ipc -p "$(config)" call "$word" toggle ;;
          lock) exec "$qs" ipc -p "$(config)" call lock lock ;;
          close) exec "$qs" ipc -p "$(config)" call panels close ;;
          *) echo "usage: hayashi-shell msg panels|launcher|lock|close" >&2; exit 2 ;;
        esac
        ;;
      ipc)
        shift
        exec "$qs" ipc -p "$(config)" "$@"
        ;;
      dev)
        shift
        case "''${1:-}" in
          "") echo "usage: hayashi-shell dev PATH | off" >&2; exit 2 ;;
          off) ;;
          *) [ -f "$1/shell.qml" ] || { echo "hayashi-shell: no shell.qml in $1" >&2; exit 1; } ;;
        esac
        stop_all
        if [ "$1" = off ]; then
          rm -f "$state/dev-path"
        else
          mkdir -p "$state"
          realpath "$1" > "$state/dev-path"
        fi
        exec "$qs" -p "$(config)" -d
        ;;
      status)
        config
        ;;
      --foreground|-f)
        # Attached to the terminal, with its log output there (for debugging).
        shift
        stop_all
        exec "$qs" -p "$(config)" "$@"
        ;;
      *)
        # Detached, so closing the terminal it was started from doesn't
        # take the shell with it.
        stop_all
        exec "$qs" -p "$(config)" -d "$@"
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
