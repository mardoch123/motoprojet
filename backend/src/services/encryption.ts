import crypto from 'node:crypto';
import { config } from '../config/env.js';
import { logger } from '../utils/logger.js';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16;

/**
 * Service de chiffrement/déchiffrement des données sensibles au repos.
 * Utilise AES-256-GCM avec un IV unique par chiffrement.
 * Format de sortie : iv:authTag:encryptedData (tout en base64)
 */
function getEncryptionKey(): Buffer {
  const key = config.encryption.key;
  if (!key || key.length < 32) {
    throw new Error('ENCRYPTION_KEY manquante ou trop courte (min 32 caractères)');
  }
  // Dérive une clé de 32 bytes à partir de la clé env (si elle est plus longue)
  return crypto.scryptSync(key, 'motoprojet-salt', 32);
}

/**
 * Chiffre une chaîne de caractères avec AES-256-GCM.
 * Retourne le format : iv:authTag:ciphertext (base64)
 */
export function encrypt(plaintext: string): string {
  if (!plaintext) return plaintext;
  try {
    const key = getEncryptionKey();
    const iv = crypto.randomBytes(IV_LENGTH);
    const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

    let encrypted = cipher.update(plaintext, 'utf8', 'base64');
    encrypted += cipher.final('base64');

    const authTag = cipher.getAuthTag().toString('base64');

    return `${iv.toString('base64')}:${authTag}:${encrypted}`;
  } catch (err: any) {
    logger.error('Erreur chiffrement', { error: err.message });
    throw err;
  }
}

/**
 * Déchiffre une chaîne chiffrée avec AES-256-GCM.
 * Attend le format : iv:authTag:ciphertext (base64)
 */
export function decrypt(encryptedText: string): string {
  if (!encryptedText) return encryptedText;

  // Si le texte ne contient pas le format chiffré, retourner tel quel
  // (rétrocompatibilité avec les données non chiffrées)
  const parts = encryptedText.split(':');
  if (parts.length !== 3) return encryptedText;

  try {
    const key = getEncryptionKey();
    const [ivB64, authTagB64, ciphertext] = parts;

    const iv = Buffer.from(ivB64, 'base64');
    const authTag = Buffer.from(authTagB64, 'base64');

    if (iv.length !== IV_LENGTH) return encryptedText;

    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
    decipher.setAuthTag(authTag);

    let decrypted = decipher.update(ciphertext, 'base64', 'utf8');
    decrypted += decipher.final('utf8');

    return decrypted;
  } catch {
    // Si le déchiffrement échoue, retourner le texte original
    // (probablement une donnée non chiffrée)
    return encryptedText;
  }
}

/**
 * Vérifie si une valeur est chiffrée (format iv:tag:cipher).
 */
export function isEncrypted(value: string): boolean {
  if (!value) return false;
  const parts = value.split(':');
  if (parts.length !== 3) return false;
  try {
    Buffer.from(parts[0], 'base64');
    Buffer.from(parts[1], 'base64');
    Buffer.from(parts[2], 'base64');
    return true;
  } catch {
    return false;
  }
}

/**
 * Hash SHA-256 d'une valeur (pour comparaison sans déchiffrement).
 */
export function hashForComparison(value: string): string {
  return crypto.createHash('sha256').update(value).digest('hex');
}
