/**
 * SkymarshalCore - Main facade and orchestrator for Skymarshal
 *
 * Coordinates all 6 managers and provides a unified entry point for
 * Bluesky content management operations.
 *
 * Manager hierarchy:
 * 1. IndexedDBProvider - Database layer
 * 2. SearchManager - Multi-field filtering (no dependencies)
 * 3. SettingsManager - User preferences (needs db)
 * 4. AuthManager - Authentication wrapper (needs apiClient.auth)
 * 5. EngagementManager - Metrics caching (needs db, optional apiClient)
 * 6. DataManager - Import/export/backups (needs db)
 * 7. DeletionManager - Safe deletion (needs db, apiClient, then setDataManager)
 *
 * @module SkymarshalCore
 */

import { IndexedDBProvider } from './database/IndexedDBProvider';
import { SearchManager } from './managers/SearchManager';
import { SettingsManager } from './managers/SettingsManager';
import { AuthManager } from './managers/AuthManager';
import { EngagementManager } from './managers/EngagementManager';
import { DataManager } from './managers/DataManager';
import { DeletionManager } from './managers/DeletionManager';
import type { IIndexedDBProvider } from './types';

/**
 * Custom error for initialization failures
 */
export class InitializationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'InitializationError';
  }
}

/**
 * Custom error for shutdown failures
 */
export class ShutdownError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ShutdownError';
  }
}

/**
 * SkymarshalCore - Main orchestrator class
 *
 * This class coordinates all Skymarshal managers and provides a single
 * entry point for initialization and shutdown.
 *
 * @example
 * ```typescript
 * import { BlueSkyClient } from '@bluesky/api-client';
 * import { SkymarshalCore } from '@bluesky/skymarshal';
 *
 * // Initialize
 * const client = new BlueSkyClient();
 * const skymarshal = new SkymarshalCore(client);
 * await skymarshal.init();
 *
 * // Use managers
 * const results = await skymarshal.search.search(items, filters);
 *
 * // Clean up
 * await skymarshal.shutdown();
 * ```
 */
export class SkymarshalCore {
  // Database provider
  private db: IndexedDBProvider;

  // Manager instances (public for direct access)
  public search: SearchManager;
  public settings: SettingsManager;
  public auth: AuthManager;
  public engagement: EngagementManager;
  public data: DataManager;
  public deletion: DeletionManager;

  // Initialization state
  private initialized: boolean = false;
  private initPromise: Promise<void> | null = null;

  /**
   * Create a new SkymarshalCore instance
   *
   * @param apiClient - BlueskyAPIClient instance from @bluesky/api-client
   *
   * @example
   * ```typescript
   * import { BlueSkyClient } from '@bluesky/api-client';
   * import { SkymarshalCore } from '@bluesky/skymarshal';
   *
   * const client = new BlueSkyClient();
   * const core = new SkymarshalCore(client);
   * ```
   */
  constructor(private apiClient: any) {
    if (!apiClient) {
      throw new InitializationError('apiClient is required');
    }

    // 1. Create IndexedDB provider (not yet initialized)
    this.db = new IndexedDBProvider();

    // 2. Instantiate managers (dependencies injected in order)
    // SearchManager has no dependencies
    this.search = new SearchManager();

    // SettingsManager needs db reference
    this.settings = new SettingsManager(this.db);

    // AuthManager wraps apiClient's auth manager
    if (!apiClient.auth) {
      throw new InitializationError('apiClient.auth is required');
    }
    this.auth = new AuthManager(apiClient.auth);

    // EngagementManager needs db + optional apiClient
    this.engagement = new EngagementManager(this.db, apiClient);

    // DataManager needs db reference
    this.data = new DataManager(this.db);

    // DeletionManager needs db + apiClient
    this.deletion = new DeletionManager(this.db, apiClient);
  }

  /**
   * Initialize the Skymarshal core
   *
   * This method:
   * 1. Opens the IndexedDB database
   * 2. Runs any pending migrations
   * 3. Sets up cross-manager dependencies
   * 4. Prepares the system for use
   *
   * Safe to call multiple times - subsequent calls return the same promise.
   *
   * @returns Promise that resolves when initialization is complete
   * @throws InitializationError if database fails to open or quota is exceeded
   *
   * @example
   * ```typescript
   * try {
   *   await skymarshal.init();
   *   console.log('Skymarshal initialized');
   * } catch (error) {
   *   if (error instanceof InitializationError) {
   *     console.error('Failed to initialize:', error.message);
   *   }
   * }
   * ```
   */
  async init(): Promise<void> {
    // If already initialized, return immediately
    if (this.initialized) {
      return Promise.resolve();
    }

    // If initialization is in progress, return the same promise
    if (this.initPromise) {
      return this.initPromise;
    }

    // Start initialization
    this.initPromise = this._initialize();
    return this.initPromise;
  }

