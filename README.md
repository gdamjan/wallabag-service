[![CI](https://github.com/gdamjan/wallabag-service/actions/workflows/ci.yml/badge.svg)](https://github.com/gdamjan/wallabag-service/actions/workflows/ci.yml)
[![Release](https://github.com/gdamjan/wallabag-service/actions/workflows/release.yml/badge.svg)](https://github.com/gdamjan/wallabag-service/actions/workflows/release.yml)

# `wallabag` as a systemd portable service

This portable service image comes with:
* [Wallabag](https://wallabag.org/)
* uwsgi as an application server, with php support
* php
* all the required php extensions

You need to provide:
* a database
* nginx and a virtual host
* lets encrypt certificate for https
* basic config file (see below)

All packed in an immutable [portable service](https://systemd.io/PORTABLE_SERVICES/) image. The image is built with
Nixos.

The service is configured in the `/etc/default/wallabag.conf` file.

All state will be kept in the database and `/var/lib/private/wallabag`.

## Quick Start

Get the latest image from [Github releases](https://github.com/gdamjan/wallabag-service/releases/), into
`/var/lib/portables` and then run:

```sh
portablectl inspect wallabag…
portablectl attach --enable --now wallabag…
```

## Service configuration

The service is configured by the `/etc/default/wallabag.conf` file.


## External dependencies

The running service doesn't have an http server, database nor a certificate store. It only includes the wallabag application
code, uwsgi with the php plugin, and the required php extensions. It exposes the `/run/wallabag.sock` uwsgi
protocol socket, which can be used with nginx. This means that you have
to provide an nginx running on the "host", and a database running either on the same host or on a remote server.

I choose to use nginx on the "host" so that it can be shared with other services, and it makes
integration with LetsEncrypt/certbot easier. I personally also use a remote database server.

The portable service will mount `/etc/ssl/certs` from the "host" in the service, so that trusted ca certificates
are not hard-coded in the image, and can be updated as part of the "host" OS life-cycle.

## Nginx configuration

The portable service will operate on the `/run/wallabag.sock` uwsgi socket. We gonna let the host nginx handle
all the http, https and letsencrypt work. The config is simple, just proxy everything back to the uwsgi socket:
```
server {
    …
    location / {
        include uwsgi_params;
        uwsgi_pass unix:/run/wallabag.sock;
    }
    …
}
```
> Note: even static files are served by the uwsgi server, but uwsgi has a good enough static files server, which doesn't
> block the application workers

## More info

See the [wiki](https://github.com/gdamjan/wallabag-service/wiki/) for more info.
