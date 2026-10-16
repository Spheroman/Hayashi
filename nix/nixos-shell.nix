# NixOS module for the system side of the shell: the PAM service its lock
# screen authenticates against.
{ config, lib, ... }:

{
  options.programs.hayashi-shell.enable = lib.mkEnableOption "system support for Hayashi's Quickshell shell (the lock screen's PAM service)";

  config = lib.mkIf config.programs.hayashi-shell.enable {
    security.pam.services.hayashi-shell = { };
  };
}
