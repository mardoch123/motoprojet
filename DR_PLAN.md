# Plan de Sauvegarde et Reprise après Sinistre — MotoProjet

> Document opérationnel pour la récupération de la base de données Neon et de l'API backend.

---

## Vue d'ensemble

| Composant | Stratégie | RTO | RPO |
|-----------|-----------|-----|-----|
| **Base Neon** | PITR natif + exports chiffrés externes | < 1h | < 24h |
| **API Backend** | Railway auto-scaling + health checks | < 5min | N/A |
| **Stockage (R2)** | Backups chiffrés AES-256, 30 jours rétention | < 1h | < 24h |

**RTO** (Recovery Time Objective) : Temps maximal d'indisponibilité toléré  
**RPO** (Recovery Point Objective) : Perte de données maximale tolérée

---

## 1. Sauvegardes automatiques Neon (PITR)

### Configuration

Neon fournit nativement le **Point-In-Time Recovery** (PITR) qui permet de restaurer la base à n'importe quel instant dans le passé.

| Plan Neon | Rétention PITR | Coût |
|-----------|----------------|------|
| Free | 24h | Gratuit |
| Launch | 7 jours | Inclus |
| Scale | 30 jours | Inclus |
| Business | 90 jours | Supplément |

**Recommandation** : Utiliser le plan **Scale** (30 jours) pour les données financières.

### Activation

