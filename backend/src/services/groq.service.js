// Groq AI service — the ONLY place in the backend that talks to Groq.
// Flutter never calls Groq directly; it goes through this service via
// authenticated API routes. The API key is read from the environment and
// never logged, returned, or exposed in errors.
const config = require('../config/env');

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

  const model = config.groqModel || DEFAULT_MODEL;
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
  if (response.status === 401 || response.status === 403) {
    throw aiError(503, 'AI service authentication failed. Contact support.');
  }
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

  const model = config.groqModel || DEFAULT_MODEL;
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
        temperature: 0.4,
        max_completion_tokens: maxTokens,
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

  if (response.status === 401 || response.status === 403) {
    throw aiError(503, 'AI service authentication failed. Contact support.');
  }
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
