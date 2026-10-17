# NixOS module for the system side of the shell:
#   - the PAM service its lock screen authenticates against
#   - optionally, the greeter, as greetd's login screen
self:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.hayashi-shell;
  shellPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.hayashi-shell;
  sessions = "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";

  # The greeter, run by greetd on the login VT (greetd clears the VT itself
  # before starting the greeter and the session).
  greeter = pkgs.writeShellScript "hayashi-greeter" ''
    # cage: -d no window decorations, -s allow switching VTs,
    # -m last use the last-connected output. Qt draws its own title bar when
    # the compositor doesn't, so QT_WAYLAND_DISABLE_WINDOWDECORATION turns
    # that off too.
    exec ${lib.getExe pkgs.cage} -d -s -m last -- \
      ${pkgs.coreutils}/bin/env \
        HAYASHI_GREETER_SESSIONS=${sessions} \
        QT_WAYLAND_DISABLE_WINDOWDECORATION=1 \
      ${pkgs.quickshell}/bin/qs -p ${shellPackage}/share/hayashi-shell/greeter.qml
  '';

  # The Linux console's default 16-color palette, with color 0 (the console
  # background) replaced by the shell's surface color.
  hex = s: (builtins.fromTOML "v = 0x${s}").v;
  bg = cfg.greeter.consoleBackground;
  channel = i: toString (hex (builtins.substring i 2 bg));
  palette = {
    red = [ (channel 0) "170" "0" "170" "0" "170" "0" "170" "85" "255" "85" "255" "85" "255" "85" "255" ];
    grn = [ (channel 2) "0" "170" "85" "0" "0" "170" "170" "85" "85" "255" "255" "85" "85" "255" "255" ];
    blu = [ (channel 4) "0" "0" "0" "170" "170" "170" "170" "85" "85" "85" "85" "255" "255" "255" "255" ];
  };
in
{
  options.programs.hayashi-shell = {
    enable = lib.mkEnableOption "system support for Hayashi's Quickshell shell (the lock screen's PAM service)";

    greeter = {
      enable = lib.mkEnableOption ''
        the shell's greeter as greetd's login screen. It runs in cage and lists
        the installed Wayland sessions
      '';

      seamless = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Keep the boot console quiet and tint its background with the shell's
          surface color, so nothing but that color shows between boot, the
          greeter and the session.
        '';
      };

      consoleBackground = lib.mkOption {
        type = lib.types.strMatching "[0-9a-fA-F]{6}";
        default = "0a100d";
        description = "The shell's surface color (hex, no #), used for the console background.";
      };
    };

    bootSplash = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.greeter.enable && cfg.greeter.seamless;
        defaultText = lib.literalExpression "greeter.enable && greeter.seamless";
        description = ''
          A Plymouth boot splash in the shell's colors: the surface color with
          a spinner, so boot runs into the greeter on the same background.
        '';
      };

      accent = lib.mkOption {
        type = lib.types.strMatching "[0-9a-fA-F]{6}";
        default = "88d8ae";
        description = "The spinner's color (hex, no #); the shell's primary.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      security.pam.services.hayashi-shell = { };

      # The system's trusted CAs as plain PEM certificates, for checking
      # enterprise Wi-Fi (eduroam and the like). NixOS's bundle also holds
      # OpenSSL "TRUSTED CERTIFICATE" blocks, and iwd (ell) rejects the whole
      # file when it meets one, so the Wi-Fi card points NetworkManager here
      # instead. /etc, since iwd's sandbox hides /home and /tmp.
      environment.etc."hayashi-shell/ca-bundle.crt".source =
        pkgs.runCommand "hayashi-shell-ca-bundle.crt" { } ''
          ${pkgs.gawk}/bin/awk '
            /^-----BEGIN CERTIFICATE-----$/ { keep = 1 }
            keep { print }
            /^-----END CERTIFICATE-----$/ { keep = 0 }
          ' ${config.security.pki.caBundle} > $out
        '';
    })

    (lib.mkIf cfg.greeter.enable {
      services.greetd = {
        enable = true;
        settings.default_session = {
          user = "greeter";
          command = "${greeter}";
        };
      };

      # The greeter user has no home-manager profile, so its fonts are system-wide.
      fonts.packages = with pkgs; [
        material-symbols
        nerd-fonts.space-mono
        (google-fonts.override { fonts = [ "SpaceGrotesk" ]; })
      ];
    })

    (lib.mkIf cfg.bootSplash.enable {
      boot.plymouth = {
        enable = true;
        theme = "hayashi";
        themePackages = [
          (pkgs.callPackage ./plymouth-theme.nix {
            background = cfg.greeter.consoleBackground;
            accent = cfg.bootSplash.accent;
          })
        ];
      };
    })

    (lib.mkIf (cfg.greeter.enable && cfg.greeter.seamless) {
      boot.consoleLogLevel = 3;
      boot.initrd.verbose = false;
      boot.kernelParams = [
        "quiet"
        "udev.log_level=3"
        "rd.udev.log_level=3"
        "systemd.show_status=auto"
        "vt.global_cursor_default=0"
        "vt.default_red=${lib.concatStringsSep "," palette.red}"
        "vt.default_grn=${lib.concatStringsSep "," palette.grn}"
        "vt.default_blu=${lib.concatStringsSep "," palette.blu}"
      ];
    })
  ];
}
