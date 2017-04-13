{ config, pkgs, lib, ... }:

with lib;

let 
  cfg = config.services.nodealarm;
  pkg = pkgs.callPackage ./default.nix {};
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
      dbHost = mkOption {
        default = "localhost";
        description = "DB Host";
      };
      dbUser = mkOption {
        default = "nodealarm";
        description = "DB Username";
      };
      dbPass = mkOption {
        default = "nodealarm";
        description = "DB Password";
      };
      dbName = mkOption {
        default = "nodealarm";
        description = "DB Name";
      };
    };
  };

  config = mkIf cfg.enable {
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
    };
    services.nginx = {
      enable = true;
      virtualHosts = {
        "localhost" = {
          root = cfg.stateDir;
          extraConfig = "index index.html index.htm index.php;";
          port = 80;
          locations = {
            "/" = {
              tryFiles = "$uri $uri/ /index.php?$query_string";
            };
            "~ ^/index.php(/|$)" = {
              extraConfig = ''
                    fastcgi_pass 127.0.0.1:9000;
                    fastcgi_split_path_info ^(.+\.php)(/.*)$;
                    fastcgi_index index.php;
                    include ${cfg.stateDir}/fastcgi_params;
                    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
              '';
            };
            #"~ /\.ht" = {
            #  extraConfig = "deny all";
            #};
          };
        };
      };
    };
    services.phpfpm = {
      phpPackage = pkgs.php70;
      pools = { 
        mypool = { 
          #listen = "/run/php/php7.0-fpm.sock"; 
          listen = "127.0.0.1:9000"; 
          extraConfig = '' 
            user = nobody 
            pm = dynamic 
            pm.max_children = 75 
            pm.start_servers = 10 
            pm.min_spare_servers = 5 
            pm.max_spare_servers = 20 
            pm.max_requests = 500 
          ''; 
        }; 
      };
    };
    systemd.services.nodealarm = {
      after = [ "network.target" "mysql.service" ];
      wantedBy = [ "multi-user.target" ];
      description = "nodealarm description";
      preStart = ''
        if [ ! -d ${cfg.stateDir} ]; then
          mkdir -p ${cfg.stateDir}
          echo state angelegt
        fi
        echo "Die Anwendung liegt in ${pkg}"
        rm -rf ${cfg.stateDir}/*
        cd ${pkg}
        cp -r . ${cfg.stateDir}/
        chmod -R ug+rw ${cfg.stateDir}
        cd ${cfg.stateDir}
        cp .env.example .env
        ${pkgs.php}/bin/php artisan key:generate
        sed -i 's/DB_HOST=localhost/DB_HOST=${cfg.dbHost}/g' .env 
        sed -i 's/DB_DATABASE=homestead/DB_DATABASE=${cfg.dbName}/g' .env
        sed -i 's/DB_USERNAME=homestead/DB_USERNAME=${cfg.dbUser}/g' .env 
        sed -i 's/DB_PASSWORD=secret/DB_PASSWORD=${cfg.dbPass}/g' .env

        echo "CREATE USER IF NOT EXISTS '${cfg.dbUser}'@'${cfg.dbHost}' IDENTIFIED BY '${cfg.dbPass}';" | ${pkgs.mysql}/bin/mysql -u root
        echo "CREATE DATABASE IF NOT EXISTS ${cfg.dbName};" | ${pkgs.mysql}/bin/mysql -u root
        echo "GRANT ALL PRIVILEGES ON ${cfg.dbName}.* TO '${cfg.dbUser}'@'${cfg.dbHost}';" | ${pkgs.mysql}/bin/mysql -u root

        # db init mit php artisan migrate
        ${pkgs.php}/bin/php artisan migrate
        chown -R nginx:nginx ${cfg.stateDir}
 
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
