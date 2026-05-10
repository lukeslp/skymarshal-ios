/**
 * Data Manager for @bluesky/skymarshal
 *
 * Handles import/export, backup/restore, and CAR file operations.
 * Provides data persistence and portability features.
 *
 * @module managers/DataManager
 */

import type {
  ContentItem,
  IDataManager,
  IIndexedDBProvider
} from '../types';
import { isValidAtUri } from '../utils/validation';
import { parseDate, formatDate } from '../utils/parsing';
import { STORE_NAMES } from '../database/schema';

/**
 * Backup metadata interface
 */
export interface BackupMetadata {
  /** Unique backup identifier (UUID) */
  id: string;
  /** User handle who created backup */
  handle: string;
  /** User-provided backup name */
  name: string;
  /** ISO8601 creation timestamp */
  createdAt: string;
  /** Number of items in backup */
  itemCount: number;
  /** Approximate size in bytes */
  sizeBytes: number;
}

/**
 * Internal backup storage structure
 */
interface Backup extends BackupMetadata {
  /** Serialized content items */
  data: ContentItem[];
}

/**
 * Validation result for imports
 */
interface ValidationResult {
  valid: ContentItem[];
  invalid: number;
  warnings: string[];
}

/**
 * Custom error for parsing failures
 */
export class ParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ParseError';
  }
}

/**
 * Custom error for validation failures
 */
export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

/**
 * DataManager implementation
 *
 * Provides comprehensive data management capabilities:
 * - JSON import/export with validation
 * - CSV export for spreadsheet compatibility
 * - Backup/restore system with IndexedDB storage
 * - CAR file support (Phase 2 stub)
 *
 * @example
 * const dataManager = new DataManager(dbProvider);
 *
 * // Export to JSON
 * const json = await dataManager.exportData(items, 'json');
 *
 * // Create backup
 * const backupId = await dataManager.createBackup(items, 'My Backup');
 *
 * // Restore from backup
 * const restored = await dataManager.restoreBackup(backupId);
 */
export class DataManager implements IDataManager {
  constructor(private db: IIndexedDBProvider) {}

