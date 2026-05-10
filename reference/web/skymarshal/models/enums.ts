/**
 * Enums and constants for @bluesky/skymarshal
 *
 * This module defines all enumeration types used throughout the Skymarshal
 * content management system.
 */

/**
 * Content type filter options
 *
 * Used to filter content by type when searching or displaying items.
 */
export enum ContentType {
  /** All content types */
  ALL = 'all',
  /** Posts only (excluding replies) */
  POSTS = 'posts',
  /** Replies only */
  REPLIES = 'replies',
  /** Liked content */
  LIKES = 'likes',
  /** Reposted content */
  REPOSTS = 'reposts'
}

/**
 * Deletion mode options
 *
 * Controls how content deletion operations are executed.
 */
export enum DeleteMode {
  /** Delete items one at a time with confirmation for each */
  INDIVIDUAL = 'individual',
  /** Delete in batches with confirmation per batch */
  BATCH = 'batch',
  /** Delete all items with final confirmation */
  ALL = 'all',
  /** Preview deletion without executing */
  DRY_RUN = 'dry_run'
}

/**
 * Cache strategy options
 *
 * Determines how aggressively engagement metrics are cached.
 */
export enum CacheStrategy {
  /** Cache everything with 7 day TTL */
  AGGRESSIVE = 'aggressive',
  /** Cache posts with smart TTL based on age (default) */
  MODERATE = 'moderate',
  /** No caching - always fetch fresh */
  MINIMAL = 'minimal'
}

/**
 * Error codes for Skymarshal operations
 *
 * Used to categorize errors for better error handling and recovery.
 */
export enum SkymarshalError {
  /** Authentication required but not provided */
  AUTH_REQUIRED = 'AUTH_REQUIRED',
  /** Authentication session has expired */
  AUTH_EXPIRED = 'AUTH_EXPIRED',
  /** Invalid handle format */
  INVALID_HANDLE = 'INVALID_HANDLE',
  /** API rate limit exceeded */
  API_RATE_LIMIT = 'API_RATE_LIMIT',
  /** Network error during API call */
  NETWORK_ERROR = 'NETWORK_ERROR',
  /** IndexedDB quota exceeded */
  DB_QUOTA_EXCEEDED = 'DB_QUOTA_EXCEEDED',
  /** Failed to parse CAR file */
  CAR_PARSE_ERROR = 'CAR_PARSE_ERROR',
  /** Deletion operation failed */
  DELETION_FAILED = 'DELETION_FAILED',
  /** Invalid search filter */
  INVALID_FILTER = 'INVALID_FILTER',
  /** Database operation failed */
  DB_ERROR = 'DB_ERROR'
}

/**
 * Sort direction options
 */
export enum SortDirection {
  /** Ascending order */
  ASC = 'asc',
  /** Descending order */
  DESC = 'desc'
}

/**
 * Data export formats
 */
export enum ExportFormat {
  /** JSON format */
  JSON = 'json',
  /** CSV format */
  CSV = 'csv',
  /** CAR (Content Addressable aRchive) format */
  CAR = 'car'
}

/**
 * Engagement metric source
 */
export enum MetricSource {
  /** Fetched from API */
  API = 'api',
  /** Hydrated from batch operation */
  HYDRATED = 'hydrated',
  /** Cached from previous fetch */
  CACHED = 'cached'
}

/**
 * Database store names
 *
 * Constants for IndexedDB store names to ensure consistency.
 */
export const DB_STORES = {
  CONTENT_ITEMS: 'contentItems',
  ENGAGEMENT_CACHE: 'engagementCache',
  USER_SETTINGS: 'userSettings',
  SEARCH_HISTORY: 'searchHistory',
  BACKUPS: 'backups',
  CAR_FILES: 'carFiles'
} as const;

/**
 * Default values for user settings
 */
export const DEFAULT_SETTINGS = {
  useSubjectEngagementForReposts: true,
  downloadLimitDefault: 1000,
  engagementScoreWeights: {
    likes: 1,
    reposts: 2,
    replies: 3
  },
  cacheTtlSeconds: 86400, // 24 hours
  batchSize: 100,
  localBackupRetentionDays: 30
} as const;

/**
 * Cache TTL constants (in seconds)
 */
export const CACHE_TTL = {
  /** New posts (< 24 hours old): 1 hour */
  NEW_POST: 3600,
  /** Recent posts (< 7 days old): 6 hours */
  RECENT_POST: 21600,
  /** Old posts (> 7 days old): 7 days */
  OLD_POST: 604800,
  /** User profiles: 24 hours */
  PROFILE: 86400,
  /** Search results: 1 hour */
  SEARCH: 3600
} as const;

/**
 * API rate limits
 */
export const RATE_LIMITS = {
  /** Maximum requests per second */
  REQUESTS_PER_SECOND: 10,
  /** Batch size for profile fetches */
  BATCH_SIZE_PROFILES: 25,
  /** Batch size for post fetches */
  BATCH_SIZE_POSTS: 100,
  /** Maximum retry attempts */
  MAX_RETRIES: 3,
  /** Initial retry delay (ms) */
  RETRY_DELAY_MS: 1000,
  /** Exponential backoff multiplier */
  BACKOFF_MULTIPLIER: 2
} as const;

// QUOTA_THRESHOLDS moved to database/schema.ts

/**
 * Type guard to check if value is a valid ContentType
 */
export function isContentType(value: unknown): value is ContentType {
  return Object.values(ContentType).includes(value as ContentType);
}

/**
 * Type guard to check if value is a valid DeleteMode
 */
export function isDeleteMode(value: unknown): value is DeleteMode {
  return Object.values(DeleteMode).includes(value as DeleteMode);
}

/**
 * Type guard to check if value is a valid CacheStrategy
 */
export function isCacheStrategy(value: unknown): value is CacheStrategy {
  return Object.values(CacheStrategy).includes(value as CacheStrategy);
}

/**
 * Type guard to check if value is a valid SkymarshalError
 */
export function isSkymarshalError(value: unknown): value is SkymarshalError {
  return Object.values(SkymarshalError).includes(value as SkymarshalError);
}
