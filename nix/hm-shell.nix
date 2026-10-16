# Home Manager module for the shell. Start it with `qs` from the compositor
# (it's linked as Quickshell's default config); `qs ipc call panels toggle`
# opens the panel view.
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
      description = "The shell's QML.";
    };

    devPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/me/src/hayashi/shell";
      description = ''
        A working copy of the shell/ directory to link instead of the store,
        so edits reload live without a rebuild.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      quickshell
      material-symbols
      nerd-fonts.space-mono
      (google-fonts.override { fonts = [ "SpaceGrotesk" ]; })
    ];

    fonts.fontconfig.enable = true;

    xdg.configFile."quickshell".source =
      if cfg.devPath != null
      then config.lib.file.mkOutOfStoreSymlink cfg.devPath
      else "${cfg.package}/share/hayashi-shell";
  };
}
