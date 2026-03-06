import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const ROOCOIN_BASE_URL =
  (Deno.env.get('ROOCOIN_BASE_URL') ?? 'https://roobit.rooverse.app').trim();
const ROOCOIN_API_KEY = (Deno.env.get('ROOCOIN_API_KEY') ?? '').trim();
const PROXY_BUILD = '2026-03-06-send-debug-1';

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
      'x-roocoin-proxy-build': PROXY_BUILD,
    },
  });
}

function normalizeBaseUrl(url: string) {
  return url.endsWith('/') ? url.slice(0, -1) : url;
}

function isValidPath(path: string) {
  const allowedExactPaths = ['/health'];
  const allowedApiPrefix = path.startsWith('/api/');

  return (
    (allowedApiPrefix || allowedExactPaths.includes(path)) &&
    !path.includes('..') &&
    !path.includes('\\')
  );
}

function asRecord(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === 'object'
    ? (value as Record<string, unknown>)
    : {};
}

function firstString(
  input: Record<string, unknown>,
  keys: string[],
): string | undefined {
  for (const key of keys) {
    const value = input[key];
    if (typeof value === 'string') {
      const trimmed = value.trim();
      if (trimmed.length > 0) {
        return trimmed;
      }
    }
  }
  return undefined;
}

function firstNumberLike(
  input: Record<string, unknown>,
  keys: string[],
): string | undefined {
  for (const key of keys) {
    const value = input[key];
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value.toString();
    }
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
  }
  return undefined;
}

function normalizeSendBody(body: unknown) {
  const input = asRecord(body);

  const toAddress = firstString(input, ['toAddress', 'to', 'target', 'address']);
  const fromPrivateKey = firstString(input, [
    'fromPrivateKey',
    'privateKey',
    'userPrivateKey',
  ]);
  const amount = firstNumberLike(input, ['amount', 'value']);
  const metadata = asRecord(input.metadata);
  const metadataToAddress = firstString(metadata, [
    'toAddress',
    'to',
    'target',
    'recipientAddress',
    'recipient',
  ]);
  const resolvedToAddress = toAddress ?? metadataToAddress;

  return {
    ...input,
    ...(resolvedToAddress
      ? {
          toAddress: resolvedToAddress,
          to: resolvedToAddress,
          target: resolvedToAddress,
          address: resolvedToAddress,
          recipientAddress: resolvedToAddress,
          recipient: resolvedToAddress,
          destination: resolvedToAddress,
          toWalletAddress: resolvedToAddress,
        }
      : {}),
    ...(fromPrivateKey
      ? {
          fromPrivateKey,
          privateKey: fromPrivateKey,
          userPrivateKey: fromPrivateKey,
        }
      : {}),
    ...(amount ? { amount, value: amount } : {}),
  };
}

