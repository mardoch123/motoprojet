import dotenv from 'dotenv';
dotenv.config();

function env(key: string, fallback?: string): string {
  const val = process.env[key] ?? fallback;
  if (val === undefined) throw new Error(`Variable d'environnement manquante : ${key}`);
  return val;
}

export const config = {
  port: parseInt(env('PORT', '3000'), 10),
  nodeEnv: env('NODE_ENV', 'development'),
  db: {
    url: env('DATABASE_URL'),
  },
  jwt: {
    accessSecret: env('JWT_ACCESS_SECRET'),
    refreshSecret: env('JWT_REFRESH_SECRET'),
    accessExpiresIn: env('JWT_ACCESS_EXPIRES_IN', '15m'),
    refreshExpiresIn: env('JWT_REFRESH_EXPIRES_IN', '7d'),
  },
  sms: {
    provider: env('SMS_PROVIDER', 'log'), // 'twilio' | 'log' (fallback)
    twilioAccountSid: env('TWILIO_ACCOUNT_SID', ''),
    twilioAuthToken: env('TWILIO_AUTH_TOKEN', ''),
    twilioPhoneNumber: env('TWILIO_PHONE_NUMBER', ''),
  },
  whatsapp: {
    enabled: env('WHATSAPP_ENABLED', 'false') === 'true',
    baseUrl: env('WHATSAPP_API_URL', ''),
    token: env('WHATSAPP_API_TOKEN', ''),
  },
  ia: {
    provider: env('IA_PROVIDER', 'deepseek'), // 'deepseek' | 'claude'
    deepseekApiKey: env('DEEPSEEK_API_KEY', ''),
    deepseekBaseUrl: env('DEEPSEEK_BASE_URL', 'https://api.deepseek.com'),
    deepseekModel: env('DEEPSEEK_MODEL', 'deepseek-chat'),
    claudeApiKey: env('CLAUDE_API_KEY', ''),
    claudeModel: env('CLAUDE_MODEL', 'claude-sonnet-4-20250514'),
  },
  kkiapay: {
    apiKey: env('KKIAPAY_API_KEY', ''),
    publicKey: env('KKIAPAY_PUBLIC_KEY', ''),
    apiUrl: env('KKIAPAY_API_URL', 'https://api.kkiapay.io'),
    webhookSecret: env('KKIAPAY_WEBHOOK_SECRET', ''),
    sandbox: env('KKIAPAY_SANDBOX', 'true') === 'true',
  },
  fcm: {
    serverKey: env('FCM_SERVER_KEY', ''),
  },
  encryption: {
    key: env('ENCRYPTION_KEY', ''),
  },
  sentry: {
    dsn: env('SENTRY_DSN', ''),
    environment: env('SENTRY_ENVIRONMENT', env('NODE_ENV', 'development')),
    tracesSampleRate: parseFloat(env('SENTRY_TRACES_SAMPLE_RATE', '0.2')),
    enabled: env('SENTRY_ENABLED', 'false') === 'true',
  },
  monitoring: {
    alertWebhookUrl: env('MONITORING_ALERT_WEBHOOK_URL', ''),
    alertEmailTo: env('MONITORING_ALERT_EMAIL_TO', ''),
    slowQueryThresholdMs: parseInt(env('MONITORING_SLOW_QUERY_MS', '1000'), 10),
    errorRateThreshold: parseFloat(env('MONITORING_ERROR_RATE_THRESHOLD', '5')),
    latencyThresholdMs: parseInt(env('MONITORING_LATENCY_THRESHOLD_MS', '3000'), 10),
  },
} as const;
