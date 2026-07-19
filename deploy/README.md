# Shared nginx deploy

The Ubuntu/Tailscale host serves every app from **one** vhost, by path:

- `/cla/` -> `/var/www/cla`
- `/cod/` -> `/var/www/cod`
- `/forms/` -> forms container on `127.0.0.1:8080` (separate repo)
- `/pb/` -> PocketBase on `127.0.0.1:8090`
- `/mqtt` -> Mosquitto WebSockets on `192.168.0.49:9001`

Same paths on both networks — `http://ubuntu.lan/cla/` on the LAN,
`https://ubuntuserver.tailb99a87.ts.net/cla/` over Tailscale.

## Ownership

The **root vhost is infrastructure** (`/etc/nginx/sites-available/root`). It
owns `server_name`, the landing page and the shared backends, and it is
installed by hand — no app pipeline may rewrite it. That file lives in the
`forms` repo at `deploy/root.nginx.conf` purely so it is version-controlled.

Apps contribute **only** a location fragment in `/etc/nginx/apps.d/`, which the
root vhost includes:

```
/etc/nginx/apps.d/foodbowl.conf   <- this repo (deploy/foodbowl.nginx.conf)
/etc/nginx/apps.d/forms.conf      <- forms repo
```

Adding an app means dropping one more file in `apps.d/`. No new DNS name, no
new Tailscale port, no edits to another project's config.

Tailscale Serve needs a single mapping, forwarding the MagicDNS HTTPS root to
local nginx:

```bash
sudo tailscale serve --bg https / http://127.0.0.1:80
```

## One-time server setup

From the Windows desktop, copy both privileged deploy scripts to the Ubuntu
server:

```powershell
scp cla\deploy\deploy-cla-nginx.sh ubuntu:/tmp/deploy-cla-nginx.sh
scp cod\deploy\deploy-cod-nginx.sh ubuntu:/tmp/deploy-cod-nginx.sh
ssh -t ubuntu
```

On the Ubuntu server, install both scripts root-owned. The GitHub runner can run
them, but cannot modify them; that is the trust boundary.

```bash
sudo install -o root -g root -m 0755 /tmp/deploy-cla-nginx.sh /usr/local/sbin/deploy-cla-nginx.sh
sudo install -o root -g root -m 0755 /tmp/deploy-cod-nginx.sh /usr/local/sbin/deploy-cod-nginx.sh
```

Replace the sudoers rule with the two allowed deploy commands:

```bash
echo 'mushbrain ALL=(ALL) NOPASSWD: /usr/local/sbin/deploy-cla-nginx.sh, /usr/local/sbin/deploy-cod-nginx.sh' \
  | sudo tee /etc/sudoers.d/github-runner >/dev/null
sudo chmod 0440 /etc/sudoers.d/github-runner
sudo visudo -c
```

Reinstall the scripts whenever their contents change in this repo — they are
deliberately not auto-installed by the workflow.
