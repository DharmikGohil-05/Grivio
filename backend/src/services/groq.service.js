// Groq AI service — the ONLY place in the backend that talks to Groq.
// Flutter never calls Groq directly; it goes through this service via
// authenticated API routes. The API key is read from the environment and
// never logged, returned, or exposed in errors.
const config = require('../config/env');

// Native fetch (built into Node 18+) is used deliberately: one outbound
// HTTPS call doesn't justify adding an HTTP client dependency.
const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const DEFAULT_MODEL = 'openai/gpt-oss-120b';
const REQUEST_TIMEOUT_MS = 30000; // 30s — generous but bounded
const DEFAULT_MAX_TOKENS = 1024;

// Normalized error with a safe statusCode + message. Never includes
// provider internals, stack traces, or credentials.
function aiError(statusCode, message) {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
}

/**
 * Sends a chat completion request to Groq and returns normalized text.
 * Throws an aiError with a safe statusCode on any failure.
 *
 * @param {string} prompt - user prompt (already validated by the controller)
 * @param {object} opts - { systemPrompt, maxTokens }
 * @returns {Promise<{text: string, model: string}>}
 */
async function generateText(prompt, { systemPrompt, maxTokens = DEFAULT_MAX_TOKENS } = {}) {
  // Missing configuration → safe 503, server keeps running.
  if (!config.groqApiKey) {
    throw aiError(503, 'AI service is not configured. Set GROQ_API_KEY on the backend.');
  }

  // GROQ_MODEL (read via config) overrides the default model when set,
  // so deployments can swap models without code changes.
  const model = config.groqModel || DEFAULT_MODEL;
  // AbortController acts as a hard deadline: after 30s the pending fetch
  // is cancelled, so a hung provider can't keep the request open forever.
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  let response;
  try {
    response = await fetch(GROQ_API_URL, {
      method: 'POST',
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${config.groqApiKey}`,
      },
      body: JSON.stringify({
        model,
        messages: [
          ...(systemPrompt ? [{ role: 'system', content: systemPrompt }] : []),
          { role: 'user', content: prompt },
        ],
        // Low-ish temperature: productivity suggestions should be
        // consistent and practical, not wildly creative.
        temperature: 0.4,
        max_completion_tokens: maxTokens,
      }),
    });
  } catch (err) {
    clearTimeout(timeout);
    if (err.name === 'AbortError') {
      throw aiError(504, 'AI request timed out. Please try again.');
    }
    // Network/DNS failure — never leak the underlying error.
    throw aiError(502, 'AI service is unreachable. Please try again later.');
  }
  clearTimeout(timeout);

  // Map provider status codes to safe, consistent errors.
  // 401/403 mean OUR key is wrong or revoked — a server-side config
  // problem, so it is surfaced as 503 (service unavailable), never as a
  // client error and never with provider details attached.
  if (response.status === 401 || response.status === 403) {
    throw aiError(503, 'AI service authentication failed. Contact support.');
  }
  // Provider rate limits are passed through as 429 so the client can show
  // an honest "wait a moment" state instead of a generic failure.
  if (response.status === 429) {
    throw aiError(429, 'AI rate limit reached. Please wait a moment and try again.');
  }
  if (response.status >= 500) {
    throw aiError(502, 'AI provider is temporarily unavailable. Please try again later.');
  }
  if (!response.ok) {
    throw aiError(502, 'AI request failed. Please try again.');
  }

  let data;
  try {
    data = await response.json();
  } catch {
    throw aiError(502, 'AI returned an unreadable response.');
  }

  // Treat provider output as untrusted: validate before returning.
  const text = data?.choices?.[0]?.message?.content;
  if (typeof text !== 'string' || !text.trim()) {
    throw aiError(502, 'AI returned an empty response.');
  }

  return { text: text.trim(), model };
}

/**
 * Like generateText but requests structured JSON output and parses it
 * safely. Returns the parsed object, or throws aiError(502) if the
 * provider returns anything unparseable.
 */
async function generateJson(prompt, { systemPrompt, maxTokens = DEFAULT_MAX_TOKENS } = {}) {
  if (!config.groqApiKey) {
    throw aiError(503, 'AI service is not configured. Set GROQ_API_KEY on the backend.');
  }

  // GROQ_MODEL (read via config) overrides the default model when set,
  // so deployments can swap models without code changes.
  const model = config.groqModel || DEFAULT_MODEL;
  // AbortController acts as a hard deadline: after 30s the pending fetch
  // is cancelled, so a hung provider can't keep the request open forever.
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  let response;
  try {
    response = await fetch(GROQ_API_URL, {
      method: 'POST',
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${config.groqApiKey}`,
      },
      body: JSON.stringify({
        model,
        messages: [
          ...(systemPrompt ? [{ role: 'system', content: systemPrompt }] : []),
          { role: 'user', content: prompt },
        ],
        // Low-ish temperature: productivity suggestions should be
        // consistent and practical, not wildly creative.
        temperature: 0.4,
        max_completion_tokens: maxTokens,
        // JSON mode asks the API to constrain output to valid JSON —
        // this reduces but does not guarantee parseable replies, which
        // is why the parsing below still fails safe with a 502.
        response_format: { type: 'json_object' },
      }),
    });
  } catch (err) {
    clearTimeout(timeout);
    if (err.name === 'AbortError') {
      throw aiError(504, 'AI request timed out. Please try again.');
    }
    throw aiError(502, 'AI service is unreachable. Please try again later.');
  }
  clearTimeout(timeout);

  // 401/403 mean OUR key is wrong or revoked — a server-side config
  // problem, so it is surfaced as 503 (service unavailable), never as a
  // client error and never with provider details attached.
  if (response.status === 401 || response.status === 403) {
    throw aiError(503, 'AI service authentication failed. Contact support.');
  }
  // Provider rate limits are passed through as 429 so the client can show
  // an honest "wait a moment" state instead of a generic failure.
  if (response.status === 429) {
    throw aiError(429, 'AI rate limit reached. Please wait a moment and try again.');
  }
  if (response.status >= 500) {
    throw aiError(502, 'AI provider is temporarily unavailable. Please try again later.');
  }
  if (!response.ok) {
    throw aiError(502, 'AI request failed. Please try again.');
  }

  let data;
  try {
    data = await response.json();
  } catch {
    throw aiError(502, 'AI returned an unreadable response.');
  }

  // The model may embed the JSON inside a message string — try both shapes.
  let parsed = data;
  if (typeof data?.choices?.[0]?.message?.content === 'string') {
    try {
      parsed = JSON.parse(data.choices[0].message.content);
    } catch {
      throw aiError(502, 'AI returned malformed structured output.');
    }
  }
  if (parsed === null || typeof parsed !== 'object') {
    throw aiError(502, 'AI returned malformed structured output.');
  }
  return parsed;
}

module.exports = { generateText, generateJson, DEFAULT_MODEL };
