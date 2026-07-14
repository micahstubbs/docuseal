#!/bin/sh
# Run the DocuSeal RSpec suite (or a subset) inside Docker.
# Host has no Ruby 4.0.5, so tests run in a ruby:4.0.5-alpine container
# with a dedicated postgres sidecar, mirroring .github/workflows/ci.yml.
#
# Usage:
#   scripts/test-in-docker.sh setup            # one-time: containers + gems + db
#   scripts/test-in-docker.sh rspec [args...]  # run rspec (e.g. spec/lib/...)
#   scripts/test-in-docker.sh down             # stop/remove containers (keeps gem cache volume)
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NET=docuseal-test-net
PG=docuseal-test-pg
APP=docuseal-test-app
BUNDLE_VOL=docuseal-test-bundle
DB_URL="postgres://postgres:postgres@$PG:5432/docuseal_test"

case "$1" in
  setup)
    docker network inspect $NET >/dev/null 2>&1 || docker network create $NET
    docker inspect $PG >/dev/null 2>&1 || docker run -d --name $PG --network $NET \
      -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=docuseal_test \
      postgres:16-alpine
    docker inspect $APP >/dev/null 2>&1 || docker run -d --name $APP --network $NET \
      -v "$REPO_DIR":/app -v $BUNDLE_VOL:/usr/local/bundle \
      -w /app -e RAILS_ENV=test -e DATABASE_URL="$DB_URL" \
      ruby:4.0.5-alpine sleep infinity
    docker exec $APP sh -c '
      set -e
      apk add --no-cache build-base git libpq-dev yaml-dev libpq vips onnxruntime leptonica wget unzip shared-mime-info tzdata nodejs yarn chromium
      wget -q -O /tmp/pdfium.zip "https://github.com/docusealco/pdfium-binaries/releases/download/20260613/pdfium-musl-$(uname -m).zip"
      unzip -q -o /tmp/pdfium.zip -d /tmp/pdfium && cp /tmp/pdfium/lib/libpdfium.so /usr/lib/libpdfium.so
      bundle install --jobs 4 --retry 2
      ln -sf /usr/lib/libonnxruntime.so.1 "$(ruby -e "print Dir[Gem::Specification.find_by_name('"'"'onnxruntime'"'"').gem_dir + '"'"'/vendor/*.so'"'"'].first")" || true
      bundle exec rake db:create db:migrate
      yarn install --frozen-lockfile
      NODE_ENV=test bundle exec rake assets:precompile
    '
    ;;
  rspec)
    shift
    docker exec $APP bundle exec rspec "$@"
    ;;
  down)
    docker rm -f $APP $PG 2>/dev/null || true
    docker network rm $NET 2>/dev/null || true
    ;;
  *)
    echo "usage: $0 {setup|rspec [args...]|down}" >&2
    exit 1
    ;;
esac
