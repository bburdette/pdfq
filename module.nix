{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.pdfq;

  # Command line arguments for the pdfq daemon

in

{

  ###### interface

  options = {
    services.pdfq = {
      enable = mkEnableOption "pdfq";
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
