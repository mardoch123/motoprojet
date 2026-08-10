import { Response, NextFunction } from 'express';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { v4 as uuidv4 } from 'uuid';
import { AppError } from '../utils/errors.js';
import type { AuthRequest } from '../types/index.js';

// ─── Client S3 compatible R2 (Cloudflare) ────────────────────────────────────
const R2_ENDPOINT = process.env.R2_ENDPOINT ?? '';
const R2_ACCESS_KEY = process.env.R2_ACCESS_KEY ?? '';
const R2_SECRET_KEY = process.env.R2_SECRET_KEY ?? '';
const R2_BUCKET = process.env.R2_BUCKET ?? 'motoprojet';
const R2_PUBLIC_URL = process.env.R2_PUBLIC_URL ?? '';

function getS3Client(): S3Client | null {
  if (!R2_ENDPOINT || !R2_ACCESS_KEY || !R2_SECRET_KEY) return null;
  return new S3Client({
    region: 'auto',
    endpoint: R2_ENDPOINT,
    credentials: {
      accessKeyId: R2_ACCESS_KEY,
      secretAccessKey: R2_SECRET_KEY,
    },
  });
}

/**
 * POST /api/v1/upload/presign
 * Génère une URL signée pour upload direct vers R2/S3.
 * Le client upload directement, puis utilise l'URL publique retournée.
 *
 * Body : { filename: "photo.jpg", contentType: "image/jpeg" }
 * Response : { upload_url, public_url, key }
 */
export async function presignUpload(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { filename, contentType } = req.body;

    if (!filename || !contentType) {
      throw AppError.badRequest('filename et contentType requis');
    }

    if (!contentType.startsWith('image/')) {
      throw AppError.badRequest('Seules les images sont acceptées');
    }

    const client = getS3Client();
    if (!client) {
      // Mode développement : retourne une URL factice
      const key = `uploads/${uuidv4()}-${filename}`;
      res.json({
        success: true,
        data: {
          upload_url: `https://dev.motoprojet.bj/upload/${key}`,
          public_url: `https://dev.motoprojet.bj/files/${key}`,
          key,
          mode: 'mock',
        },
      });
      return;
    }

    const key = `uploads/${uuidv4()}-${filename}`;

    const command = new PutObjectCommand({
      Bucket: R2_BUCKET,
      Key: key,
      ContentType: contentType,
    });

    const uploadUrl = await getSignedUrl(client, command, { expiresIn: 300 }); // 5 min

    const publicUrl = R2_PUBLIC_URL
      ? `${R2_PUBLIC_URL}/${key}`
      : `${R2_ENDPOINT}/${R2_BUCKET}/${key}`;

    res.json({
      success: true,
      data: {
        upload_url: uploadUrl,
        public_url: publicUrl,
        key,
        expires_in: 300,
      },
    });
  } catch (err) { next(err); }
}
