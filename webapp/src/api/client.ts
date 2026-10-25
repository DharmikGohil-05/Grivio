// Single fetch wrapper for every GRIVIO API call.
//
// Contract (identical to the mobile ApiClient):
//  - JSON in, JSON out; the backend always answers { success, message?, ... }
//  - Authorization: Bearer <JWT> is attached only when a token is provided,
//    so login/register send no credentials.
//  - success !== true throws ApiError carrying the server's safe message.
import { API_BASE_URL } from '../config';

export class ApiError extends Error {
  constructor(message: string, readonly statusCode?: number) {
    super(message);
    this.name = 'ApiError';
  }
}

let authToken: string | null = null;

// The AuthContext installs the token once; every request below reads it.
export function setAuthToken(token: string | null) {
  authToken = token;
}

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

async function request<T = Record<string, unknown>>(
  path: string,
  method: Method = 'GET',
  body?: Record<string, unknown>,
): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`${API_BASE_URL}${path}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(authToken ? { Authorization: `Bearer ${authToken}` } : {}),
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
  } catch {
    // Network-level failure (offline, DNS, CORS misconfig…).
    throw new ApiError('Could not reach the server. Check your connection and try again.');
  }

  let json: any;
  try {
    json = await res.json();
  } catch {
    throw new ApiError(`Unexpected response from the server (${res.status}).`, res.status);
  }

  if (json?.success === true) return json as T;
  throw new ApiError(
    (typeof json?.message === 'string' && json.message) || 'Request failed.',
    res.status,
  );
}

export const api = {
  get: <T = Record<string, unknown>>(path: string) => request<T>(path, 'GET'),
  post: <T = Record<string, unknown>>(path: string, body?: Record<string, unknown>) =>
    request<T>(path, 'POST', body),
  put: <T = Record<string, unknown>>(path: string, body?: Record<string, unknown>) =>
    request<T>(path, 'PUT', body),
  patch: <T = Record<string, unknown>>(path: string, body?: Record<string, unknown>) =>
    request<T>(path, 'PATCH', body),
  del: <T = Record<string, unknown>>(path: string) => request<T>(path, 'DELETE'),
};
