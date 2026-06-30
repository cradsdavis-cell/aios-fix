#!/usr/bin/env bash
# One-time fix: make the AI OS box run its container as the non-root `aios`
# user instead of root, so Claude Code stops refusing --dangerously-skip-permissions.
set -euo pipefail

echo ">> Stopping the box for a moment..."
systemctl stop ai-os.service

echo ">> Handing all of /state to the limited (aios) user..."
chown -R aios:aios /state

echo ">> Writing the non-root override..."
mkdir -p /etc/systemd/system/ai-os.service.d
AIOS_UID=$(id -u aios)
AIOS_GID=$(id -g aios)
cat > /etc/systemd/system/ai-os.service.d/nonroot.conf <<CONF
[Service]
ExecStart=
ExecStart=/usr/bin/docker run --rm --name ai-os --user ${AIOS_UID}:${AIOS_GID} --env-file /etc/ai-os/env -v /state:/state -p 127.0.0.1:7781:7781 -p 127.0.0.1:7780:7780 ghcr.io/cradsdavis-cell/ai-os:latest up
CONF

echo ">> Reloading systemd + starting the box..."
systemctl daemon-reload
systemctl start ai-os.service

echo ">> Waiting for the container to come up..."
for i in $(seq 1 30); do
  if docker exec ai-os id >/dev/null 2>&1; then break; fi
  sleep 2
done

echo ""
echo "================= RESULT ================="
echo "-- override written:"
cat /etc/systemd/system/ai-os.service.d/nonroot.conf
echo ""
echo "-- Claude now runs as (want a NON-zero uid, NOT uid=0):"
docker exec ai-os id || echo "(container still starting -- run:  docker exec ai-os id  again in a few seconds)"
echo "=========================================="
echo ""
echo "If the uid above is non-zero, it worked. Tell Sasha to refresh her browser tab."
