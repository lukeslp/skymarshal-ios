/**
 * Validation utilities for Bluesky data
 * @module utils/validation
 */

/**
 * Search filter types (minimal interface for validation)
 */
export interface SearchFilters {
  contentType?: 'all' | 'posts' | 'replies' | 'likes' | 'reposts';
  keywords?: string[];
  minEngagement?: number;
  maxEngagement?: number;
  minLikes?: number;
  maxLikes?: number;
  minReposts?: number;
  maxReposts?: number;
  minReplies?: number;
  maxReplies?: number;
  startDate?: string;
  endDate?: string;
  authorDid?: string;
  excludedUris?: string[];
}

/**
 * Validate AT URI format
 *
 * @param uri - String to validate
 * @returns True if valid AT URI
 *
 * @example
 * isValidAtUri('at://did:plc:abc123/app.bsky.feed.post/3k2xyz') // true
 * isValidAtUri('https://bsky.app/profile/alice') // false
 */
export function isValidAtUri(uri: string): boolean {
  if (!uri || typeof uri !== 'string') {
    return false;
  }

  // AT URI format: at://did/collection/rkey
  const atUriRegex = /^at:\/\/did:[a-z0-9]+:[a-zA-Z0-9._-]+\/[a-z.]+\/[a-zA-Z0-9._-]+$/;
  return atUriRegex.test(uri);
}

/**
 * Validate Bluesky handle format
 *
 * @param handle - String to validate
 * @returns True if valid handle
 *
 * @example
 * isValidHandle('alice.bsky.social') // true
 * isValidHandle('alice') // true
 * isValidHandle('alice@bob') // false
 */
export function isValidHandle(handle: string): boolean {
  if (!handle || typeof handle !== 'string') {
    return false;
  }

  // Remove @ prefix if present
  const cleaned = handle.startsWith('@') ? handle.slice(1) : handle;

  // Handle can be simple username or domain format
  // Must be 1-253 chars, alphanumeric, dots, hyphens
  const handleRegex = /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;

  if (!handleRegex.test(cleaned)) {
    return false;
  }

  // Length check
  if (cleaned.length < 1 || cleaned.length > 253) {
    return false;
  }

  return true;
}

/**
 * Validate DID format
 *
 * @param did - String to validate
 * @returns True if valid DID
 *
 * @example
 * isValidDid('did:plc:abc123xyz') // true
 * isValidDid('did:web:example.com') // true
 * isValidDid('not-a-did') // false
 */
export function isValidDid(did: string): boolean {
  if (!did || typeof did !== 'string') {
    return false;
  }

  // DID format: did:method:identifier
  const didRegex = /^did:[a-z0-9]+:[a-zA-Z0-9._-]+$/;
  return didRegex.test(did);
}

/**
 * Validate and sanitize search filters
 *
 * @param filters - Partial search filters object
 * @returns Complete, validated search filters
 *
 * @example
 * validateSearchFilters({ minEngagement: -5, maxEngagement: 100 })
 * // { minEngagement: 0, maxEngagement: 100, ... }
 */
export function validateSearchFilters(filters: Partial<SearchFilters>): SearchFilters {
  const validated: SearchFilters = {
    contentType: filters.contentType || 'all',
    keywords: filters.keywords || [],
    minEngagement: Math.max(0, filters.minEngagement ?? 0),
    maxEngagement: Math.max(0, filters.maxEngagement ?? 999999),
    minLikes: Math.max(0, filters.minLikes ?? 0),
    maxLikes: Math.max(0, filters.maxLikes ?? 999999),
    minReposts: Math.max(0, filters.minReposts ?? 0),
    maxReposts: Math.max(0, filters.maxReposts ?? 999999),
    minReplies: Math.max(0, filters.minReplies ?? 0),
    maxReplies: Math.max(0, filters.maxReplies ?? 999999),
    startDate: filters.startDate,
    endDate: filters.endDate,
    authorDid: filters.authorDid,
    excludedUris: filters.excludedUris || []
  };

  // Validate content type
  const validTypes = ['all', 'posts', 'replies', 'likes', 'reposts'];
  if (!validTypes.includes(validated.contentType || '')) {
    validated.contentType = 'all';
  }

  // Validate min/max pairs (min <= max)
  if (validated.minEngagement! > validated.maxEngagement!) {
    [validated.minEngagement, validated.maxEngagement] = [validated.maxEngagement, validated.minEngagement];
  }
  if (validated.minLikes! > validated.maxLikes!) {
    [validated.minLikes, validated.maxLikes] = [validated.maxLikes, validated.minLikes];
  }
  if (validated.minReposts! > validated.maxReposts!) {
    [validated.minReposts, validated.maxReposts] = [validated.maxReposts, validated.minReposts];
  }
  if (validated.minReplies! > validated.maxReplies!) {
    [validated.minReplies, validated.maxReplies] = [validated.maxReplies, validated.minReplies];
  }

  // Validate dates
  if (validated.startDate) {
    try {
      new Date(validated.startDate);
    } catch {
      delete validated.startDate;
    }
  }
  if (validated.endDate) {
    try {
      new Date(validated.endDate);
    } catch {
      delete validated.endDate;
    }
  }

  // Validate DID if present
  if (validated.authorDid && !isValidDid(validated.authorDid)) {
    delete validated.authorDid;
  }

  // Validate excluded URIs
  if (validated.excludedUris) {
    validated.excludedUris = validated.excludedUris.filter(uri => isValidAtUri(uri));
  }

  return validated;
}

