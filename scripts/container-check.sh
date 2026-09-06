#!/usr/bin/env bash
set -euo pipefail

app_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
image="${1:?Usage: scripts/container-check.sh LOCAL_IMAGE}"
reports="$app_root/tmp/container-check"
mkdir -p "$reports"
container_id=""
cleanup() {
  if [[ -n "$container_id" ]]; then
    docker logs "$container_id" > "$reports/server.log" 2>&1 || true
    docker rm --force "$container_id" >/dev/null
  fi
}
trap cleanup EXIT

container_id="$(docker run --detach --publish 127.0.0.1::80 --env SECRET_KEY_BASE_DUMMY=1 "$image")"
port="$(docker port "$container_id" 80/tcp | sed 's/.*://')"
healthy=false
for ((attempt = 0; attempt < 60; attempt++)); do
  if curl --fail --silent "http://127.0.0.1:$port/up" >/dev/null; then
    healthy=true
    break
  fi
  sleep 0.5
done
"$healthy" || { printf '%s\n' 'Production container did not become healthy.' >&2; exit 1; }

[[ "$(docker exec "$container_id" id -u)" != 0 ]]
docker exec "$container_id" bundle exec ruby -e 'forbidden = %w[capybara selenium-webdriver rubocop brakeman debug]; abort "test tools in runtime" unless (Gem::Specification.map(&:name) & forbidden).empty?'
for route in / /about /blog /ctf /timeline /blog/java-strings /blog/climbing-stairs /feed.xml /feed.atom /feed.json /sitemap.xml; do
  curl --fail --silent "http://127.0.0.1:$port$route" >/dev/null
done
docker exec --interactive "$container_id" bin/rails runner - < "$app_root/scripts/check_container_downloads.rb" | tee "$reports/downloads.json"
docker image inspect "$image" --format '{{.Size}}' > "$reports/image-size-bytes.txt"
printf 'Non-root production container routes passed; image bytes: %s\n' "$(< "$reports/image-size-bytes.txt")"
