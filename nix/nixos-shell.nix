# NixOS module for the system side of the shell:
#   - the PAM service its lock screen authenticates against
#   - optionally, the greeter, as greetd's login screen
self:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.hayashi-shell;
  shellPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.hayashi-shell;
  sessions = "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";

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
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      security.pam.services.hayashi-shell = { };
    })

    (lib.mkIf cfg.greeter.enable {
      services.greetd = {
        enable = true;
        settings.default_session = {
          user = "greeter";
          # cage: -d no window decorations, -s allow switching VTs,
          # -m last use the last-connected output.
          command = lib.concatStringsSep " " [
            "${lib.getExe pkgs.cage} -d -s -m last --"
            "${pkgs.coreutils}/bin/env"
            "HAYASHI_GREETER_SESSIONS=${sessions}"
            # Qt draws its own title bar when the compositor doesn't; cage
            # doesn't, so turn Qt's off too.
            "QT_WAYLAND_DISABLE_WINDOWDECORATION=1"
            "${pkgs.quickshell}/bin/qs -p ${shellPackage}/share/hayashi-shell/greeter.qml"
          ];
        };
      };

      # The greeter user has no home-manager profile, so its fonts are system-wide.
      fonts.packages = with pkgs; [
        material-symbols
        nerd-fonts.space-mono
        (google-fonts.override { fonts = [ "SpaceGrotesk" ]; })
      ];
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