  /**
   * Import data from JSON file content
   *
   * Validates structure and filters invalid items.
   * Returns only valid ContentItem objects.
   *
   * Performance: 1,000 items in <1s
   *
   * @param fileContent - JSON string containing ContentItem array
   * @returns Array of validated ContentItem objects
   * @throws ParseError if JSON is invalid
   *
   * @example
   * const items = await dataManager.importData(jsonString);
   * console.log(`Imported ${items.length} items`);
   */
  async importData(fileContent: string): Promise<ContentItem[]> {
    // Parse JSON
    let parsed: any;
    try {
      parsed = JSON.parse(fileContent);
    } catch (error) {
      throw new ParseError(`Invalid JSON: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }

    // Validate it's an array
    if (!Array.isArray(parsed)) {
      throw new ParseError('Expected JSON array of ContentItem objects');
    }

    // Validate and filter items
    const result = this.validateItems(parsed);

    if (result.warnings.length > 0) {
      console.warn('Import warnings:', result.warnings);
    }

    return result.valid;
  }

  /**
   * Export data to specified format
   *
   * Supports JSON and CSV formats. Strips internal cache fields.
   *
   * Performance targets:
   * - JSON: Any size, streaming possible
   * - CSV: 10,000 items in <2s
   *
   * @param items - ContentItem array to export
   * @param format - Output format ('json' | 'csv')
   * @returns Formatted string ready for download
   *
   * @example
   * const csv = await dataManager.exportData(items, 'csv');
   * downloadFile(csv, 'export.csv', 'text/csv');
   */
  async exportData(
    items: ContentItem[],
    format: 'json' | 'csv'
  ): Promise<string> {
    if (format === 'json') {
      return this.exportToJSON(items);
    } else {
      return this.exportToCSV(items);
    }
  }

  /**
   * Load and parse exported data file
   *
   * Auto-detects JSON format. For CSV, use importData() with
   * CSV parser (not implemented in Phase 1).
   *
   * @param fileContent - File content string
   * @returns Parsed ContentItem array
   * @throws ParseError if format is invalid
   *
   * @example
   * const items = dataManager.loadExportedData(fileContent);
   */
  loadExportedData(fileContent: string): ContentItem[] {
    // For Phase 1, only support JSON
    // CSV parsing would require a more complex parser
    const trimmed = fileContent.trim();

    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      // JSON format
      let parsed: any;
      try {
        parsed = JSON.parse(fileContent);
      } catch (error) {
        throw new ParseError(`Invalid JSON: ${error instanceof Error ? error.message : 'Unknown error'}`);
      }

      if (!Array.isArray(parsed)) {
        throw new ParseError('Expected JSON array of ContentItem objects');
      }

      const result = this.validateItems(parsed);
      return result.valid;
    } else {
      throw new ParseError('CSV import not implemented in Phase 1. Use JSON format.');
    }
  }

  /**
   * Create a backup snapshot
   *
   * Stores items in IndexedDB with metadata.
   * Generates UUID for backup ID.
   *
   * Performance: <1s for typical datasets
   *
   * @param items - ContentItem array to backup
   * @param name - User-provided backup name
   * @returns Backup ID (UUID)
   * @throws Error if quota exceeded
   *
   * @example
   * const backupId = await dataManager.createBackup(items, 'Before Cleanup');
   * console.log(`Backup created: ${backupId}`);
   */
  async createBackup(items: ContentItem[], name: string): Promise<string> {
    // Generate UUID
    const id = this.generateUUID();

    // Get current user handle (for now, use 'default' - will be updated in Phase 2)
    const handle = 'default';

    // Calculate size
    const sizeBytes = this.calculateSize(items);

    // Create backup object
    const backup: Backup = {
      id,
      handle,
      name: name || `Backup ${new Date().toISOString()}`,
      createdAt: new Date().toISOString(),
      itemCount: items.length,
      sizeBytes,
      data: items
    };

    // Store in IndexedDB
    try {
      await this.db.put(STORE_NAMES.BACKUPS, backup);
    } catch (error) {
      if (error instanceof Error && error.name === 'QuotaExceededError') {
        throw new Error('DB_QUOTA_EXCEEDED: Storage quota exceeded. Delete old backups or clear data.');
      }
      throw error;
    }

    return id;
  }

  /**
   * Restore backup by ID
   *
   * Retrieves backup from IndexedDB and returns items.
   *
   * @param backupId - UUID of backup to restore
   * @returns Array of ContentItem objects from backup
   * @throws Error if backup not found
   *
   * @example
   * const items = await dataManager.restoreBackup(backupId);
   */
  async restoreBackup(backupId: string): Promise<ContentItem[]> {
    const backup = await this.db.get<Backup>(STORE_NAMES.BACKUPS, backupId);

    if (!backup) {
      throw new Error(`Backup not found: ${backupId}`);
    }

    return backup.data;
  }

  /**
   * List all backups (optionally filtered by handle)
   *
   * Returns backups sorted by creation date (newest first).
   *
   * @param handle - Optional handle to filter by
   * @returns Array of backup metadata
   *
   * @example
   * const backups = await dataManager.listBackups('alice.bsky.social');
   */
  async listBackups(handle?: string): Promise<BackupMetadata[]> {
    let backups: Backup[];

    if (handle) {
      // Query by handle index
      backups = await this.db.query<Backup>(
        STORE_NAMES.BACKUPS,
        'by_handle',
        handle
      );
    } else {
      // Get all backups
      backups = await this.db.getAll<Backup>(STORE_NAMES.BACKUPS);
    }

    // Sort by createdAt (newest first)
    backups.sort((a, b) => {
      const dateA = new Date(a.createdAt).getTime();
      const dateB = new Date(b.createdAt).getTime();
      return dateB - dateA;
    });

    // Strip data field and return metadata only
    return backups.map(({ id, handle, name, createdAt, itemCount, sizeBytes }) => ({
      id,
      handle,
      name,
      createdAt,
      itemCount,
      sizeBytes
    }));
  }

  /**
   * Delete backup by ID
   *
   * Permanently removes backup from IndexedDB.
   *
   * @param backupId - UUID of backup to delete
   *
   * @example
   * await dataManager.deleteBackup(backupId);
   */
  async deleteBackup(backupId: string): Promise<void> {
    await this.db.delete(STORE_NAMES.BACKUPS, backupId);
  }

  // ============================================================================
  // CAR File Operations (Phase 2 stub)
  // ============================================================================

  /**
   * Download CAR file for a handle (Phase 2)
   *
   * @throws Error - Not implemented in Phase 1
   */
  async downloadCAR(handle: string): Promise<Uint8Array> {
    throw new Error('CAR download requires Python backend (planned for Phase 2)');
  }

  /**
   * Import CAR file data (Phase 2)
   *
   * CAR (Content Addressable aRchive) files contain complete Bluesky
   * repository data. Parsing requires Python backend with car-mirror library.
   *
   * @param carData - CAR file binary data
   * @param handle - User handle for attribution
   * @throws Error - Not implemented in Phase 1
   */
  async importCAR(carData: Uint8Array, handle: string): Promise<ContentItem[]> {
    throw new Error('CAR import requires Python backend (planned for Phase 2)');
  }

  /**
   * Restore from CAR file path (Phase 2)
   *
   * @throws Error - Not implemented in Phase 1
   */
  async restoreCAR(carPath: string): Promise<ContentItem[]> {
    throw new Error('CAR restore requires Python backend (planned for Phase 2)');
  }

  /**
   * Hydrate items with fresh engagement data (placeholder)
   *
   * Note: Actual implementation requires API client integration.
   * Will be implemented in EngagementManager.
   */
  async hydrateItems(items: ContentItem[]): Promise<void> {
    // Placeholder - actual hydration happens in EngagementManager
    console.warn('hydrateItems: Requires API client integration (Phase 2)');
  }

  /**
   * Get local data files for handle (placeholder)
   */
  async getLocalDataFiles(handle: string): Promise<any[]> {
    // Placeholder - will integrate with file system APIs in Phase 2
    return [];
  }

  /**
   * Delete all local data for handle (placeholder)
   */
  async deleteLocalData(handle: string): Promise<void> {
    // Placeholder - will implement in Phase 2 with proper cleanup
    console.warn(`deleteLocalData: Not implemented for ${handle}`);
  }

  // ============================================================================
  // Private Helper Methods
  // ============================================================================

  /**
   * Export items to JSON format
   *
   * Strips internal cache fields (cachedAt, engagementCachedAt).
   * Pretty-prints for readability.
   */
  private exportToJSON(items: ContentItem[]): string {
    const cleaned = items.map(item => this.stripCacheFields(item));
    return JSON.stringify(cleaned, null, 2);
  }

  /**
   * Export items to CSV format
   *
   * Simplified format with core fields:
   * uri, text, createdAt, contentType, likeCount, repostCount, replyCount, engagementScore
   *
   * Performance target: 10,000 items in <2s
   */
  private exportToCSV(items: ContentItem[]): string {
    // CSV header
    const header = 'uri,text,createdAt,contentType,likeCount,repostCount,replyCount,engagementScore';

    // CSV rows
    const rows = items.map(item => {
      const fields = [
        item.uri,
        this.escapeCSV(item.text || ''),
        item.createdAt || '',
        item.contentType,
        item.likeCount?.toString() || '0',
        item.repostCount?.toString() || '0',
        item.replyCount?.toString() || '0',
        item.engagementScore.toString()
      ];

      return fields.join(',');
    });

    return [header, ...rows].join('\n');
  }

  /**
   * Escape CSV field value
   *
   * Handles commas, quotes, and newlines per CSV spec.
   */
  private escapeCSV(text: string): string {
    if (!text) return '';

    // If contains comma, quote, or newline, wrap in quotes and escape internal quotes
    if (text.includes(',') || text.includes('"') || text.includes('\n')) {
      return `"${text.replace(/"/g, '""')}"`;
    }