function sanitizedBodyForLog(path: string, body: unknown) {
  const input = asRecord(body);
  if (path !== '/api/wallet/send') {
    return input;
  }
  return {
    ...input,
    fromPrivateKey:
      typeof input.fromPrivateKey === 'string' && input.fromPrivateKey.trim()
        ? '[REDACTED]'
        : undefined,
    privateKey:
      typeof input.privateKey === 'string' && input.privateKey.trim()
        ? '[REDACTED]'
        : undefined,
    userPrivateKey:
      typeof input.userPrivateKey === 'string' && input.userPrivateKey.trim()
        ? '[REDACTED]'
        : undefined,
  };
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse(405, { error: 'Method not allowed' });
  }

  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    return jsonResponse(500, {
      error: 'Missing Supabase environment variables',
    });
  }

  if (!ROOCOIN_API_KEY) {
    return jsonResponse(500, {
      error: 'Missing ROOCOIN_API_KEY secret',
    });
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();

  console.log('authHeader exists:', !!authHeader);
  console.log('token length:', token.length);
  console.log('proxy build:', PROXY_BUILD);

  if (!token) {
    return jsonResponse(401, { error: 'Missing bearer token' });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser(token);

  console.log('authError:', authError?.message ?? null);
  console.log('userId:', user?.id ?? null);

  if (authError || !user) {
    return jsonResponse(401, {
      error: 'Unauthorized',
      details: authError?.message ?? 'No user returned from token',
    });
  }

  let payload: {
    path?: string;
    method?: string;
    body?: unknown;
  };

  try {
    payload = await req.json();
  } catch (_) {
    return jsonResponse(400, { error: 'Invalid JSON body' });
  }

  const path = payload.path;
  const method = (payload.method ?? 'GET').toUpperCase();
  const originalBody = payload.body;

  if (typeof path !== 'string' || !isValidPath(path)) {
    return jsonResponse(400, { error: 'Invalid or missing path' });
  }

  if (!['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
    return jsonResponse(400, { error: 'Invalid HTTP method' });
  }

  const upstreamUrl = `${normalizeBaseUrl(ROOCOIN_BASE_URL)}${path}`;

  // Forward authenticated user identity for all requests.
  // /api/wallet/send also gets x-sender-user-id as a compatibility alias.
  const headers: Record<string, string> = {
    Accept: 'application/json',
    'x-api-key': ROOCOIN_API_KEY,
    'x-user-id': user.id,
  };

  if (path === '/api/wallet/send') {
    headers['x-sender-user-id'] = user.id;
  }

  if (method !== 'GET') {
    headers['Content-Type'] = 'application/json';
  }

  const body = path === '/api/wallet/send'
    ? normalizeSendBody(originalBody)
    : originalBody;

  if (path === '/api/wallet/send') {
    const sendBody = asRecord(body);
    const target = firstString(sendBody, [
      'toAddress',
      'to',
      'target',
      'recipientAddress',
      'recipient',
      'destination',
      'toWalletAddress',
      'address',
    ]);
    const key = firstString(sendBody, [
      'fromPrivateKey',
      'privateKey',
      'userPrivateKey',
    ]);
    const amount = firstNumberLike(sendBody, ['amount', 'value']);

    if (!target || !key || !amount) {
      return jsonResponse(400, {
        error: 'Invalid send payload',
        details: {
          hasTarget: !!target,
          hasPrivateKey: !!key,
          hasAmount: !!amount,
          bodyKeys: Object.keys(sendBody),
        },
      });
    }
  }

  console.log('forwarding to:', upstreamUrl);
  console.log('forwarding method:', method);
  console.log('forwarding headers:', JSON.stringify(headers));
  console.log(
    'forwarding body:',
    method === 'GET' ? null : JSON.stringify(sanitizedBodyForLog(path, body)),
  );

  try {
    const upstreamResponse = await fetch(upstreamUrl, {
      method,
      headers,
      body: method === 'GET' ? undefined : JSON.stringify(body ?? {}),
    });

    const text = await upstreamResponse.text();
    const contentType =
      upstreamResponse.headers.get('content-type') ?? 'application/json';

    console.log('upstream status:', upstreamResponse.status);
    console.log('upstream response text:', text);

    if (
      path === '/api/wallet/send' &&
      text.toLowerCase().includes('unsupported addressable value') &&
      text.toLowerCase().includes('target')
    ) {
      const sendBody = asRecord(body);
      const target = firstString(sendBody, [
        'toAddress',
        'to',
        'target',
        'recipientAddress',
        'recipient',
        'destination',
        'toWalletAddress',
        'address',
      ]);
      const amount = firstNumberLike(sendBody, ['amount', 'value']);
      const hasPrivateKey = !!firstString(sendBody, [
        'fromPrivateKey',
        'privateKey',
        'userPrivateKey',
      ]);

      return jsonResponse(upstreamResponse.status, {
        error: 'Upstream send failed with null target',
        details: {
          proxyBuild: PROXY_BUILD,
          forwarded: {
            toAddress: target ?? null,
            amount: amount ?? null,
            hasPrivateKey,
          },
          upstream: text,
        },
      });
    }

    return new Response(text, {
      status: upstreamResponse.status,
      headers: {
        ...corsHeaders,
        'Content-Type': contentType,
        'x-roocoin-proxy-build': PROXY_BUILD,
      },
    });
  } catch (error) {
    console.error('proxy fetch failed:', error);

    return jsonResponse(502, {
      error: 'Upstream request failed',
      details: error instanceof Error ? error.message : String(error),
    });
  }
});
