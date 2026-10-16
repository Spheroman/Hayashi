# NixOS module for the system side of the shell:
#   - the PAM service its lock screen authenticates against
#   - optionally, the greeter, as greetd's login screen
self:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.hayashi-shell;
  shellPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.hayashi-shell;
  sessions = "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
in
{
  options.programs.hayashi-shell = {
    enable = lib.mkEnableOption "system support for Hayashi's Quickshell shell (the lock screen's PAM service)";

    greeter.enable = lib.mkEnableOption ''
      the shell's greeter as greetd's login screen. It runs in cage and lists
      the installed Wayland sessions
    '';
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
          # cage: -s allows switching VTs, -m last uses the last-connected output.
          command = lib.concatStringsSep " " [
            "${lib.getExe pkgs.cage} -s -m last --"
            "${pkgs.coreutils}/bin/env HAYASHI_GREETER_SESSIONS=${sessions}"
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
  ];
}
