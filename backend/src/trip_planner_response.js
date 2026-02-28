import { tryDecodeJson } from './planner_utils.js';

export function extractGeminiErrorMessage(decoded) {
  if (!decoded || typeof decoded !== 'object') {
    return null;
  }
  if (typeof decoded.message === 'string' && decoded.message.trim()) {
    return decoded.message.trim();
  }
  const error = decoded.error;
  if (typeof error === 'string' && error.trim()) {
    return error.trim();
  }
  if (error && typeof error === 'object') {
    if (typeof error.message === 'string' && error.message.trim()) {
      return error.message.trim();
    }
  }
  return null;
}

export function extractGeminiCandidateText(decoded) {
  if (!decoded || typeof decoded !== 'object') {
    return null;
  }
  if (!Array.isArray(decoded.candidates) || decoded.candidates.length === 0) {
    return null;
  }
  const firstCandidate = decoded.candidates[0];
  if (!firstCandidate?.content?.parts || !Array.isArray(firstCandidate.content.parts)) {
    return null;
  }
  const chunks = firstCandidate.content.parts
    .filter((part) => part && typeof part.text === 'string' && part.text.length > 0)
    .map((part) => part.text);
  return chunks.length > 0 ? chunks.join('') : null;
}

export function extractGeminiJsonObject(rawText) {
  const text = rawText.trim();
  if (!text) {
    return null;
  }
  const direct = tryDecodeJson(text);
  if (direct && typeof direct === 'object') {
    return direct;
  }
  const firstBrace = text.indexOf('{');
  const lastBrace = text.lastIndexOf('}');
  if (firstBrace === -1 || lastBrace === -1 || lastBrace <= firstBrace) {
    return null;
  }
  return tryDecodeJson(text.slice(firstBrace, lastBrace + 1));
}
