/**
 * Settings Manager for @bluesky/skymarshal
 *
 * Manages user preferences with IndexedDB persistence. Provides default
 * settings, validation, and merge capabilities for partial updates.
 *
 * @module managers/SettingsManager
 */

import type { UserSettings, ISettingsManager, IIndexedDBProvider } from '../types';
import { DEFAULT_SETTINGS, DB_STORES } from '../models/enums';
import { clampNumber } from '../utils/validation';

/**
 * Settings Manager Class
 *
 * Handles loading, saving, and resetting user settings with validation
 * and default value management.
 */
export class SettingsManager implements ISettingsManager {
  constructor(private db: IIndexedDBProvider) {}

  /**
   * Load user settings from IndexedDB
   *
   * @param handle - User handle
   * @returns User settings with defaults applied if not found
   */
  async loadSettings(handle: string): Promise<UserSettings> {
    try {
      // Attempt to load settings from database
      const stored = await this.db.get<UserSettings & { handle: string }>(
        DB_STORES.USER_SETTINGS,
        handle
      );

      if (!stored) {
        // Return defaults if no settings found
        return this.getDefaults();
      }

      // Validate and merge with defaults to ensure all required fields exist
      return this.validateSettings(stored);
    } catch (error) {
      console.error('Failed to load settings:', error);
      // Return defaults on error
      return this.getDefaults();
    }
  }

  /**
   * Save user settings to IndexedDB
   *
   * @param handle - User handle
   * @param settings - Complete or partial settings to save
   */
  async saveSettings(handle: string, settings: UserSettings): Promise<void> {
    try {
      // Load existing settings
      const existing = await this.loadSettings(handle);

      // Merge with existing settings
      const merged = this.mergeSettings(existing, settings);

      // Validate merged settings
      const validated = this.validateSettings(merged);

      // Store with handle as key
      await this.db.put(DB_STORES.USER_SETTINGS, {
        ...validated,
        handle
      });
    } catch (error) {
      console.error('Failed to save settings:', error);
      throw new Error(`Failed to save settings for ${handle}: ${error}`);
    }
  }

  /**
   * Get default settings
   *
   * @returns Default settings object
   */
  getDefaults(): UserSettings {
    return {
      useSubjectEngagementForReposts: DEFAULT_SETTINGS.useSubjectEngagementForReposts,
      downloadLimitDefault: DEFAULT_SETTINGS.downloadLimitDefault,
      engagementScoreWeights: {
        likes: DEFAULT_SETTINGS.engagementScoreWeights.likes,
        reposts: DEFAULT_SETTINGS.engagementScoreWeights.reposts,
        replies: DEFAULT_SETTINGS.engagementScoreWeights.replies
      },
      cacheTtlSeconds: DEFAULT_SETTINGS.cacheTtlSeconds,
      batchSize: DEFAULT_SETTINGS.batchSize,
      localBackupRetentionDays: DEFAULT_SETTINGS.localBackupRetentionDays
    };
  }

  /**
   * Apply defaults to partial settings
   *
   * @param partial - Partial settings object
   * @returns Complete settings with defaults applied
   */
  applyDefaults(partial: Partial<UserSettings>): UserSettings {
    const defaults = this.getDefaults();
    return this.mergeSettings(defaults, partial);
  }

  /**
   * Merge partial settings with base settings
   *
   * @param base - Base settings object
   * @param partial - Partial settings to merge
   * @returns Merged settings
   * @private
   */
  private mergeSettings(
    base: UserSettings,
    partial: Partial<UserSettings>
  ): UserSettings {
    return {
      useSubjectEngagementForReposts:
        partial.useSubjectEngagementForReposts ?? base.useSubjectEngagementForReposts,
      downloadLimitDefault: partial.downloadLimitDefault ?? base.downloadLimitDefault,
      engagementScoreWeights: {
        likes: partial.engagementScoreWeights?.likes ?? base.engagementScoreWeights.likes,
        reposts:
          partial.engagementScoreWeights?.reposts ?? base.engagementScoreWeights.reposts,
        replies:
          partial.engagementScoreWeights?.replies ?? base.engagementScoreWeights.replies
      },
      cacheTtlSeconds: partial.cacheTtlSeconds ?? base.cacheTtlSeconds,
      batchSize: partial.batchSize ?? base.batchSize,
      localBackupRetentionDays:
        partial.localBackupRetentionDays ?? base.localBackupRetentionDays
    };
  }

  /**
   * Validate settings values
   *
   * Ensures all numeric values are within reasonable ranges and
   * all required fields are present.
   *
   * @param settings - Settings to validate
   * @returns Validated settings
   * @private
   */
  private validateSettings(settings: Partial<UserSettings>): UserSettings {
    const defaults = this.getDefaults();

    return {
      useSubjectEngagementForReposts:
        typeof settings.useSubjectEngagementForReposts === 'boolean'
          ? settings.useSubjectEngagementForReposts
          : defaults.useSubjectEngagementForReposts,

      downloadLimitDefault: clampNumber(
        settings.downloadLimitDefault ?? defaults.downloadLimitDefault,
        1,
        100000
      ),

      engagementScoreWeights: {
        likes: clampNumber(
          settings.engagementScoreWeights?.likes ?? defaults.engagementScoreWeights.likes,
          0,
          100
        ),
        reposts: clampNumber(
          settings.engagementScoreWeights?.reposts ??
            defaults.engagementScoreWeights.reposts,
          0,
          100
        ),
        replies: clampNumber(
          settings.engagementScoreWeights?.replies ??
            defaults.engagementScoreWeights.replies,
          0,
          100
        )
      },

      cacheTtlSeconds: clampNumber(
        settings.cacheTtlSeconds ?? defaults.cacheTtlSeconds,
        60, // Minimum 1 minute
        604800 // Maximum 7 days
      ),

      batchSize: clampNumber(settings.batchSize ?? defaults.batchSize, 1, 1000),

      localBackupRetentionDays: clampNumber(
        settings.localBackupRetentionDays ?? defaults.localBackupRetentionDays,
        1,
        365
      )
    };
  }
}

/**
 * Update user settings with partial values
 *
 * Convenience function for updating specific settings without loading/saving manually.
 *
 * @param manager - Settings manager instance
 * @param handle - User handle
 * @param partial - Partial settings to update
 *
 * @example
 * await updateSettings(manager, 'alice.bsky.social', { batchSize: 200 });
 */
export async function updateSettings(
  manager: ISettingsManager,
  handle: string,
  partial: Partial<UserSettings>
): Promise<void> {
  const current = await manager.loadSettings(handle);
  const updated = manager.applyDefaults({ ...current, ...partial });
  await manager.saveSettings(handle, updated);
}

/**
 * Reset user settings to defaults
 *
 * Convenience function for resetting settings to default values.
 *
 * @param manager - Settings manager instance
 * @param handle - User handle
 *
 * @example
 * await resetSettings(manager, 'alice.bsky.social');
 */
export async function resetSettings(
  manager: ISettingsManager,
  handle: string
): Promise<void> {
  const defaults = manager.getDefaults();
  await manager.saveSettings(handle, defaults);
}
