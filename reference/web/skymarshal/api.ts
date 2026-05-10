/**
 * User-facing API wrappers for Skymarshal
 *
 * This module provides convenient wrapper functions that simplify common
 * operations by coordinating multiple managers. All functions require a
 * SkymarshalCore instance as the first parameter.
 *
 * @module api
 */

import type { SkymarshalCore } from './SkymarshalCore';
import type {
  ContentItem,
  SearchFilters,
  SearchOptions,
  UserSettings,
  EngagementMetrics
} from './types';
import type {
  DeletionOptions,
  DeletionResult
} from './managers/DeletionManager';

// ============================================================================
// Content Management
// ============================================================================

/**
 * Search content with filters and options
 *
 * Combines database retrieval with filtering and sorting.
 *
 * @param core - SkymarshalCore instance
 * @param filters - Partial filter criteria
 * @param options - Optional search options (sorting, pagination)
 * @returns Array of matching content items
 *
 * @example
 * ```typescript
 * import { SkymarshalCore } from '@bluesky/skymarshal';
 * import { searchContent } from '@bluesky/skymarshal/api';
 *
 * const results = await searchContent(skymarshal, {
 *   contentType: 'posts',
 *   keywords: ['typescript'],
 *   minEngagement: 10
 * }, {
 *   sortBy: 'engagement',
 *   limit: 50
 * });
 *
 * console.log(`Found ${results.length} posts`);
 * ```
 */
export async function searchContent(
  core: SkymarshalCore,
  filters: Partial<SearchFilters>,
  options?: SearchOptions
): Promise<ContentItem[]> {
  // Step 1: Get all content items from database
  const items = await core.getDatabase().getAll<ContentItem>('contentItems');

  // Step 2: Build complete filters with defaults
  const builtFilters = core.search.buildFilters(filters);

  // Step 3: Search and filter
  return core.search.search(items, builtFilters, options);
}

/**
 * Hydrate content items with fresh engagement data
 *
 * Updates engagement metrics (likes, reposts, replies) from the API.
 * Uses caching to minimize API calls.
 *
 * @param core - SkymarshalCore instance
 * @param items - Content items to hydrate
 *
 * @example
 * ```typescript
 * const items = await searchContent(core, { contentType: 'posts' });
 *
 * // Refresh engagement data
 * await hydrateEngagement(core, items);
 *
 * console.log('Engagement data refreshed');
 * ```
 */
export async function hydrateEngagement(
  core: SkymarshalCore,
  items: ContentItem[]
): Promise<void> {
  await core.engagement.hydrateItems(items);
}

/**
 * Get engagement metrics for a single content item
 *
 * Returns cached metrics if available and fresh, otherwise fetches from API.
 *
 * @param core - SkymarshalCore instance
 * @param uri - AT-URI of the content item
 * @returns Engagement metrics or null if not found
 *
 * @example
 * ```typescript
 * const metrics = await getEngagement(core, 'at://did:plc:xyz/app.bsky.feed.post/abc123');
 *
 * if (metrics) {
 *   console.log(`Likes: ${metrics.likeCount}`);
 *   console.log(`Reposts: ${metrics.repostCount}`);
 * }
 * ```
 */
export async function getEngagement(
  core: SkymarshalCore,
  uri: string
): Promise<EngagementMetrics | null> {
  return core.engagement.getEngagement(uri);
}

// ============================================================================
// Data Export Operations
// ============================================================================

/**
 * Export content to JSON format
 *
 * Optionally filter content before export.
 *
 * @param core - SkymarshalCore instance
 * @param filters - Optional filters to apply before export
 * @returns JSON string of exported content
 *
 * @example
 * ```typescript
 * // Export all posts
 * const json = await exportToJSON(core, { contentType: 'posts' });
 *
 * // Download as file
 * const blob = new Blob([json], { type: 'application/json' });
 * const url = URL.createObjectURL(blob);
 * // ... trigger download
 * ```
 */
export async function exportToJSON(
  core: SkymarshalCore,
  filters?: Partial<SearchFilters>
): Promise<string> {
  const items = await searchContent(core, filters || {});
  return core.data.exportData(items, 'json');
}

/**
 * Export content to CSV format
 *
 * Converts content items to CSV for spreadsheet compatibility.
 *
 * @param core - SkymarshalCore instance
 * @param filters - Optional filters to apply before export
 * @returns CSV string of exported content
 *
 * @example
 * ```typescript
 * // Export high-engagement posts
 * const csv = await exportToCSV(core, {
 *   contentType: 'posts',
 *   minEngagement: 50
 * });
 *
 * // Download as CSV file
 * const blob = new Blob([csv], { type: 'text/csv' });
 * ```
 */