    return text;
  }

  /**
   * Validate array of potential ContentItem objects
   *
   * Filters invalid items and returns validation results.
   */
  private validateItems(items: any[]): ValidationResult {
    const valid: ContentItem[] = [];
    const warnings: string[] = [];
    let invalid = 0;

    for (let i = 0; i < items.length; i++) {
      const item = items[i];

      // Check required fields
      if (!item.uri || !item.cid || !item.contentType) {
        warnings.push(`Item ${i}: Missing required fields (uri, cid, contentType)`);
        invalid++;
        continue;
      }

      // Validate URI format
      if (!isValidAtUri(item.uri)) {
        warnings.push(`Item ${i}: Invalid AT URI format: ${item.uri}`);
        invalid++;
        continue;
      }

      // Validate content type
      const validTypes = ['post', 'reply', 'like', 'repost'];
      if (!validTypes.includes(item.contentType)) {
        warnings.push(`Item ${i}: Invalid content type: ${item.contentType}`);
        invalid++;
        continue;
      }

      // Validate date if present
      if (item.createdAt) {
        try {
          parseDate(item.createdAt);
        } catch {
          warnings.push(`Item ${i}: Invalid date format: ${item.createdAt}`);
          // Don't skip item, just remove invalid date
          delete item.createdAt;
        }
      }

      // Ensure engagementScore exists
      if (typeof item.engagementScore !== 'number') {
        item.engagementScore = 0;
      }

      // Add to valid items
      valid.push(item as ContentItem);
    }

    return { valid, invalid, warnings };
  }

  /**
   * Strip internal cache fields from item
   */
  private stripCacheFields(item: ContentItem): Partial<ContentItem> {
    const { cachedAt, engagementCachedAt, ...rest } = item;
    return rest;
  }

  /**
   * Calculate approximate size of items array in bytes
   */
  private calculateSize(items: ContentItem[]): number {
    // Rough approximation: JSON.stringify length * 2 (for UTF-16)
    const json = JSON.stringify(items);
    return json.length * 2;
  }

  /**
   * Generate UUID v4
   *
   * Simple implementation for browser compatibility.
   */
  private generateUUID(): string {
    // Use crypto.randomUUID if available
    if (typeof crypto !== 'undefined' && crypto.randomUUID) {
      return crypto.randomUUID();
    }

    // Fallback implementation
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = (Math.random() * 16) | 0;
      const v = c === 'x' ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
  }
}
