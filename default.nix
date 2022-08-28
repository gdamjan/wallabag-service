{ pkgs ? import <nixpkgs> {}, withSystemd ? true }:

let
  wallabag = pkgs.wallabag;

  php = (pkgs.php.override {
    embedSupport = true;
    cliSupport = true;
    cgiSupport = false;
    fpmSupport = false;
    phpdbgSupport = false;
    systemdSupport = false;
    apxs2Support = false;
  }).withExtensions ({ all, ... }: with all;
    [ pdo pdo_pgsql session ctype dom simplexml gd mbstring xml tidy iconv curl gettext tokenizer bcmath intl opcache ]);

  uwsgi = pkgs.uwsgi.override {
    withPAM = false;
    withSystemd = withSystemd;
    systemd = pkgs.systemdMinimal;
    plugins = ["php"];
    inherit php;
  };

  uwsgiConfig = pkgs.substituteAll {
    name = "uwsgi.wallabag.ini";
    src = ./files/uwsgi.wallabag.ini.in;
    mimeTypes = "${pkgs.mime-types}/etc/mime.types";
    uwsgiLogger = if withSystemd then "systemd" else "stdio";
    inherit php wallabag;
  };

  wallabag-service = pkgs.substituteAll {
    name = "wallabag.service";
    src = ./files/wallabag.service.in;
    execStart = "${uwsgi}/bin/uwsgi --ini ${uwsgiConfig}";
  };
  wallabag-socket = pkgs.concatText "wallabag.socket" [ ./files/wallabag.socket ];

in

pkgs.portableService {
  pname = "wallabag";
  version = wallabag.version;
  description = ''Portable wallabag service run by uwsgi-php and built with Nix'';
  homepage = "https://github.com/gdamjan/wallabag-service/";

  units = [ wallabag-service wallabag-socket ];

  symlinks = [
    { object = "${pkgs.cacert}/etc/ssl"; symlink = "/etc/ssl"; }
    { object = "${pkgs.bash}/bin/bash"; symlink = "/bin/sh"; }
    { object = "${php}/bin/php"; symlink = "/bin/php"; }
  ];
}
