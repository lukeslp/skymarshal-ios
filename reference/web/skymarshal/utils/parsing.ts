/**
 * Parsing utilities for dates, URIs, and handles
 * @module utils/parsing
 */

/**
 * Parse date string to Date object
 * Supports ISO8601 and YYYY-MM-DD formats
 *
 * @param dateString - ISO8601 or YYYY-MM-DD date string
 * @returns Parsed Date object
 * @throws Error if date string is invalid
 *
 * @example
 * parseDate('2024-01-15') // Date object for 2024-01-15
 * parseDate('2024-01-15T10:30:00Z') // Date object with time
 */
export function parseDate(dateString: string): Date {
  if (!dateString || typeof dateString !== 'string') {
    throw new Error('Invalid date string: must be a non-empty string');
  }

  const date = new Date(dateString);

  if (isNaN(date.getTime())) {
    throw new Error(`Invalid date string: ${dateString}`);
  }

  return date;
}

/**
 * Format date to specified format
 *
 * @param date - Date object to format
 * @param format - Output format ('iso' | 'short' | 'long')
 * @returns Formatted date string
 *
 * @example
 * formatDate(new Date('2024-01-15'), 'iso') // '2024-01-15T00:00:00.000Z'
 * formatDate(new Date('2024-01-15'), 'short') // '2024-01-15'
 * formatDate(new Date('2024-01-15'), 'long') // 'January 15, 2024'
 */
export function formatDate(date: Date, format: 'iso' | 'short' | 'long'): string {
  if (!(date instanceof Date) || isNaN(date.getTime())) {
    throw new Error('Invalid date object');
  }

  switch (format) {
    case 'iso':
      return date.toISOString();

    case 'short':
      return date.toISOString().split('T')[0];

    case 'long':
      return new Intl.DateTimeFormat('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      }).format(date);

    default:
      throw new Error(`Unknown format: ${format}`);
  }
}

/**
 * AT URI components
 */
export interface AtUriComponents {
  did: string;
  collection: string;
  rkey: string;
}

/**
 * Parse AT URI into components
 * Format: at://did:plc:abc123/app.bsky.feed.post/3k2xyz
 *
 * @param uri - AT Protocol URI
 * @returns Object with did, collection, and rkey
 * @throws Error if URI is invalid
 *
 * @example
 * parseAtUri('at://did:plc:abc123/app.bsky.feed.post/3k2xyz')
 * // { did: 'did:plc:abc123', collection: 'app.bsky.feed.post', rkey: '3k2xyz' }
 */
export function parseAtUri(uri: string): AtUriComponents {
  if (!uri || typeof uri !== 'string') {
    throw new Error('Invalid AT URI: must be a non-empty string');
  }

  // AT URI format: at://did/collection/rkey
  const atUriRegex = /^at:\/\/(did:[^/]+)\/([^/]+)\/([^/]+)$/;
  const match = uri.match(atUriRegex);

  if (!match) {
    throw new Error(`Invalid AT URI format: ${uri}`);
  }

  const [, did, collection, rkey] = match;

  return {
    did,
    collection,
    rkey
  };
}

/**
 * Normalize Bluesky handle
 * Adds .bsky.social suffix if not present and no other TLD exists
 *
 * @param handle - Bluesky handle (with or without .bsky.social)
 * @returns Normalized handle
 *
 * @example
 * normalizeHandle('alice') // 'alice.bsky.social'
 * normalizeHandle('alice.bsky.social') // 'alice.bsky.social'
 * normalizeHandle('alice.com') // 'alice.com'
 */
export function normalizeHandle(handle: string): string {
  if (!handle || typeof handle !== 'string') {
    throw new Error('Invalid handle: must be a non-empty string');
  }

  // Remove @ prefix if present
  const cleaned = handle.startsWith('@') ? handle.slice(1) : handle;

  // Remove whitespace
  const trimmed = cleaned.trim();

  if (trimmed.length === 0) {
    throw new Error('Invalid handle: cannot be empty');
  }

  // If already has a TLD, return as-is
  if (trimmed.includes('.')) {
    return trimmed;
  }

  // Add .bsky.social suffix
  return `${trimmed}.bsky.social`;
}

/**
 * Extract DID from AT URI
 *
 * @param uri - AT Protocol URI
 * @returns DID string
 *
 * @example
 * extractDid('at://did:plc:abc123/app.bsky.feed.post/3k2xyz') // 'did:plc:abc123'
 */
export function extractDid(uri: string): string {
  const { did } = parseAtUri(uri);
  return did;
}

/**
 * Build AT URI from components
 *
 * @param did - DID identifier
 * @param collection - Collection name
 * @param rkey - Record key
 * @returns Complete AT URI
 *
 * @example
 * buildAtUri('did:plc:abc123', 'app.bsky.feed.post', '3k2xyz')
 * // 'at://did:plc:abc123/app.bsky.feed.post/3k2xyz'
 */
export function buildAtUri(did: string, collection: string, rkey: string): string {
  if (!did || !collection || !rkey) {
    throw new Error('All components required: did, collection, rkey');
  }

  return `at://${did}/${collection}/${rkey}`;
}

/**
 * Parse ISO8601 duration to milliseconds
 * Supports simple formats like PT1H, PT30M, PT1H30M
 *
 * @param duration - ISO8601 duration string
 * @returns Duration in milliseconds
 *
 * @example
 * parseDuration('PT1H') // 3600000 (1 hour)
 * parseDuration('PT30M') // 1800000 (30 minutes)
 * parseDuration('PT1H30M') // 5400000 (1.5 hours)
 */
export function parseDuration(duration: string): number {
  if (!duration || typeof duration !== 'string') {
    throw new Error('Invalid duration: must be a non-empty string');
  }

  // Simple ISO8601 duration parser
  const regex = /^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$/;
  const match = duration.match(regex);

  if (!match) {
    throw new Error(`Invalid ISO8601 duration: ${duration}`);
  }

  const [, hours, minutes, seconds] = match;

  const hoursMs = hours ? parseInt(hours, 10) * 3600000 : 0;
  const minutesMs = minutes ? parseInt(minutes, 10) * 60000 : 0;
  const secondsMs = seconds ? parseInt(seconds, 10) * 1000 : 0;

  return hoursMs + minutesMs + secondsMs;
}

/**
 * Format milliseconds to human-readable duration
 *
 * @param ms - Milliseconds
 * @returns Human-readable string (e.g., "1h 30m")
 *
 * @example
 * formatDuration(3600000) // '1h'
 * formatDuration(5400000) // '1h 30m'
 * formatDuration(90000) // '1m 30s'
 */
export function formatDuration(ms: number): string {
  if (typeof ms !== 'number' || ms < 0) {
    throw new Error('Invalid duration: must be a non-negative number');
  }

  const hours = Math.floor(ms / 3600000);
  const minutes = Math.floor((ms % 3600000) / 60000);
  const seconds = Math.floor((ms % 60000) / 1000);

  const parts: string[] = [];

  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0) parts.push(`${minutes}m`);
  if (seconds > 0 && hours === 0) parts.push(`${seconds}s`);

  return parts.length > 0 ? parts.join(' ') : '0s';
}
