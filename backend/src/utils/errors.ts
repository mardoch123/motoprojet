/**
 * Classe d'erreur standardisée pour l'API
 */
export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: string;

  constructor(statusCode: number, message: string, code?: string) {
    super(message);
    this.statusCode = statusCode;
    this.code = code ?? 'UNKNOWN_ERROR';
    Object.setPrototypeOf(this, AppError.prototype);
  }

  static badRequest(message: string) { return new AppError(400, message, 'BAD_REQUEST'); }
  static unauthorized(message = 'Non authentifié') { return new AppError(401, message, 'UNAUTHORIZED'); }
  static forbidden(message = 'Accès refusé') { return new AppError(403, message, 'FORBIDDEN'); }
  static notFound(message = 'Ressource non trouvée') { return new AppError(404, message, 'NOT_FOUND'); }
  static conflict(message: string) { return new AppError(409, message, 'CONFLICT'); }
  static unprocessable(message: string) { return new AppError(422, message, 'UNPROCESSABLE'); }
  static tooMany() { return new AppError(429, 'Trop de requêtes', 'TOO_MANY_REQUESTS'); }
  static internal(message = 'Erreur serveur') { return new AppError(500, message, 'INTERNAL_ERROR'); }
}