export async function exportToCSV(
  core: SkymarshalCore,
  filters?: Partial<SearchFilters>
): Promise<string> {
  const items = await searchContent(core, filters || {});
  return core.data.exportData(items, 'csv');
}

// ============================================================================
// Data Import Operations
// ============================================================================

/**
 * Import content from JSON file
 *
 * Validates and stores imported content in the database.
 *
 * @param core - SkymarshalCore instance
 * @param jsonContent - JSON string containing content items
 * @returns Array of imported content items
 * @throws ParseError if JSON is invalid
 * @throws ValidationError if content items are malformed
 *
 * @example
 * ```typescript
 * // Read file from input
 * const file = event.target.files[0];
 * const text = await file.text();
 *
 * // Import content
 * const items = await importFromJSON(core, text);
 * console.log(`Imported ${items.length} items`);
 * ```
 */
export async function importFromJSON(
  core: SkymarshalCore,
  jsonContent: string
): Promise<ContentItem[]> {
  // Parse and validate JSON
  const items = await core.data.importData(jsonContent);

  // Store in IndexedDB
  await core.getDatabase().putBatch('contentItems', items);

  return items;
}

// ============================================================================
// Backup Operations
// ============================================================================

/**
 * Create a backup of content items
 *
 * Stores a named backup in IndexedDB for later restoration.
 *
 * @param core - SkymarshalCore instance
 * @param name - Human-readable backup name
 * @param filters - Optional filters to select what to backup
 * @returns Backup ID (UUID)
 *
 * @example
 * ```typescript
 * // Backup all posts from 2024
 * const backupId = await createBackup(core, 'Posts 2024', {
 *   contentType: 'posts',
 *   startDate: '2024-01-01',
 *   endDate: '2024-12-31'
 * });
 *
 * console.log(`Backup created: ${backupId}`);
 * ```
 */
export async function createBackup(
  core: SkymarshalCore,
  name: string,
  filters?: Partial<SearchFilters>
): Promise<string> {
  const items = await searchContent(core, filters || {});
  return core.data.createBackup(items, name);
}

/**
 * List all available backups
 *
 * @param core - SkymarshalCore instance
 * @returns Array of backup metadata
 *
 * @example
 * ```typescript
 * const backups = await listBackups(core);
 *
 * for (const backup of backups) {
 *   console.log(`${backup.name} - ${backup.itemCount} items (${backup.createdAt})`);
 * }
 * ```
 */
export async function listBackups(
  core: SkymarshalCore
): Promise<Array<{
  id: string;
  name: string;
  handle: string;
  createdAt: string;
  itemCount: number;
  sizeBytes: number;
}>> {
  return core.data.listBackups();
}

/**
 * Restore content from a backup
 *
 * @param core - SkymarshalCore instance
 * @param backupId - Backup ID (from createBackup or listBackups)
 * @returns Array of restored content items
 *
 * @example
 * ```typescript
 * const items = await restoreBackup(core, backupId);
 * console.log(`Restored ${items.length} items`);
 * ```
 */
export async function restoreBackup(
  core: SkymarshalCore,
  backupId: string
): Promise<ContentItem[]> {
  return core.data.restoreBackup(backupId);
}

/**
 * Delete a backup
 *
 * @param core - SkymarshalCore instance
 * @param backupId - Backup ID to delete
 *
 * @example
 * ```typescript
 * await deleteBackup(core, backupId);
 * console.log('Backup deleted');
 * ```
 */
export async function deleteBackup(
  core: SkymarshalCore,
  backupId: string
): Promise<void> {
  return core.data.deleteBackup(backupId);
}

// ============================================================================
// Deletion Operations
// ============================================================================

/**
 * Safely delete a single content item
 *
 * Supports local-only or remote deletion with optional backup.
 *
 * @param core - SkymarshalCore instance
 * @param uri - AT-URI of content to delete
 * @param options - Deletion options
 * @returns Deletion result
 *
 * @example
 * ```typescript
 * // Delete from local database only
 * const result = await safeDeleteContent(core, uri, {
 *   deleteFromRemote: false,
 *   createBackup: true,
 *   backupName: 'Before deletion'
 * });
 *
 * if (result.success === 1) {
 *   console.log('Deleted successfully');
 * }
 * ```
 */
export async function safeDeleteContent(
  core: SkymarshalCore,
  uri: string,
  options: DeletionOptions
): Promise<DeletionResult> {
  return core.deletion.safeDelete(uri, options);
}

