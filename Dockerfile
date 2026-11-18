FROM docker.io/oven/bun:1 AS frontend
WORKDIR /app
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun run build

FROM docker.io/hexpm/elixir:1.18.4-erlang-27.3.4-debian-bookworm-20250428-slim AS build
WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force
ENV MIX_ENV=prod
COPY backend/mix.exs backend/mix.lock* ./
RUN mix deps.get --only prod
COPY backend/config config
COPY backend/lib lib
COPY --from=frontend /app/dist priv/static
RUN mix compile && mix release

FROM docker.io/library/debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/_build/prod/rel/uno ./
ENV PHX_SERVER=true PORT=4000
EXPOSE 4000
CMD ["bin/uno", "start"]
