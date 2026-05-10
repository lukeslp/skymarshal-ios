/**
 * @bluesky/skymarshal - Bluesky content management library
 *
 * A TypeScript library for managing, searching, and analyzing Bluesky content.
 * Port of the Python skymarshal toolkit to browser-compatible TypeScript.
 *
 * @module @bluesky/skymarshal
 */

// ============================================================================
// Type Exports
// ============================================================================

export type {
  // Core data models
  ContentItem,
  ContentItemWithMetadata,

  // Search & filtering
  SearchFilters,
  SearchOptions,

  // Settings & configuration
  UserSettings,

  // Engagement & metrics
  EngagementMetrics,

  // Data management
  SearchHistoryEntry,
  BackupSnapshot,
  DataFile,

  // Manager interfaces
  IAuthManager,
  ISearchManager,
  IDataManager,
  IEngagementManager,
  ISettingsManager,
  IDeletionManager,

  // Deletion types (from types.ts - for old interface)
  DeletionPreview,

  // Configuration
  SkymarshalConfig,

  // Database interfaces
  IIndexedDBProvider,
  DBSchema,
  DBStoreSchema
} from './types';

// ============================================================================
// Enum Exports
// ============================================================================

export {
  // Core enums
  ContentType,
  DeleteMode,
  CacheStrategy,
  SkymarshalError,
  SortDirection,
  ExportFormat,
  MetricSource,

  // Constants
  DB_STORES,
  DEFAULT_SETTINGS,
  CACHE_TTL,
  RATE_LIMITS,

  // Type guards
  isContentType,
  isDeleteMode,
  isCacheStrategy,
  isSkymarshalError
} from './models/enums';

// ============================================================================
// Manager Exports
// ============================================================================

export { AuthManager, AuthError, ValidationError } from './managers/AuthManager';
export { SearchManager } from './managers/SearchManager';
export { DataManager, ParseError, ValidationError as DataValidationError } from './managers/DataManager';
export type { BackupMetadata } from './managers/DataManager';
export { EngagementManager } from './managers/EngagementManager';
export { SettingsManager, updateSettings, resetSettings } from './managers/SettingsManager';
export { DeletionManager, NetworkError, DBError } from './managers/DeletionManager';
export type { DeletionOptions, DeletionResult } from './managers/DeletionManager';

// ============================================================================
// Database Exports
// ============================================================================

export { IndexedDBProvider, getDefaultProvider } from './database/IndexedDBProvider';
export { SCHEMA, STORE_NAMES } from './database/schema';
export { migrations, runMigrations, getLatestVersion, hasMigration, getMigration, validateMigrations } from './database/migrations';
export type { QueryRange, IndexedDBProviderConfig, OperationResult } from './database/IndexedDBProvider';
export type { StoreIndex, ObjectStoreDefinition, DatabaseSchema, StoreName } from './database/schema';
export type { DBMigration } from './database/migrations';

// ============================================================================
// Core Orchestrator
// ============================================================================

export { SkymarshalCore, InitializationError, ShutdownError } from './SkymarshalCore';

// ============================================================================
// User-Facing API Wrappers
// ============================================================================

export {
  // Content management
  searchContent,
  hydrateEngagement,
  getEngagement,

  // Data export
  exportToJSON,
  exportToCSV,

  // Data import
  importFromJSON,

  // Backup operations
  createBackup,
  listBackups,
  restoreBackup,
  deleteBackup,

  // Deletion operations
  safeDeleteContent,
  batchDeleteLocal,
  batchDeleteRemote,

  // Settings
  getUserSettings,
  updateUserSettings,
  resetUserSettings,

  // Authentication
  login,
  logout,
  isAuthenticated,
  getCurrentHandle,
  getCurrentDid,

  // Batch operations
  batchHydrateEngagement,

  // Statistics
  getEngagementStats,
  clearEngagementCache
} from './api';

// ============================================================================
// Future Utility Exports (to be implemented)
// ============================================================================

// export * as parsing from './utils/parsing';
// export * as validation from './utils/validation';
// export * as batching from './utils/batching';
// export * as cacheUtils from './utils/cache-utils';

// ============================================================================
// Version
// ============================================================================

export const VERSION = '1.0.0';

/**
 * Package metadata
 */
export const PKG_INFO = {
  name: '@bluesky/skymarshal',
  version: VERSION,
  description: 'Bluesky content management library',
  author: 'Luke Steuber'
} as const;