/**
 * Batch delete multiple content items (local only)
 *
 * Deletes items from IndexedDB with progress tracking.
 *
 * @param core - SkymarshalCore instance
 * @param uris - Array of AT-URIs to delete
 * @param onProgress - Optional callback for progress updates (0-100)
 * @returns Deletion result
 *
 * @example
 * ```typescript
 * const urisToDelete = ['at://...', 'at://...'];
 *
 * const result = await batchDeleteLocal(core, urisToDelete, (progress) => {
 *   console.log(`Deletion ${progress}% complete`);
 * });
 *
 * console.log(`Deleted: ${result.success}, Failed: ${result.failed}`);
 * ```
 */
export async function batchDeleteLocal(
  core: SkymarshalCore,
  uris: string[],
  onProgress?: (progress: number) => void
): Promise<DeletionResult> {
  return core.deletion.batchDeleteLocal(uris, onProgress);
}

/**
 * Batch delete from remote Bluesky server
 *
 * Deletes posts, likes, reposts, etc. from the actual Bluesky account.
 * Requires authentication.
 *
 * Note: This is a planned feature. Currently, remote deletion must be
 * done individually using safeDeleteContent with deleteFromRemote: true.
 *
 * @param core - SkymarshalCore instance
 * @param uris - Array of AT-URIs to delete
 * @param onProgress - Optional callback for progress updates (0-100)
 * @returns Deletion result
 *
 * @example
 * ```typescript
 * // Delete old posts from account
 * const result = await batchDeleteRemote(core, oldPostUris, (progress) => {
 *   updateProgressBar(progress);
 * });
 *
 * if (result.failed > 0) {
 *   console.error('Some deletions failed:', result.errors);
 * }
 * ```
 */
export async function batchDeleteRemote(
  core: SkymarshalCore,
  uris: string[],
  onProgress?: (progress: number) => void
): Promise<DeletionResult> {
  // TODO: Implement batch remote deletion
  // For now, iterate and call safeDelete individually
  const result: DeletionResult = {
    success: 0,
    failed: 0,
    errors: []
  };

  for (let i = 0; i < uris.length; i++) {
    try {
      const deleteResult = await core.deletion.safeDelete(uris[i], {
        deleteFromRemote: true,
        confirmationRequired: false
      });

      result.success += deleteResult.success;
      result.failed += deleteResult.failed;
      result.errors.push(...deleteResult.errors);

      if (onProgress) {
        const progress = Math.round(((i + 1) / uris.length) * 100);
        onProgress(progress);
      }
    } catch (error: any) {
      result.failed++;
      result.errors.push({
        uri: uris[i],
        error: error.message
      });
    }
  }

  return result;
}

// ============================================================================
// Settings Operations
// ============================================================================

/**
 * Get user settings
 *
 * Returns saved settings for a handle, or defaults if not found.
 *
 * @param core - SkymarshalCore instance
 * @param handle - Bluesky handle
 * @returns User settings
 *
 * @example
 * ```typescript
 * const settings = await getUserSettings(core, 'alice.bsky.social');
 * console.log('Cache TTL:', settings.cacheTtlSeconds);
 * ```
 */
export async function getUserSettings(
  core: SkymarshalCore,
  handle: string
): Promise<UserSettings> {
  return core.settings.loadSettings(handle);
}

/**
 * Update user settings
 *
 * Merges provided settings with existing settings and saves.
 *
 * @param core - SkymarshalCore instance
 * @param handle - Bluesky handle
 * @param settings - Partial settings to update
 *
 * @example
 * ```typescript
 * await updateUserSettings(core, 'alice.bsky.social', {
 *   cacheTtlSeconds: 7200,
 *   engagementScoreWeights: {
 *     likes: 1,
 *     reposts: 3,
 *     replies: 5
 *   }
 * });
 * ```
 */
export async function updateUserSettings(
  core: SkymarshalCore,
  handle: string,
  settings: Partial<UserSettings>
): Promise<void> {
  // Load existing settings first
  const existing = await core.settings.loadSettings(handle);

  // Merge partial settings with existing
  const merged = {
    ...existing,
    ...settings
  } as UserSettings;

  return core.settings.saveSettings(handle, merged);
}

/**
 * Reset user settings to defaults
 *
 * @param core - SkymarshalCore instance
 * @param handle - Bluesky handle
 *
 * @example
 * ```typescript
 * await resetUserSettings(core, 'alice.bsky.social');
 * console.log('Settings reset to defaults');
 * ```
 */
export async function resetUserSettings(
  core: SkymarshalCore,
  handle: string
): Promise<void> {
  const defaults = core.settings.getDefaults();
  return core.settings.saveSettings(handle, defaults);
}

