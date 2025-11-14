# Stage 1: deps (install all dependencies for build)
FROM node:lts-alpine AS deps
WORKDIR /app
ARG PNPM_VERSION=latest
# Active Corepack et installe la version de pnpm spécifiée
RUN corepack enable && corepack prepare pnpm@${PNPM_VERSION} --activate

# Copie les fichiers de lock / dépendances et installe
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Stage 2: builder (build the app)
FROM node:lts-alpine AS builder
WORKDIR /app
ARG PNPM_VERSION=latest
# Encore activation de Corepack / pnpm dans le builder
RUN corepack enable && corepack prepare pnpm@${PNPM_VERSION} --activate

# On réutilise les modules installés dans deps pour éviter de les réinstaller
COPY --from=deps /app/node_modules ./node_modules
# On copie tout le reste du code source
COPY . .
# On lance le build de l’application
RUN pnpm build

# Stage 3: prod-deps (prune dev dependencies)
FROM deps AS prod-deps
WORKDIR /app
# On supprime les dépendances de développement pour garder uniquement ce qui est nécessaire en production
RUN pnpm prune --prod

# Stage 4: runner (final runtime image)
FROM node:lts-alpine AS runner
WORKDIR /app
ARG PNPM_VERSION=latest
# On active Corepack / pnpm dans l’image finale + on crée un user non-root
RUN corepack enable && corepack prepare pnpm@${PNPM_VERSION} --activate \
 && addgroup -S -g 1001 nodejs \
 && adduser -S -u 1001 -G nodejs appuser

# Copie seulement ce qu’il faut pour exécuter en production
# Les modules de production uniquement
COPY --from=prod-deps --chown=appuser:nodejs /app/node_modules ./node_modules
# Le fichier package.json pour l’application
COPY --from=deps --chown=appuser:nodejs /app/package.json ./package.json

# Copie le build sorti par le builder (à ajuster si ton build sort autre part)
COPY --from=builder --chown=appuser:nodejs /app/.output ./.output
# Copie optionnelle de dossiers de base de données/migrations si tu en as besoin
COPY --from=builder --chown=appuser:nodejs /app/src/db ./src/db

# Définit l’utilisateur non root
USER appuser
# Définit l’environnement comme production
ENV NODE_ENV=production
# Expose le port 3000 (à ajuster si ton app utilise un autre port)
EXPOSE 3000

# Commande de démarrage de l’application : utilise pnpm start
CMD ["pnpm", "start"]

## j'ai demandé à Copilot de me décris au max pour que je comprenne chaque étape du Dockerfile.