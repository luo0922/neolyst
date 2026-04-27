FROM node:20-alpine

WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@10.29.3 --activate

# Copy lock file and install deps
COPY web/package.json web/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Copy source
COPY web/ ./

# Inject public env vars at build time
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY
ENV NODE_ENV=production

RUN pnpm build

EXPOSE 3000
CMD ["pnpm", "start"]