// ============================================================================
// Authentication Operations
// ============================================================================

/**
 * Login to Bluesky
 *
 * Authenticates with handle and password (or app password).
 *
 * @param core - SkymarshalCore instance
 * @param handle - Bluesky handle (with or without @, domain optional)
 * @param password - Account password or app password
 * @returns Session object
 * @throws ValidationError if handle format is invalid
 * @throws AuthError if credentials are invalid
 *
 * @example
 * ```typescript
 * try {
 *   const session = await login(core, 'alice', 'app-password-xyz');
 *   console.log('Logged in as:', session.handle);
 * } catch (error) {
 *   if (error instanceof ValidationError) {
 *     console.error('Invalid handle format');
 *   } else if (error instanceof AuthError) {
 *     console.error('Login failed:', error.message);
 *   }
 * }
 * ```
 */
export async function login(
  core: SkymarshalCore,
  handle: string,
  password: string
): Promise<any> {
  return core.auth.login(handle, password);
}

/**
 * Logout from Bluesky
 *
 * Clears the current session.
 *
 * @param core - SkymarshalCore instance
 *
 * @example
 * ```typescript
 * await logout(core);
 * console.log('Logged out');
 * ```
 */
export async function logout(core: SkymarshalCore): Promise<void> {
  return core.auth.logout();
}

/**
 * Check if user is authenticated
 *
 * @param core - SkymarshalCore instance
 * @returns True if there is an active session
 *
 * @example
 * ```typescript
 * if (!isAuthenticated(core)) {
 *   console.log('Please login first');
 * }
 * ```
 */
export function isAuthenticated(core: SkymarshalCore): boolean {
  return core.auth.isAuthenticated();
}

/**
 * Get current user's handle
 *
 * @param core - SkymarshalCore instance
 * @returns Handle or null if not authenticated
 *
 * @example
 * ```typescript
 * const handle = getCurrentHandle(core);
 * console.log('Current user:', handle || 'Not logged in');
 * ```
 */
export function getCurrentHandle(core: SkymarshalCore): string | null {
  return core.auth.getCurrentHandle();
}

/**
 * Get current user's DID
 *
 * @param core - SkymarshalCore instance
 * @returns DID or null if not authenticated
 *
 * @example
 * ```typescript
 * const did = getCurrentDid(core);
 * if (did) {
 *   console.log('User DID:', did);
 * }
 * ```
 */
export function getCurrentDid(core: SkymarshalCore): string | null {
  return core.auth.getCurrentDid();
}

// ============================================================================
// Batch Engagement Operations
// ============================================================================

/**
 * Batch update engagement metrics for multiple items
 *
 * Efficiently fetches and caches engagement data for multiple URIs.
 *
 * @param core - SkymarshalCore instance
 * @param uris - Array of AT-URIs to update
 * @returns Map of URI to engagement metrics
 *
 * @example
 * ```typescript
 * const uris = posts.map(p => p.uri);
 * const metrics = await batchHydrateEngagement(core, uris);
 *
 * for (const [uri, engagement] of metrics) {
 *   console.log(`${uri}: ${engagement.likeCount} likes`);
 * }
 * ```
 */
export async function batchHydrateEngagement(
  core: SkymarshalCore,
  uris: string[]
): Promise<Map<string, EngagementMetrics>> {
  return core.engagement.batchUpdateEngagement(uris);
}

// ============================================================================
// Statistics and Monitoring
// ============================================================================

/**
 * Get engagement cache statistics
 *
 * Returns cache hit rate and performance metrics.
 *
 * @param core - SkymarshalCore instance
 * @returns Cache statistics
 *
 * @example
 * ```typescript
 * const stats = getEngagementStats(core);
 * console.log(`Cache hit rate: ${(stats.hitRate * 100).toFixed(1)}%`);
 * console.log(`Total API calls: ${stats.apiCalls}`);
 * ```
 */
export function getEngagementStats(core: SkymarshalCore): {
  hitRate: number;
  hits: number;
  misses: number;
  apiCalls: number;
  errors: number;
} {
  return core.engagement.getStats();
}

/**
 * Clear all cached engagement data
 *
 * Forces fresh API calls on next hydration.
 *
 * @param core - SkymarshalCore instance
 *
 * @example
 * ```typescript
 * await clearEngagementCache(core);
 * console.log('Engagement cache cleared');
 * ```
 */
export async function clearEngagementCache(core: SkymarshalCore): Promise<void> {
  await core.getDatabase().clear('engagementCache');
  core.engagement.resetStats();
}
