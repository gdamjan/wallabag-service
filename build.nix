{ pkgs, wallabag, php, uwsgi, withSystemd ? true }:
let

  phpWithModules = (php.override {
    embedSupport = true;
    cliSupport = true;
    cgiSupport = false;
    fpmSupport = false;
    phpdbgSupport = false;
    systemdSupport = false;
    apxs2Support = false;
  }).withExtensions ({ all, ... }:
    with all; [
      pdo
      pdo_pgsql
      session
      ctype
      dom
      simplexml
      gd
      mbstring
      tidy
      iconv
      curl
      gettext
      tokenizer
      bcmath
      intl
      opcache
    ]);

  uwsgiWithPhp = uwsgi.override {
    withPAM = false;
    systemd = pkgs.systemdMinimal;
    plugins = [ "php" ];
    php = phpWithModules;
    inherit withSystemd;
  };

  uwsgiConfig = pkgs.substituteAll {
    name = "uwsgi.wallabag.ini";
    src = ./files/uwsgi.wallabag.ini.in;
    mimeTypes = "${pkgs.mime-types}/etc/mime.types";
    uwsgiLogger = if withSystemd then "systemd" else "stdio";
    php = phpWithModules;
    inherit wallabag;
  };

  wallabag-service = pkgs.substituteAll {
    name = "wallabag.service";
    src = ./files/wallabag.service.in;
    execStart = "${uwsgiWithPhp}/bin/uwsgi --ini ${uwsgiConfig}";
  };
  wallabag-socket =
    pkgs.concatText "wallabag.socket" [ ./files/wallabag.socket ];
  wallabag-first-run-service = pkgs.substituteAll {
    name = "wallabag-first-run.service";
    src = ./files/wallabag-first-run.service.in;
    inherit wallabag;
    inherit (pkgs) coreutils;
  };

in pkgs.portableService {
  pname = "wallabag";
  version = wallabag.version;
  description = "Portable wallabag service run by uwsgi-php and built with Nix";
  homepage = "https://github.com/gdamjan/wallabag-service/";

  units = [ wallabag-service wallabag-socket wallabag-first-run-service ];

  symlinks = [
    {
      object = "${pkgs.cacert}/etc/ssl";
      symlink = "/etc/ssl";
    }
    {
      object = "${pkgs.bash}/bin/bash";
      symlink = "/bin/sh";
    }
    {
      object = "${phpWithModules}/bin/php";
      symlink = "/bin/php";
    }
  ];
}
