# COD deploy

The GitHub Actions workflow (`.github/workflows/deploy-cod.yml`) builds the
Flutter web app with `--base-href /cod/` and then runs one privileged command on
the self-hosted runner:

```bash
sudo /usr/local/sbin/deploy-cod-nginx.sh "$PWD/cod/build/web" "$PWD/deploy/foodbowl.nginx.conf"
```

`deploy-cod-nginx.sh` publishes the build to `/var/www/cod`, installs the
shared `foodbowl` nginx vhost, validates with `nginx -t`, and reloads. nginx
owns `/`; the COD app is served at `/cod/`, while shared backends stay at
`/pb/`, `/frigate/`, and `/mqtt`.

## One-time server setup

The script is not auto-installed by the workflow. Install it manually as root,
and repeat the install whenever `deploy-cod-nginx.sh` changes in the repo. See
the shared setup steps in `deploy/README.md`; the sudoers rule should allow both
the CLA and COD deploy scripts.

## Backends

- PocketBase runs on the Ubuntu host at `127.0.0.1:8090`.
- Frigate runs on the Ubuntu host at `127.0.0.1:5000`.
- Mosquitto WebSockets run on the MQTT LXC at `192.168.0.49:9001`.
- Tailscale TLS should forward HTTPS for `ubuntuserver.tailb99a87.ts.net` to
  local nginx port 80.
