{ config, lib, pkgs, ... }:
let
  cfg = config.programs.prismarine;
in {
  options.programs.prismarine = {
    enable = lib.mkEnableOption "Prismarine, a desktop manager for Prism Launcher instances";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The Prismarine package to install.";
    };
    installPrismLauncher = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Prism Launcher alongside Prismarine.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ]
      ++ lib.optional cfg.installPrismLauncher pkgs.prismlauncher;
  };
}
