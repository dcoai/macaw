# The tools brand/render.exs runs: librsvg to render the logo, ImageMagick to
# lay out the social previews and to read pixels back for the checks.
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends librsvg2-bin imagemagick && rm -rf /var/lib/apt/lists/*
WORKDIR /work
