/**
 * Core type definitions for @bluesky/skymarshal
 *
 * This module contains all TypeScript interfaces and types for the Skymarshal
 * content management system, ported from the Python implementation.
 */

import type { ContentType, DeleteMode, CacheStrategy } from './models/enums';

// ============================================================================
// Core Data Models
// ============================================================================

/**
 * Base content item representing any Bluesky content
 */
export interface ContentItem {
  /** AT Protocol URI */
  uri: string;
  /** Content identifier */
  cid: string;
  /** Type of content */
  contentType: 'post' | 'reply' | 'like' | 'repost';
  /** Post text content (if applicable) */
  text?: string;
  /** ISO8601 timestamp of creation */
  createdAt?: string;
  /** Calculated engagement score */
  engagementScore: number;
  /** Number of likes */
  likeCount?: number;
  /** Number of reposts */
  repostCount?: number;
  /** Number of replies */
  replyCount?: number;
  /** Full record data for edge cases */
  rawData?: Record<string, any>;
  /** When this item was cached (timestamp) */
  cachedAt?: number;
  /** When engagement metrics were cached (timestamp) */
  engagementCachedAt?: number;
}

/**
 * Content item with additional metadata
 */
export interface ContentItemWithMetadata extends ContentItem {
  /** Author's DID */
  authorDid: string;
  /** Author's handle */
  authorHandle: string;
  /** Search relevance score */
  relevanceScore?: number;
}

// ============================================================================
// Search & Filtering
// ============================================================================

/**
 * Filter criteria for content searches
 */
export interface SearchFilters {
  /** Type of content to search */
  contentType: ContentType;
  /** Keywords to search for in text */
  keywords?: string[];
  /** Minimum engagement score */
  minEngagement?: number;
  /** Maximum engagement score */
  maxEngagement?: number;
  /** Minimum like count */
  minLikes?: number;
  /** Maximum like count */
  maxLikes?: number;
  /** Minimum repost count */
  minReposts?: number;
  /** Maximum repost count */
  maxReposts?: number;
  /** Minimum reply count */
  minReplies?: number;
  /** Maximum reply count */
  maxReplies?: number;
  /** Start date (ISO8601 or YYYY-MM-DD) */
  startDate?: string;
  /** End date (ISO8601 or YYYY-MM-DD) */
  endDate?: string;
  /** Filter by author DID */
  authorDid?: string;
  /** Exclude specific URIs */
  excludedUris?: string[];
}

/**
 * Options for search operations
 */
export interface SearchOptions {
  /** Maximum number of results */
  limit?: number;
  /** Offset for pagination */
  offset?: number;
  /** Sort order */
  sortBy?: 'newest' | 'oldest' | 'engagement' | 'likes' | 'replies' | 'reposts';
  /** Include replies in results */
  includeReplies?: boolean;
}

// ============================================================================
// Settings & Configuration
// ============================================================================

/**
 * User preferences and settings
 */
export interface UserSettings {
  /** Use subject engagement for reposts instead of repost engagement */
  useSubjectEngagementForReposts: boolean;
  /** Default download limit */
  downloadLimitDefault: number;
  /** Weights for engagement score calculation */
  engagementScoreWeights: {
    likes: number;
    reposts: number;
    replies: number;
  };
  /** Cache TTL in seconds */
  cacheTtlSeconds: number;
  /** Batch size for API operations */
  batchSize: number;
  /** Local backup retention in days */
  localBackupRetentionDays: number;
}

// ============================================================================
// Engagement & Metrics
// ============================================================================

/**
 * Cached engagement metrics for a content item
 */
export interface EngagementMetrics {
  /** Content URI */
  uri: string;
  /** Number of likes */
  likeCount: number;
  /** Number of reposts */
  repostCount: number;
  /** Number of replies */
  replyCount: number;
  /** When these metrics were cached (milliseconds) */
  cachedAt: number;
  /** Timestamp when TTL expires */
  expiresAt: number;
  /** Source of the metrics */
  source: 'api' | 'hydrated';
}

// ============================================================================
// Data Management
// ============================================================================

/**
 * Search history entry for UX
 */
