{ pkgs ? import <nixpkgs> {}, withSystemd ? true }:

let
  squash-compression = "xz -Xdict-size 100%";
  uwsgiLogger = if withSystemd then "systemd" else "stdio";

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
    [ pdo pdo_pgsql pcntl posix filter mbstring fileinfo iconv intl dom curl gd opcache session ]);

  uwsgi = pkgs.uwsgi.override {
    withPAM = false;
    withSystemd = withSystemd;
    systemd = pkgs.systemdMinimal;
    plugins = ["php"];
    php = php;
  };

  uwsgiConfig = pkgs.substituteAll {
    name = "uwsgi.wallabag.ini";
    src = ./files/uwsgi.wallabag.ini.in;
    mimeTypes = pkgs.mime-types + "/etc/mime.types";
    inherit wallabag php uwsgiLogger;
  };

  rootfs = pkgs.stdenv.mkDerivation {
    name = "rootfs";
    inherit uwsgi php wallabag uwsgiConfig;
    coreutils = pkgs.coreutils;
    buildCommand = ''
        # prepare the portable service file-system layout
        mkdir -p $out/etc/systemd/system $out/proc $out/sys $out/dev $out/run $out/tmp $out/var/tmp $out/var/lib
        touch $out/etc/resolv.conf $out/etc/machine-id
        cp ${./files/os-release} $out/etc/os-release

        # global /usr/bin/php and bash symlinks for the update daemon
        mkdir -p $out/usr/bin
        ln -s ${php}/bin/php $out/usr/bin/php
        ln -s ${pkgs.bash}/bin/bash $out/usr/bin/sh
        ln -s $out/usr/bin/ $out/bin

        # create the mount-point for the cert store
        mkdir -p $out/etc/ssl/certs

        # setup systemd units
        substituteAll ${./files/wallabag.service.in} $out/etc/systemd/system/wallabag.service
        cp ${./files/wallabag.socket} $out/etc/systemd/system/wallabag.socket
    '';
  };

in

pkgs.stdenv.mkDerivation {
  name = "wallabag.raw";
  nativeBuildInputs = [ pkgs.squashfsTools ];

  buildCommand = ''
      closureInfo=${pkgs.closureInfo { rootPaths = [ rootfs ]; }}

      mkdir -p nix/store
      for i in $(< $closureInfo/store-paths); do
        cp -a "$i" "''${i:1}"
      done

      # archive the nix store
      mksquashfs nix ${rootfs}/* $out \
        -noappend \
        -keep-as-directory \
        -all-root -root-mode 755 \
        -b 1048576 -comp ${squash-compression}
  '';
}