/**
 * Sanitize user input string
 * Removes potentially dangerous characters while preserving unicode
 *
 * @param input - Raw user input
 * @returns Sanitized string
 *
 * @example
 * sanitizeInput('<script>alert("xss")</script>') // 'scriptalert("xss")/script'
 * sanitizeInput('Hello\x00World') // 'HelloWorld'
 */
export function sanitizeInput(input: string): string {
  if (!input || typeof input !== 'string') {
    return '';
  }

  return input
    // Remove null bytes
    .replace(/\x00/g, '')
    // Remove control characters (but keep newlines and tabs)
    .replace(/[\x01-\x08\x0B-\x0C\x0E-\x1F\x7F]/g, '')
    // Remove HTML tags
    .replace(/<[^>]*>/g, '')
    // Trim whitespace
    .trim();
}

/**
 * Validate engagement score
 *
 * @param score - Engagement score to validate
 * @returns True if valid (non-negative number)
 */
export function isValidEngagementScore(score: number): boolean {
  return typeof score === 'number' && !isNaN(score) && score >= 0;
}

/**
 * Validate timestamp
 *
 * @param timestamp - Unix timestamp in milliseconds
 * @returns True if valid timestamp
 */
export function isValidTimestamp(timestamp: number): boolean {
  if (typeof timestamp !== 'number' || isNaN(timestamp)) {
    return false;
  }

  // Reasonable range: Jan 1, 2000 to 100 years from now
  const minTimestamp = new Date('2000-01-01').getTime();
  const maxTimestamp = Date.now() + (100 * 365 * 24 * 60 * 60 * 1000);

  return timestamp >= minTimestamp && timestamp <= maxTimestamp;
}

/**
 * Validate URL string
 *
 * @param url - URL string to validate
 * @returns True if valid URL
 */
export function isValidUrl(url: string): boolean {
  if (!url || typeof url !== 'string') {
    return false;
  }

  try {
    const parsed = new URL(url);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
}

/**
 * Validate content type
 *
 * @param type - Content type string
 * @returns True if valid content type
 */
export function isValidContentType(type: string): boolean {
  const validTypes = ['post', 'reply', 'like', 'repost', 'all', 'posts', 'replies', 'likes', 'reposts'];
  return validTypes.includes(type);
}

/**
 * Validate keyword array
 *
 * @param keywords - Array of search keywords
 * @returns Sanitized keyword array
 */
export function validateKeywords(keywords: unknown): string[] {
  if (!Array.isArray(keywords)) {
    return [];
  }

  return keywords
    .filter(k => typeof k === 'string')
    .map(k => sanitizeInput(k))
    .filter(k => k.length > 0);
}

/**
 * Validate number is within range
 *
 * @param value - Number to validate
 * @param min - Minimum value (inclusive)
 * @param max - Maximum value (inclusive)
 * @returns Clamped value within range
 */
export function clampNumber(value: number, min: number, max: number): number {
  if (typeof value !== 'number' || isNaN(value)) {
    return min;
  }
  return Math.max(min, Math.min(max, value));
}

/**
 * Validate and normalize pagination options
 *
 * @param limit - Items per page
 * @param offset - Offset from start
 * @returns Validated pagination options
 */
export function validatePagination(limit?: number, offset?: number): { limit: number; offset: number } {
  return {
    limit: clampNumber(limit ?? 50, 1, 1000),
    offset: clampNumber(offset ?? 0, 0, Number.MAX_SAFE_INTEGER)
  };
}