export interface SearchHistoryEntry {
  /** Unique identifier */
  id: string;
  /** User handle */
  handle: string;
  /** Search filters used */
  filters: SearchFilters;
  /** Number of results found */
  resultCount: number;
  /** Timestamp of search */
  timestamp: number;
}

/**
 * Backup snapshot of content
 */
export interface BackupSnapshot {
  /** Unique identifier */
  id: string;
  /** User handle */
  handle: string;
  /** Content items in backup */
  items: ContentItem[];
  /** When backup was created */
  createdAt: number;
  /** Number of items */
  itemCount: number;
  /** Total size in bytes */
  totalSize: number;
  /** Optional description */
  description?: string;
}

/**
 * Data file metadata
 */
export interface DataFile {
  /** File identifier */
  id: string;
  /** User handle */
  handle: string;
  /** File format */
  format: 'json' | 'csv' | 'car';
  /** File size in bytes */
  size: number;
  /** Creation timestamp */
  createdAt: number;
  /** Number of items */
  itemCount: number;
  /** File path or blob URL */
  path?: string;
}

// ============================================================================
// Manager Interfaces
// ============================================================================

/**
 * Search manager interface
 */
export interface ISearchManager {
  /**
   * Build search filters from partial criteria
   */
  buildFilters(criteria: Partial<SearchFilters>): SearchFilters;

  /**
   * Search content items with filters
   */
  search(
    items: ContentItem[],
    filters: SearchFilters,
    options?: SearchOptions
  ): Promise<ContentItem[]>;

  /**
   * Sort results by specified criteria
   */
  sortResults(
    items: ContentItem[],
    sortBy: string
  ): ContentItem[];

  /**
   * Apply filter to single item
   */
  applyFilter(
    item: ContentItem,
    filters: SearchFilters
  ): boolean;

  /**
   * Calculate engagement score
   */
  calculateEngagement(
    likes: number,
    reposts: number,
    replies: number,
    weights?: Record<string, number>
  ): number;
}

/**
 * Data manager interface
 */
export interface IDataManager {
  /**
   * Download CAR file for a handle
   */
  downloadCAR(handle: string): Promise<Uint8Array>;

  /**
   * Import CAR file data
   */
  importCAR(carData: Uint8Array, handle: string): Promise<ContentItem[]>;

  /**
   * Restore from CAR file
   */
  restoreCAR(carPath: string): Promise<ContentItem[]>;

  /**
   * Export data to format
   */
  exportData(
    items: ContentItem[],
    format: 'json' | 'csv'
  ): Promise<string>;

  /**
   * Load exported data from file content
   */
  loadExportedData(fileContent: string): ContentItem[];

  /**
   * Hydrate items with fresh engagement data
   */
  hydrateItems(items: ContentItem[]): Promise<void>;

  /**
   * Get local data files for handle
   */
  getLocalDataFiles(handle: string): Promise<DataFile[]>;

  /**
   * Delete all local data for handle
   */
  deleteLocalData(handle: string): Promise<void>;
}

/**
 * Engagement manager interface
 */
export interface IEngagementManager {
  /**
   * Cache engagement metrics for a URI
   */
  cacheEngagement(uri: string, metrics: EngagementMetrics): Promise<void>;

  /**
   * Get cached engagement metrics
   */
  getEngagement(uri: string): Promise<EngagementMetrics | null>;

  /**
   * Batch update engagement for multiple URIs
   */
  batchUpdateEngagement(uris: string[]): Promise<Map<string, EngagementMetrics>>;

  /**
   * Calculate TTL for content based on age
   */
  calculateTTL(createdAt: string): number;

  /**
   * Check if cached data is stale
   */
  isStale(cachedAt: number, ttl: number): boolean;
}

/**
 * Authentication manager interface
 */
export interface IAuthManager {
  /**
   * Login with handle and password
   */
  login(handle: string, password: string): Promise<any>; // Session type from api-client

  /**
   * Logout and clear session
   */
  logout(): Promise<void>;

  /**
   * Refresh the current session
   */
  refreshSession(): Promise<any>; // Session type from api-client

  /**
   * Get the current session
   */
  getCurrentSession(): any | null; // Session type from api-client

