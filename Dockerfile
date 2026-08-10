# =============================================================================
# Dockerfile — MotoProjet API
# Multi-stage build pour une image optimisée
# =============================================================================

# ─── Stage 1 : Build ─────────────────────────────────────────────────────────
FROM node:22-alpine AS builder

WORKDIR /app

# Copier les fichiers de dépendances
COPY backend/package.json backend/package-lock.json ./

# Installer toutes les dépendances (y compris devDependencies pour le build)
RUN npm ci

# Copier le code source
COPY backend/ ./

# Type-check + Build
RUN npx tsc --noEmit && npm run build

# ─── Stage 2 : Production ────────────────────────────────────────────────────
FROM node:22-alpine AS production

# Labels
LABEL maintainer="MotoProjet <dev@motoprojet.bj>"
LABEL org.opencontainers.image.title="MotoProjet API"
LABEL org.opencontainers.image.description="API REST — financement de taxis au Bénin"

# Sécurité : ne pas root
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

WORKDIR /app

# Copier uniquement les fichiers de production
COPY backend/package.json backend/package-lock.json ./

# Installer uniquement les dépendances de production
RUN npm ci --omit=dev && npm cache clean --force

# Copier le build compilé
COPY --from=builder /app/dist ./dist

# Copier les fichiers SQL de migration (legacy + versionnés)
COPY backend/src/db/*.sql ./src/db/
COPY backend/src/db/migrations ./src/db/migrations/

# Appartenir à l'utilisateur non-root
RUN chown -R appuser:appgroup /app
USER appuser

# Variables d'environnement
ENV NODE_ENV=production
ENV PORT=3000

# Exposer le port
EXPOSE 3000

# Health check (vérifie l'API + la base de données)
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health/db || exit 1

# Démarrage
CMD ["node", "dist/server.js"]
