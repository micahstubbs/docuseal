#!/bin/sh
# Replace the running dataroom-sign container with a new image, keeping its config.
# Usage: scripts/redeploy-dataroom-sign.sh <image:tag>
#
# Keeps the old container, stopped, as dataroom-sign-old-<timestamp> for rollback:
#   docker stop dataroom-sign && docker rename dataroom-sign dataroom-sign-bad \
#     && docker rename dataroom-sign-old-<ts> dataroom-sign && docker start dataroom-sign
# Runtime env (secrets included) is copied from the old container into a 0600 file under
# ~/.config/dataroom-sign/ and is never printed.
set -eu
IMAGE="$1"
NAME=dataroom-sign
TS="$(date +%Y%m%d-%H%M%S)"
ENV_DIR="$HOME/.config/dataroom-sign"
ENV_FILE="$ENV_DIR/env-$TS"
mkdir -p "$ENV_DIR" && chmod 700 "$ENV_DIR"
umask 077
docker inspect "$NAME" --format '{{range .Config.Env}}{{println .}}{{end}}' \
  | grep -E '^(FORCE_SSL|PRODUCT_NAME|EXTERNAL_TOKEN_AUTH_SECRET|EXTERNAL_MAGIC_LINK_ISSUER_URL)=' >> "$ENV_FILE"
[ "$(wc -l < "$ENV_FILE")" -eq 4 ] || { echo "expected 4 runtime env vars in $ENV_FILE"; exit 1; }
docker image inspect "$IMAGE" >/dev/null
docker stop "$NAME" >/dev/null
docker rename "$NAME" "$NAME-old-$TS"
docker run -d --name "$NAME" --restart unless-stopped \
  -p 127.0.0.1:3102:3000 -v dataroom-sign-data:/data/docuseal \
  --env-file "$ENV_FILE" "$IMAGE" >/dev/null
echo "started $NAME from $IMAGE at $(date -u +%FT%TZ); previous container kept as $NAME-old-$TS"
for i in $(seq 1 30); do
  code="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3102/up || true)"
  [ "$code" = "200" ] && { echo "healthy after ${i}s"; exit 0; }
  sleep 1
done
echo "not healthy after 30s (last /up: $code); see docker logs $NAME"; exit 1
