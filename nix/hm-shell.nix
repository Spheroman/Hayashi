# Home Manager module for the shell. Start it with `hayashi-shell` from the
# compositor and bind `hayashi-shell ipc call panels toggle` to Super+Esc.
# For live editing, run `hayashi-shell dev ~/path/to/hayashi/shell`; see
# nix/shell.nix.
self:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.hayashi-shell;
in
{
  options.programs.hayashi-shell = {
    enable = lib.mkEnableOption "Hayashi's Quickshell shell";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.hayashi-shell;
      defaultText = lib.literalExpression "hayashi.packages.\${system}.hayashi-shell";
      description = "The shell package, which provides the `hayashi-shell` command.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      cfg.package
      quickshell
      material-symbols
      nerd-fonts.space-mono
      (google-fonts.override { fonts = [ "SpaceGrotesk" ]; })
    ];

    fonts.fontconfig.enable = true;
  };
}
