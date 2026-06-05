# Shared nginx deploy

`foodbowl.nginx.conf` is the shared nginx front door for the Ubuntu/Tailscale
host. nginx owns `/`, serves the apps by path, and proxies shared backends:

- `/cla/` -> `/var/www/cla`
- `/cod/` -> `/var/www/cod`
- `/pb/` -> PocketBase on `127.0.0.1:8090`
- `/mqtt` -> Mosquitto WebSockets on `192.168.0.49:9001`

Tailscale Serve should forward the MagicDNS HTTPS root to local nginx port 80:

```bash
sudo tailscale serve --bg https / http://127.0.0.1:80
```

The app-specific deploy scripts install this same config to
`/etc/nginx/sites-available/foodbowl`, enable it, remove the legacy per-app
enabled sites, validate nginx, and reload.

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

If the old COD-specific sudoers file exists from testing, remove it after the
combined rule validates:

```bash
sudo rm -f /etc/sudoers.d/github-runner-cod
sudo visudo -c
```
