#!/usr/bin/env bash
# Wire a domain to the portfolio (port 8092) on the shared pi-tunnel.
# Usage:  ./add-domain.sh yourdomain.com            # adds apex + www
#         ./add-domain.sh sub.yourdomain.com        # adds just that host
set -euo pipefail

DOMAIN="${1:?usage: add-domain.sh <domain> [--no-www]}"
NOWWW="${2:-}"
PORT=8092
CFG=/etc/cloudflared/config.yml
TID=9f2261a5-0b23-4d88-83ee-08cbf940cb02

# Build the list of hostnames to add.
HOSTS=("$DOMAIN")
# add www. only for an apex (exactly one dot) and unless --no-www
if [[ "$NOWWW" != "--no-www" && "$(grep -o '\.' <<<"$DOMAIN" | wc -l)" -eq 1 ]]; then
  HOSTS+=("www.$DOMAIN")
fi

echo ">> backing up $CFG"
sudo cp "$CFG" "${CFG}.bak.$(date +%Y%m%d-%H%M%S)"

# Insert each hostname block before the catch-all 404 rule, if not already present.
for h in "${HOSTS[@]}"; do
  if sudo grep -qF "hostname: $h" "$CFG"; then
    echo ">> $h already in ingress, skipping"
  else
    echo ">> adding ingress: $h -> http://localhost:$PORT"
    sudo sed -i "s|  - service: http_status:404|  - hostname: $h\n    service: http://localhost:$PORT\n  - service: http_status:404|" "$CFG"
  fi
done

echo ">> validating config"
cloudflared --config "$CFG" tunnel ingress validate

echo ">> restarting cloudflared.service"
sudo systemctl restart cloudflared.service

# Try to auto-create the DNS route (only works if the zone is on THIS Cloudflare account).
for h in "${HOSTS[@]}"; do
  if cloudflared tunnel route dns pi-tunnel "$h" 2>/dev/null; then
    echo ">> DNS route auto-created for $h (proxied CNAME -> ${TID}.cfargotunnel.com)"
  else
    echo ">> could not auto-create DNS for $h."
    echo "   Add this record in your Cloudflare dashboard (zone must be on this account):"
    echo "     Type: CNAME | Name: $h | Target: ${TID}.cfargotunnel.com | Proxy: ON (orange cloud)"
  fi
done

echo ""
echo "Done. CNAME target: ${TID}.cfargotunnel.com"
