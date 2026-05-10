/**
 * Utility functions for @bluesky/skymarshal
 * @module utils
 */

// Re-export all parsing utilities
export {
  parseDate,
  formatDate,
  parseAtUri,
  normalizeHandle,
  extractDid,
  buildAtUri,
  parseDuration,
  formatDuration,
  type AtUriComponents
} from './parsing';

// Re-export all validation utilities
export {
  isValidAtUri,
  isValidHandle,
  isValidDid,
  validateSearchFilters,
  sanitizeInput,
  isValidEngagementScore,
  isValidTimestamp,
  isValidUrl,
  isValidContentType,
  validateKeywords,
  clampNumber,
  validatePagination,
  type SearchFilters
} from './validation';

// Re-export all batching utilities
export {
  batch,
  batchProcess,
  rateLimitedFetch,
  deduplicate,
  chunk,
  sleep,
  retry,
  parallelMap,
  AsyncQueue,
  type BatchOptions
} from './batching';

// Re-export all cache utilities
export {
  calculateTTL,
  isStale,
  getCacheKey,
  shouldRefresh,
  calculateExpiration,
  isExpired,
  createCacheItem,
  getRemainingTTL,
  TTLCache,
  memoize,
  type CacheItem,
  type CacheStats
} from './cache-utils';