  /**
   * Internal initialization logic
   * @private
   */
  private async _initialize(): Promise<void> {
    try {
      // Step 1: Initialize IndexedDB
      await this.db.init();

      // Step 2: Set cross-manager dependencies
      // DeletionManager needs DataManager reference for backup creation
      this.deletion.setDataManager(this.data);

      // Mark as initialized
      this.initialized = true;

      console.log('SkymarshalCore initialized successfully');
    } catch (error: any) {
      // Reset state on failure
      this.initialized = false;
      this.initPromise = null;

      // Normalize error
      if (error.name === 'QuotaExceededError') {
        throw new InitializationError(
          'Storage quota exceeded. Please free up space or clear old data.'
        );
      } else if (error.message?.includes('IndexedDB is not available')) {
        throw new InitializationError(
          'IndexedDB is not supported in this browser'
        );
      } else {
        throw new InitializationError(
          `Failed to initialize database: ${error.message}`
        );
      }
    }
  }

  /**
   * Gracefully shutdown Skymarshal
   *
   * This method:
   * 1. Closes the IndexedDB connection
   * 2. Clears any pending timers/intervals
   * 3. Releases resources
   *
   * After shutdown, the instance cannot be reused. Create a new instance
   * if you need to reinitialize.
   *
   * @throws ShutdownError if shutdown fails
   *
   * @example
   * ```typescript
   * // When done with the instance
   * await skymarshal.shutdown();
   * console.log('Skymarshal shut down');
   * ```
   */
  async shutdown(): Promise<void> {
    if (!this.initialized) {
      return; // Already shut down or never initialized
    }

    try {
      // Close IndexedDB connection
      await this.db.close();

      // Clear manager state
      this.search.clearCache();
      this.engagement.resetStats();

      // Mark as shut down
      this.initialized = false;
      this.initPromise = null;

      console.log('SkymarshalCore shut down successfully');
    } catch (error: any) {
      throw new ShutdownError(
        `Failed to shutdown: ${error.message}`
      );
    }
  }

  /**
   * Check if Skymarshal is initialized
   *
   * @returns True if initialized and ready to use
   *
   * @example
   * ```typescript
   * if (!skymarshal.isInitialized()) {
   *   await skymarshal.init();
   * }
   * ```
   */
  isInitialized(): boolean {
    return this.initialized;
  }

  /**
   * Get the underlying IndexedDB provider
   *
   * Advanced use only - most operations should use managers directly.
   *
   * @returns IndexedDB provider instance
   *
   * @example
   * ```typescript
   * const db = skymarshal.getDatabase();
   * const items = await db.getAll('contentItems');
   * ```
   */
  getDatabase(): IIndexedDBProvider {
    return this.db;
  }

  /**
   * Get the API client instance
   *
   * @returns BlueskyAPIClient instance
   *
   * @example
   * ```typescript
   * const client = skymarshal.getApiClient();
   * // Use client directly for custom API calls
   * ```
   */
  getApiClient(): any {
    return this.apiClient;
  }

  /**
   * Get initialization status and health check
   *
   * @returns Status object with manager health
   *
   * @example
   * ```typescript
   * const status = await skymarshal.getStatus();
   * console.log('Database:', status.database.connected);
   * console.log('Auth:', status.auth.authenticated);
   * ```
   */
  async getStatus(): Promise<{
    initialized: boolean;
    database: {
      connected: boolean;
      version: number;
    };
    auth: {
      authenticated: boolean;
      handle: string | null;
    };
    engagement: {
      cacheHitRate: number;
    };
  }> {
    return {
      initialized: this.initialized,
      database: {
        connected: this.db !== null,
        version: this.db ? (this.db as any).schema?.version ?? 0 : 0
      },
      auth: {
        authenticated: this.auth.isAuthenticated(),
        handle: this.auth.getCurrentHandle()
      },
      engagement: {
        cacheHitRate: this.engagement.getStats().hitRate
      }
    };
  }
}
