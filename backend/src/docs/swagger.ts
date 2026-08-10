/**
 * Spécification OpenAPI 3.0 — générée automatiquement
 */
export const swaggerDocument = {
  openapi: '3.0.3',
  info: {
    title: 'MotoProjet API',
    description: 'API REST pour le système de financement de motos-taxis et voitures-taxis au Bénin',
    version: '1.0.0',
    contact: { name: 'MotoProjet' },
  },
  servers: [{ url: '/api/v1', description: 'API v1' }],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
      },
    },
    schemas: {
      ApiResponse: {
        type: 'object',
        properties: {
          success: { type: 'boolean' },
          data: { type: 'object' },
          error: { type: 'string' },
          meta: { type: 'object' },
        },
        required: ['success'],
      },
      LoginRequest: {
        type: 'object',
        properties: {
          telephone: { type: 'string', example: '+22912345678' },
          pin: { type: 'string', example: '1234' },
        },
        required: ['telephone', 'pin'],
      },
      CreatePaiementRequest: {
        type: 'object',
        properties: {
          vehicule_id: { type: 'string', format: 'uuid' },
          montant: { type: 'number', example: 5000 },
          date: { type: 'string', format: 'date' },
          mode: { type: 'string', enum: ['cash', 'mobile_money'] },
          synchronise_offline: { type: 'boolean', default: false },
        },
        required: ['vehicule_id', 'montant'],
      },
      SyncBatchRequest: {
        type: 'object',
        properties: {
          paiements: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                id: { type: 'string', format: 'uuid', description: 'UUID mobile' },
                vehicule_id: { type: 'string', format: 'uuid' },
                montant: { type: 'number' },
                date: { type: 'string', format: 'date' },
                mode: { type: 'string', enum: ['cash', 'mobile_money'] },
              },
              required: ['id', 'vehicule_id', 'montant', 'date', 'mode'],
            },
          },
        },
        required: ['paiements'],
      },
    },
  },
  paths: {
    '/auth/login': {
      post: {
        tags: ['Auth'],
        summary: 'Connexion par PIN',
        requestBody: { content: { 'application/json': { schema: { $ref: '#/components/schemas/LoginRequest' } } } },
        responses: { '200': { description: 'Tokens JWT' } },
      },
    },
    '/auth/refresh': {
      post: {
        tags: ['Auth'],
        summary: 'Rafraîchir l\'access token',
        requestBody: { content: { 'application/json': { schema: { type: 'object', properties: { refresh_token: { type: 'string' } } } } } },
        responses: { '200': { description: 'Nouvel access token' } },
      },
    },
    '/auth/me': {
      get: {
        tags: ['Auth'],
        summary: 'Profil utilisateur',
        security: [{ bearerAuth: [] }],
        responses: { '200': { description: 'Données utilisateur' } },
      },
    },
    '/chauffeurs': {
      get: {
        tags: ['Chauffeurs'],
        summary: 'Lister les chauffeurs',
        security: [{ bearerAuth: [] }],
        responses: { '200': { description: 'Liste des chauffeurs' } },
      },
      post: {
        tags: ['Chauffeurs'],
        summary: 'Créer un chauffeur',
        security: [{ bearerAuth: [] }],
        responses: { '201': { description: 'Chauffeur créé' } },
      },
    },
    '/vehicules': {
      get: {
        tags: ['Véhicules'],
        summary: 'Lister les véhicules',
        security: [{ bearerAuth: [] }],
        responses: { '200': { description: 'Liste des véhicules' } },
      },
      post: {
        tags: ['Véhicules'],
        summary: 'Créer un véhicule',
        security: [{ bearerAuth: [] }],
        responses: { '201': { description: 'Véhicule créé' } },
      },
    },
    '/vehicules/{id}': {
      get: {
        tags: ['Véhicules'],
        summary: 'Détail d\'un véhicule',
        security: [{ bearerAuth: [] }],
        parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { '200': { description: 'Détail du véhicule' } },
      },
    },
    '/paiements': {
      get: {
        tags: ['Paiements'],
        summary: 'Lister les paiements',
        security: [{ bearerAuth: [] }],
        responses: { '200': { description: 'Liste des paiements' } },
      },
      post: {
        tags: ['Paiements'],
        summary: 'Enregistrer un paiement',
        security: [{ bearerAuth: [] }],
        requestBody: { content: { 'application/json': { schema: { $ref: '#/components/schemas/CreatePaiementRequest' } } } },
        responses: { '201': { description: 'Paiement créé' } },
      },
    },
    '/paiements/sync-batch': {
      post: {
        tags: ['Paiements'],
        summary: 'Synchronisation batch hors-ligne',
        description: 'Reçoit les paiements enregistrés hors-ligne. Déduplication par UUID mobile.',
        security: [{ bearerAuth: [] }],
        requestBody: { content: { 'application/json': { schema: { $ref: '#/components/schemas/SyncBatchRequest' } } } },
        responses: { '200': { description: 'Résultat de la sync' } },
      },
    },
    '/paiements/finance/dashboard': {
      get: {
        tags: ['Finance'],
        summary: 'Dashboard financier',
        security: [{ bearerAuth: [] }],
        responses: { '200': { description: 'KPIs financiers' } },
      },
    },
    '/incidents': {
      get: {
        tags: ['Incidents'],
        summary: 'Lister les incidents',
        security: [{ bearerAuth: [] }],
        responses: { '200': { description: 'Liste des incidents' } },
      },
      post: {
        tags: ['Incidents'],
        summary: 'Signaler un incident',
        security: [{ bearerAuth: [] }],
        responses: { '201': { description: 'Incident créé' } },
      },
    },
    '/salaires': {
      get: {
        tags: ['Salaires'],
        summary: 'Lister les salaires',
        security: [{ bearerAuth: [] }],
        responses: { '200': { description: 'Liste des salaires' } },
      },
      post: {
        tags: ['Salaires'],
        summary: 'Enregistrer un salaire',
        security: [{ bearerAuth: [] }],
        responses: { '201': { description: 'Salaire créé' } },
      },
    },
    '/dashboard': {
      get: {
        tags: ['Dashboard'],
        summary: 'Vue d\'ensemble',
        security: [{ bearerAuth: [] }],
        responses: { '200': { description: 'KPIs globaux' } },
      },
    },
  },
};