  /**
   * Check if user is authenticated
   */
  isAuthenticated(): boolean;

  /**
   * Get the current user's handle
   */
  getCurrentHandle(): string | null;
}

/**
 * Settings manager interface
 */
export interface ISettingsManager {
  /**
   * Load user settings
   */
  loadSettings(handle: string): Promise<UserSettings>;

  /**
   * Save user settings
   */
  saveSettings(handle: string, settings: UserSettings): Promise<void>;

  /**
   * Get default settings
   */
  getDefaults(): UserSettings;

  /**
   * Apply defaults to partial settings
   */
  applyDefaults(partial: Partial<UserSettings>): UserSettings;
}

/**
 * Deletion manager interface
 */
export interface IDeletionManager {
  /**
   * Delete content with specified mode
   */
  deleteContent(
    items: ContentItem[],
    mode: DeleteMode
  ): Promise<DeletionResult>;

  /**
   * Preview deletion without executing
   */
  previewDeletion(items: ContentItem[]): DeletionPreview;

  /**
   * Confirm deletion operation
   */
  confirmDeletion(preview: DeletionPreview): Promise<boolean>;
}

/**
 * Deletion operation result
 */
export interface DeletionResult {
  /** Number of items successfully deleted */
  deleted: number;
  /** Number of items that failed */
  failed: number;
  /** Items that failed to delete */
  errors: Array<{
    item: ContentItem;
    error: string;
  }>;
  /** Whether operation was dry run */
  dryRun: boolean;
}

/**
 * Deletion preview
 */
export interface DeletionPreview {
  /** Items to be deleted */
  items: ContentItem[];
  /** Total count */
  count: number;
  /** Breakdown by type */
  breakdown: {
    posts: number;
    replies: number;
    likes: number;
    reposts: number;
  };
  /** Estimated time */
  estimatedTime: number;
}

// ============================================================================
// Core Configuration
// ============================================================================

/**
 * Configuration for Skymarshal core
 */
export interface SkymarshalConfig {
  /** API client instance */
  apiClient: any; // TODO: Type from @bluesky/api-client
  /** User session */
  session: any; // TODO: Type from @bluesky/api-client
  /** Database provider */
  dbProvider: IIndexedDBProvider;
  /** Cache strategy */
  cacheStrategy: CacheStrategy;
  /** Batch size for operations */
  batchSize?: number;
  /** Cache TTL in seconds */
  cacheTtl?: number;
}

// ============================================================================
// Database Interfaces
// ============================================================================

/**
 * IndexedDB provider interface
 */
export interface IIndexedDBProvider {
  /**
   * Initialize database
   */
  init(): Promise<void>;

  /**
   * Get database instance
   */
  getDB(): IDBDatabase;

  /**
   * Get item by key from store
   */
  get<T>(storeName: string, key: IDBValidKey): Promise<T | null>;

  /**
   * Put item in store
   */
  put<T>(storeName: string, value: T): Promise<IDBValidKey>;

  /**
   * Batch put items in store
   */
  putBatch<T>(storeName: string, items: T[]): Promise<IDBValidKey[]>;

  /**
   * Delete item from store
   */
  delete(storeName: string, key: IDBValidKey): Promise<void>;

  /**
   * Query store by index
   */
  query<T>(
    storeName: string,
    indexName: string,
    query?: IDBValidKey | IDBKeyRange | { lower?: any; upper?: any; lowerOpen?: boolean; upperOpen?: boolean }
  ): Promise<T[]>;

  /**
   * Get all items from store
   */
  getAll<T>(storeName: string): Promise<T[]>;

  /**
   * Clear all items from store
   */
  clear(storeName: string): Promise<void>;

  /**
   * Count items in store
   */
  count(storeName: string): Promise<number>;
}

/**
 * Database schema definition
 */
export interface DBSchema {
  version: number;
  stores: Record<string, DBStoreSchema>;
}

/**
 * Store schema definition
 */
export interface DBStoreSchema {
  keyPath: string | string[];
  autoIncrement?: boolean;
  indexes?: Record<string, string | string[]>;
}

// DBMigration is exported from database/migrations.ts
