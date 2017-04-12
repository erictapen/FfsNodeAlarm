{ config, pkgs, lib, ... }:

with lib;

let 
  cfg = config.services.nodealarm;
  # WHYYY?
  pack = pkgs.callPackage ./default.nix {};
  #pack = ./default.nix;
in

{

  options = {
    services.nodealarm = {
      enable = mkOption {
        default = false;
        description = ''
          Hier wird der Nodealarm aktiviert.
        '';
        type = types.bool;
      }; 
      stateDir = mkOption {
        default = "/var/lib/nodealarm";
        description = "State dir";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.nodealarm = {
      after = [ "network.target" "mysql.service" ];
      wantedBy = [ "multi-user.target" ];
      description = "nodealarm description";
      preStart = ''
        if [ ! -d ${cfg.stateDir} ]; then
          mkdir -p ${cfg.stateDir}
          echo state angelegt
        fi
        cp -r $pack/public/ ${cfg.stateDir}/
        # TODO
        # Erstmal alles in statedir schreiben
        # .env init mit php artisan keys:generate
        # DB anlegen mit user und password und privileges
        # db init mit php artisan migrate
        # nginx und mysql aus der configuration.nix
      '';
      script = ''
        echo Läuft
      '';
      postStop = ''
        echo stop
      '';
    };
  };
}
