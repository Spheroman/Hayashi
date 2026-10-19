# NixOS module for the system side of the shell:
#   - the PAM service its lock screen authenticates against
#   - optionally, the greeter, as greetd's login screen
#   - optionally, backpack mode (the Power card's "never sleep, run cool")
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

    backpackMode = {
      enable = lib.mkEnableOption ''
        backpack mode, a switch on the Power card for leaving the laptop
        working in a bag: it never sleeps (not even with the lid closed), and
        while the lid is closed on battery it runs slow and cool with the fans
        in their quietest mode. With the lid open, or on AC, it runs as
        normal. It's a system
        service, hayashi-shell-backpack,
        that local users at the machine may start and stop. It turns itself
        off when the battery runs low, so the laptop sleeps instead of dying
      '';

      maxFrequency = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1200;
        description = "The CPU's top speed in backpack mode with the lid closed, in MHz.";
      };

      lowBattery = lib.mkOption {
        type = lib.types.ints.between 0 100;
        default = 10;
        description = "Backpack mode turns itself off at this battery percentage (when not charging).";
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

    (lib.mkIf cfg.backpackMode.enable (let
      # The service's script. `watch` is its main process; `restore` undoes
      # the lid-closed settings however the service ends.
      backpack = pkgs.writeShellScript "hayashi-backpack" ''
        state=/run/hayashi-shell-backpack.state
        fan=$(echo /sys/bus/platform/devices/VPC*/fan_mode)

        # Lid closed on battery: power saver, the CPU and GPU capped, the fans in their
        # quietest mode. What they were goes in $state, to put back.
        quiet() {
          {
            command -v powerprofilesctl >/dev/null && echo "profile=$(powerprofilesctl get)"
            [ -w "$fan" ] && echo "fan=$(cat $fan)"
          } > $state
          command -v powerprofilesctl >/dev/null && powerprofilesctl set power-saver
          for p in /sys/devices/system/cpu/cpufreq/policy*; do
            echo ${toString (cfg.backpackMode.maxFrequency * 1000)} > $p/scaling_max_freq
          done
          for g in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
            [ -e "$g" ] && echo low > "$g"
          done
          # Lenovo IdeaPad/Yoga (ideapad_laptop): 0 is "super silent". The
          # embedded controller still runs the fans if it gets hot enough.
          [ -w "$fan" ] && echo 0 > $fan
          echo "lid closed on battery: quiet"
        }

        restore() {
          [ -e $state ] || return 0
          # No limit (the kernel's own default for the request), not
          # cpuinfo_max_freq: that's the top speed at this moment, 2.0 GHz
          # with boost off in power saver, and it stayed the limit after
          # switching to a profile with boost (2026-10-18).
          for p in /sys/devices/system/cpu/cpufreq/policy*; do
            echo 2147483647 > $p/scaling_max_freq
          done
          for g in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
            [ -e "$g" ] && echo auto > "$g"
          done
          while IFS='=' read -r k v; do
            case $k in
              profile) powerprofilesctl set "$v" ;;
              fan) echo "$v" > $fan ;;
            esac
          done < $state
          rm -f $state
          echo "back to normal"
        }

        lidClosed() { grep -q closed /proc/acpi/button/lid/*/state 2>/dev/null; }

        # On AC (any mains supply online), there's no battery to save: the
        # lid closed then only means no sleep, with full speed and normal fans.
        onAC() {
          for s in /sys/class/power_supply/*; do
            [ "$(cat $s/type 2>/dev/null)" = Mains ] && [ "$(cat $s/online 2>/dev/null)" = 1 ] && return 0
          done
          return 1
        }

        lowBattery() {
          for b in /sys/class/power_supply/BAT*; do
            [ -e "$b/capacity" ] || continue
            [ "$(cat $b/status)" = Discharging ] && [ "$(cat $b/capacity)" -le ${toString cfg.backpackMode.lowBattery} ] && return 0
          done
          return 1
        }

        case "$1" in
          restore) restore ;;
          watch)
            # Follows the lid and the charger every 2 s (quiet only with the
            # lid closed on battery); checks the battery every minute
            # and ends backpack mode when it's low, so the laptop can sleep
            # (logind's lid handling takes over again).
            restore
            trap 'restore; exit 0' TERM INT
            n=0
            while :; do
              if lidClosed && ! onAC; then [ -e $state ] || quiet
              else [ -e $state ] && restore
              fi
              if [ $((n % 30)) -eq 0 ] && lowBattery; then
                echo "battery low, ending backpack mode"
                restore
                exit 0
              fi
              n=$((n + 1))
              sleep 2 & wait $!
            done
            ;;
        esac
      '';
    in {
      # Started and stopped by the Power card. While it runs it holds a
      # logind inhibitor against sleep and the lid, suspend and power keys
      # (as root, so no session needs that right). With the lid open the
      # laptop runs as normal; with it closed on battery, it's throttled and the fans
      # kept quiet.
      systemd.services.hayashi-shell-backpack = {
        description = "Hayashi shell backpack mode: no sleep; quiet with the lid closed";
        path = [ pkgs.coreutils pkgs.gnugrep ]
          ++ lib.optional config.services.power-profiles-daemon.enable config.services.power-profiles-daemon.package;
        serviceConfig = {
          Type = "simple";
          ExecStart = lib.escapeShellArgs [
            "${pkgs.systemd}/bin/systemd-inhibit"
            "--what=sleep:handle-lid-switch:handle-suspend-key:handle-power-key"
            "--mode=block"
            "--who=Backpack mode"
            "--why=Keeping the laptop working in a bag"
            backpack
            "watch"
          ];
          ExecStopPost = "${backpack} restore";
        };
      };

      # Anyone at the machine can switch backpack mode on and off.
      security.polkit.enable = true;
      security.polkit.extraConfig = ''
        polkit.addRule(function (action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "hayashi-shell-backpack.service" &&
              (action.lookup("verb") == "start" || action.lookup("verb") == "stop") &&
              subject.local && subject.active) {
            return polkit.Result.YES;
          }
        });
      '';
    }))

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
