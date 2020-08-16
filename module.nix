{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.pdfq;

  # Command line arguments for the pdfq daemon
  # data dir.  pdfq.db, config.
  # user to run as.
  # port, I guess.
  # pdf docs directory

in

{

  ###### interface

  options = {
    services.pdfq = {
      enable = mkEnableOption "pdfq";

      dataDir = mkOption {
        type = types.path;
        default = null;
        example = "/home/bburdette/.pdfq";
        description = "Location where hydron runs and stores data.";
      };

      listenAddress = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "127.0.0.1";
        description = "Listen on a specific IP address.";
      };

      listenPort = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 8011;
        description = "Listen on a specific IP port.";
      };

      importPaths = mkOption {
        type = types.listOf types.path;
        default = [];
        example = [ "/home/bburdette/papers" ];
        description = "Paths that pdfq will recursively import.";
      };

    };
  };

  ###### implementation

  config = mkIf cfg.enable {

    systemd.services.pdfq = {
      description = "pdfq";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig.User = "bburdette";

      script = ''
          cd /home/bburdette/code/pdfq/server
          /home/bburdette/code/pdfq/server/target/debug/server
          '';

      # serviceConfig = {
      #   User = "bburdette";
      #   # Group = "bburdette";
      #   ExecStart = ''
      #     cd /home/bburdette/code/pdfq/server &&
      #     /home/bburdette/code/pdfq/server/target/debug/server
      #     '';
      # };
    };
  };
}
