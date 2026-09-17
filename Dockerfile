# syntax=docker/dockerfile:1

# ── build ───────────────────────────────────────────────────────────────────────────────
FROM node:22-alpine AS build
WORKDIR /app

# Dependencies resolve in their own layer, which then only invalidates when the manifests
# change rather than on every edit under src/.
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY . .
# `npm run build` runs the asset packer first, which is a no-op unless the raw KayKit packs
# have been fetched into assets-src/ — the built .glb files are checked in.
RUN npm run build

# ── runtime ─────────────────────────────────────────────────────────────────────────────
FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production

# Everything under server/ is written against Node builtins alone, so no dependency travels
# into the runtime image: the built page and the server's own source are the whole of it.
COPY --from=build /app/dist ./dist
COPY --from=build /app/server ./server
COPY --from=build /app/package.json ./package.json

# The colony file's directory has to exist in the image, owned by the user the container runs
# as. An empty named volume takes its ownership from whatever the image has at that path, and
# a path the image does not have at all arrives as root-owned — at which point the one file
# this project writes cannot be written, and the map silently fails to survive a restart.
RUN mkdir -p /app/data && chown node:node /app/data

EXPOSE 5274
USER node
CMD ["node", "server/serve.mjs"]