1. Aller dans le [Dashboard Neon](https://console.neon.tech)
2. Sélectionner le projet `motoprojet`
3. Onglet **Settings** → **Branches**
4. Activer **PITR** sur la branche `main`
5. Choisir la rétention : **30 jours**

### Restauration via PITR Neon

```bash
# Via l'API Neon
curl -X POST "https://console.neon.tech/api/v2/projects/<project_id>/branches/<branch_id>/restore" \
  -H "Authorization: Bearer $NEON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "source_branch_id": "<branch_id>",
    "target_timestamp": "2024-08-10T14:30:00Z"
  }'
```

**Ou via le Dashboard** :
1. Dashboard → Projet → Branches
2. Cliquer sur `main` → **Restore**
3. Choisir le timestamp souhaité
4. Créer une nouvelle branche ou écraser

---

## 2. Exports périodiques externes

### Pourquoi un export externe ?

Le PITR Neon ne protège pas contre :
- Suppression accidentelle du compte Neon
- Corruption des backups Neon (rare mais possible)
- Besoin d'exporter pour audit/compliance

### Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Neon (source)  │────▶│  backup.sh      │────▶│  R2/S3 (dest)   │
│  PostgreSQL     │     │  pg_dump + gpg  │     │  Chiffré AES256 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                                                │
        │ PITR natif                                     │
        ▼                                                ▼
  Restauration rapide                           Archive externe
  (derniers 30 jours)                           (indépendante)
```

### Configuration

#### Variables d'environnement requises

```bash
# .env.production (ou GitHub Secrets)
DATABASE_URL=postgresql://user:pass@neon.tech/db
BACKUP_ENCRYPTION_KEY=<clé_gpg_ou_passphrase>
R2_ENDPOINT=https://<account>.r2.cloudflarestorage.com
R2_ACCESS_KEY=<access_key>
R2_SECRET_KEY=<secret_key>
R2_BUCKET=motoprojet-backups
```

#### Générer une clé de chiffrement

```bash
# Option 1 : Passphrase symétrique (simple)
openssl rand -base64 32

# Option 2 : Clé GPG (recommandé pour la rotation)
gpg --full-generate-key
# Choisir RSA, 4096 bits, pas d'expiration
gpg --export-secret-keys --armor <email> > backup-key.gpg
```

#### Planifier le backup automatique

**GitHub Actions** (recommandé) :
- Workflow `backup-monitoring.yml`
- Exécution quotidienne à 2h UTC
- Rétention : 30 jours

**Cron local** (alternative) :
```bash
# /etc/cron.d/motoprojet-backup
0 2 * * * root /path/to/scripts/backup.sh >> /var/log/motoprojet-backup.log 2>&1
```

### Exécution manuelle

```bash
# Backup complet
./scripts/backup.sh

# Schema seulement (plus rapide)
./scripts/backup.sh --schema-only

# Avec rétention personnalisée
BACKUP_RETENTION_DAYS=90 ./scripts/backup.sh
```

---

## 3. Procédure de restauration

### Scénario A : Restauration rapide via PITR Neon

**Cas d'usage** : Erreur récente (DELETE sans WHERE, migration cassée, etc.)

```
Étapes :
1. Identifier le timestamp AVANT l'incident
2. Dashboard Neon → Branches → Restore
3. Restaurer dans une NOUVELLE branche (test)
4. Vérifier les données
5. Promouvoir la branche restaurée ou copier les tables
```

**Durée estimée** : 5-15 minutes

### Scénario B : Restauration depuis backup externe

**Cas d'usage** : Incident Neon majeur, migration vers nouveau compte

```bash
# 1. Lister les backups disponibles
./scripts/restore.sh --list

# 2. Restaurer le dernier backup
./scripts/restore.sh --latest

# 3. Ou restaurer un backup spécifique
./scripts/restore.sh --from-s3 motoprojet-2024-08-10

# 4. Ou restaurer un fichier local
./scripts/restore.sh ./backups/motoprojet-2024-08-10-020000.sql.gz.gpg
```

**Durée estimée** : 15-60 minutes (selon taille)

### Scénario C : Restauration vers nouvelle instance Neon

```bash
# 1. Créer une nouvelle instance Neon
# (via Dashboard ou API)

# 2. Exporter depuis l'ancien backup
./scripts/restore.sh --from-s3 motoprojet-2024-08-10 \
  DATABASE_URL=postgresql://new-user:new-pass@new-neon.tech/new-db

# 3. Mettre à jour les variables d'environnement
# Railway / Backend : DATABASE_URL

# 4. Redémarrer l'API
railway up
```

### Checklist de restauration

```markdown
## Pré-restauration
- [ ] Identifier la cause de la panne
- [ ] Communiquer l'incident à l'équipe
- [ ] Préparer les accès (Neon, R2, Railway)

## Restauration
- [ ] Choisir le point de restauration (timestamp)
- [ ] Restaurer dans une branche de test
- [ ] Vérifier l'intégrité des données
- [ ] Valider avec un utilisateur métier

## Post-restauration
- [ ] Mettre à jour DATABASE_URL si nécessaire
- [ ] Redémarrer l'API backend
- [ ] Vérifier les health checks
- [ ] Notifier l'équipe de la résolution
- [ ] Documenter l'incident (post-mortem)
```

---

## 4. Plan de continuité API

### Health checks

L'API expose plusieurs endpoints de monitoring :

| Endpoint | Usage |
|----------|-------|
| `GET /health` | Health check basique (200 si OK) |
| `GET /health/db` | Vérifie la connexion à la base |
| `GET /api/v1/auth/ping` | Vérifie l'authentification |

### Monitoring automatisé

**GitHub Actions** :
- Health check toutes les heures (schedule)
- Notification Slack en cas de panne

**Services externes recommandés** :
- [UptimeRobot](https://uptimerobot.com) : Monitoring gratuit, checks toutes les 5 min
- [Better Stack](https://betterstack.com) : Monitoring + on-call
- [Healthchecks.io](https://healthchecks.io) : Cron monitoring

### Configuration Railway

```toml
# railway.toml
[build]
builder = "DOCKERFILE"
dockerfilePath = "Dockerfile"

[deploy]
healthcheckPath = "/health"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 5
```

### Procédure en cas de panne API

```
1. Détection
   - Alertes Slack/Email automatiques
   - Vérifier https://status.motoprojet.bj

2. Diagnostic
   - Railway Dashboard → Logs
   - Vérifier les variables d'environnement
   - Tester la connexion à Neon

3. Résolution
   - Si crash : Railway redémarre automatiquement
   - Si DB : Vérifier le statut Neon
   - Si code : Déployer un hotfix

4. Communication
   - Informer les utilisateurs si > 15 min
   - Post-mortem dans les 48h
```

---

## 5. Chiffrement des sauvegardes

### Méthode

Tous les backups sont chiffrés **avant** upload vers R2 :

```
pg_dump → gzip → GPG (AES-256) → Upload R2
```

### Algorithmes

| Composant | Algorithme |
|-----------|------------|
| Symétrique | AES-256-CBC |
| Asymétrique | RSA-4096 (optionnel) |
| Hash vérification | SHA-256 |

### Rotation des clés

**Recommandation** : Changer la clé de chiffrement tous les 90 jours.

```bash
# Générer une nouvelle clé
NEW_KEY=$(openssl rand -base64 32)

# Mettre à jour GitHub Secrets
gh secret set BACKUP_ENCRYPTION_KEY --body "$NEW_KEY"

# Mettre à jour les variables d'environnement
# Railway, local, etc.
```

### Déchiffrement manuel

```bash
# Avec passphrase
echo "$BACKUP_ENCRYPTION_KEY" | gpg --batch --passphrase-fd 0 \
  --output backup.gz --decrypt backup.gz.gpg

# Avec clé GPG
gpg --output backup.gz --decrypt backup.gz.gpg
```

---

## 6. Tests de restauration

### Fréquence

| Test | Fréquence | Responsable |
|------|-----------|-------------|
| Vérification backup (automatique) | Hebdomadaire | GitHub Actions |
| Restauration complète (manuelle) | Trimestrielle | Équipe tech |
| Simulation sinistre (drill) | Semestrielle | Équipe tech + métier |

### Procédure de test trimestriel

```bash
# 1. Créer une base de test locale
createdb test_restoration

# 2. Restaurer le dernier backup
./scripts/restore.sh --latest \
  DATABASE_URL=postgresql://localhost/test_restoration

# 3. Vérifier les données critiques
psql test_restoration -c "SELECT COUNT(*) FROM users;"
psql test_restoration -c "SELECT COUNT(*) FROM paiements;"
psql test_restoration -c "SELECT COUNT(*) FROM vehicules;"

# 4. Tester l'application en local
DATABASE_URL=postgresql://localhost/test_restoration npm run dev

# 5. Nettoyer
dropdb test_restoration
```

### Critères de succès

- [ ] Toutes les tables restaurées
- [ ] Contraintes d'intégrité respectées
- [ ] Données financières cohérentes
- [ ] Application fonctionnelle

---

## 7. Contacts d'urgence

| Rôle | Nom | Contact |
|------|-----|---------|
| Lead Tech | - | - |
| Admin Neon | - | - |
| Admin Railway | - | - |
| Support Neon | support@neon.tech | - |
| Support Railway | support@railway.app | - |

---

## 8. Secrets requis

### GitHub Secrets

| Secret | Description |
|--------|-------------|
| `DATABASE_URL` | Connection string Neon PostgreSQL |
| `BACKUP_ENCRYPTION_KEY` | Clé de chiffrement des backups |
| `R2_ENDPOINT` | Endpoint S3-compatible |
| `R2_ACCESS_KEY` | Access key du bucket |
| `R2_SECRET_KEY` | Secret key du bucket |
| `R2_BUCKET` | Nom du bucket (défaut: motoprojet-backups) |
| `SLACK_WEBHOOK_URL` | Webhook pour notifications |
| `API_URL` | URL de l'API pour health checks |

### Variables locales

Copier `.env.example` vers `.env` et remplir les mêmes variables.

---

## 9. Métriques et SLA

### Objectifs

| Métrique | Objectif |
|----------|----------|
| Disponibilité API | 99.5% (43h d'indisponibilité/an max) |
| RTO (Recovery Time) | < 1 heure |
| RPO (Recovery Point) | < 24 heures |
| Temps de backup | < 5 minutes |
| Temps de restauration | < 30 minutes |

### Monitoring

- **Uptime** : UptimeRobot / Better Stack
- **Performance** : Railway Metrics
- **Erreurs** : Sentry (si configuré)
- **Backups** : GitHub Actions logs

---

## 10. Post-mortem

Après chaque incident, documenter :

```markdown
## Incident : [Titre]
**Date** : YYYY-MM-DD
**Durée** : X minutes
**Impact** : [Description]

### Timeline
- HH:MM : Détection
- HH:MM : Diagnostic
- HH:MM : Résolution
- HH:MM : Vérification

### Cause racine
[Description]

### Actions correctives
- [ ] Action 1
- [ ] Action 2

### Leçons apprises
[Ce qui a bien fonctionné / à améliorer]
```

---

## Annexes

### A. Commandes utiles

```bash
# Voir les derniers backups
aws s3 ls s3://motoprojet-backups/backups/ --endpoint-url $R2_ENDPOINT --recursive | tail -10

# Télécharger un backup spécifique
aws s3 cp s3://motoprojet-backups/backups/2024/08/motoprojet-2024-08-10-020000.sql.gz.gpg . --endpoint-url $R2_ENDPOINT

# Vérifier l'intégrité d'un backup
sha256sum -c motoprojet-2024-08-10-020000.sql.gz.gpg.sha256

# Tester la connexion à Neon
psql $DATABASE_URL -c "SELECT version();"

# Voir la taille de la base
psql $DATABASE_URL -c "SELECT pg_size_pretty(pg_database_size(current_database()));"
```

### B. Liens utiles

- [Neon Documentation](https://neon.tech/docs)
- [Neon PITR Guide](https://neon.tech/docs/guides/point-in-time-recovery)
- [Railway Documentation](https://docs.railway.app)
- [Cloudflare R2](https://developers.cloudflare.com/r2/)
- [GPG Documentation](https://www.gnupg.org/documentation/)
