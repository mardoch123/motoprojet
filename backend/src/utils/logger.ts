/**
 * Logger structuré JSON pour chaque requête sensible.
 * Compatible avec les agrégateurs de logs (Datadog, ELK, etc.)
 */
export function logJson(level: string, message: string, data?: Record<string, unknown>): void {
  const entry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...data,
  };
  const line = JSON.stringify(entry);
  if (level === 'error') console.error(line);
  else if (level === 'warn') console.warn(line);
  else console.log(line);
}

export const logger = {
  info: (msg: string, data?: Record<string, unknown>) => logJson('info', msg, data),
  warn: (msg: string, data?: Record<string, unknown>) => logJson('warn', msg, data),
  error: (msg: string, data?: Record<string, unknown>) => logJson('error', msg, data),
  audit: (userId: string, action: string, cible: string, details?: Record<string, unknown>) =>
    logJson('audit', `${action} on ${cible}`, { user_id: userId, action, cible, details }),
};
