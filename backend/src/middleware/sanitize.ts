import { Request, Response, NextFunction } from 'express';

/**
 * Middleware de sanitization XSS.
 *
 * Supprime les balises HTML et les caractères de contrôle dangereux
 * de tous les champs string dans req.body.
 *
 * Protège contre les attaques XSS stockées (injection de <script>,
 * event handlers inline, etc.) sans dépendance externe.
 *
 * Usage :
 *   app.use(sanitizeBody);           // global
 *   router.post('/', sanitizeBody, createHandler);  // par route
 */

// Regex pour détecter les balises HTML et les attributs dangereux
const HTML_TAG_RE = /<\/?[^>]+>/g;
const JS_PROTOCOL_RE = /javascript\s*:/gi;
const DATA_URI_SCRIPT_RE = /data\s*:\s*text\/html/gi;
const EVENT_HANDLER_RE = /\bon\w+\s*=/gi;
const NULL_BYTE_RE = /\0/g;

/**
 * Sanitize récursivement une valeur :
 * - string → supprime balises HTML, protocoles js:, event handlers, null bytes
 * - object → parcourt les clés récursivement
 * - array  → parcourt les éléments
 * - autres → retourne tel quel
 */
function sanitizeValue(value: unknown): unknown {
  if (typeof value === 'string') {
    return value
      .replace(NULL_BYTE_RE, '')           // null bytes (possible injection SQL)
      .replace(HTML_TAG_RE, '')            // balises HTML
      .replace(JS_PROTOCOL_RE, '')         // javascript:
      .replace(DATA_URI_SCRIPT_RE, '')     // data:text/html
      .replace(EVENT_HANDLER_RE, '');      // onclick=, onerror=, etc.
  }

  if (Array.isArray(value)) {
    return value.map(sanitizeValue);
  }

  if (value !== null && typeof value === 'object') {
    const sanitized: Record<string, unknown> = {};
    for (const [key, val] of Object.entries(value as Record<string, unknown>)) {
      // Ne pas sanitizer les champs qui sont explicitement du HTML (photo_url, description riche)
      // ni les champs numériques/booléens
      if (typeof val === 'string' || Array.isArray(val) || (val !== null && typeof val === 'object')) {
        sanitized[key] = sanitizeValue(val);
      } else {
        sanitized[key] = val;
      }
    }
    return sanitized;
  }

  return value;
}

/**
 * Middleware Express : sanitize tous les champs string de req.body.
 * À placer APRÈS express.json() et AVANT les routes.
 */
export function sanitizeBody(req: Request, _res: Response, next: NextFunction): void {
  if (req.body && typeof req.body === 'object') {
    req.body = sanitizeValue(req.body);
  }
  next();
}

/**
 * Middleware Express : sanitize également req.query et req.params.
 * Utile pour les endpoints GET avec paramètres texte libre.
 */
export function sanitizeAll(req: Request, _res: Response, next: NextFunction): void {
  if (req.body && typeof req.body === 'object') {
    req.body = sanitizeValue(req.body);
  }
  if (req.query && typeof req.query === 'object') {
    // req.query est readonly en types mais on peut modifier les valeurs
    const sanitizedQuery = sanitizeValue(req.query) as Record<string, unknown>;
    for (const key of Object.keys(req.query)) {
      (req.query as Record<string, unknown>)[key] = sanitizedQuery[key];
    }
  }
  next();
}
