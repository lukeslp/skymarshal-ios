/**
 * SearchManager - Multi-field filtering and sorting for Bluesky content
 *
 * Provides high-performance search capabilities with:
 * - Multi-field filtering (keywords, date ranges, engagement thresholds)
 * - Multiple sort options (newest, oldest, engagement, likes, reposts, replies)
 * - Weighted engagement calculation (likes×1 + reposts×2 + replies×3)
 * - Pagination support
 *
 * Performance target: Search 10,000 items in <100ms
 *
 * @module SearchManager
 */

import type {
  ContentItem,
  SearchFilters,
  SearchOptions,
  ISearchManager
} from '../types';
import { ContentType, DEFAULT_SETTINGS } from '../models/enums';

/**
 * Search manager implementation
 *
 * This class provides in-memory search and filtering of content items.
 * It does NOT query the database directly - that's handled by the calling code.
 */
export class SearchManager implements ISearchManager {
  /** Cache of calculated engagement scores to avoid recalculation */
  private engagementCache: Map<string, number> = new Map();

  /** Default engagement weights */
  private defaultWeights: { likes: number; reposts: number; replies: number } = {
    likes: DEFAULT_SETTINGS.engagementScoreWeights.likes,
    reposts: DEFAULT_SETTINGS.engagementScoreWeights.reposts,
    replies: DEFAULT_SETTINGS.engagementScoreWeights.replies
  };

  /**
   * Build complete search filters from partial criteria
   *
   * Applies defaults for any missing filter fields.
   *
   * @param criteria - Partial filter criteria
   * @returns Complete SearchFilters object
   */
  buildFilters(criteria: Partial<SearchFilters>): SearchFilters {
    return {
      contentType: criteria.contentType ?? ContentType.ALL,
      keywords: criteria.keywords,
      minEngagement: criteria.minEngagement,
      maxEngagement: criteria.maxEngagement,
      minLikes: criteria.minLikes,
      maxLikes: criteria.maxLikes,
      minReposts: criteria.minReposts,
      maxReposts: criteria.maxReposts,
      minReplies: criteria.minReplies,
      maxReplies: criteria.maxReplies,
      startDate: criteria.startDate,
      endDate: criteria.endDate,
      authorDid: criteria.authorDid,
      excludedUris: criteria.excludedUris
    };
  }

  /**
   * Search content items with filters and options
   *
   * This is the main search method. It:
   * 1. Filters items using applyFilter()
   * 2. Sorts results using sortResults()
   * 3. Applies pagination (offset + limit)
   *
   * Performance: O(n) for filtering, O(n log n) for sorting where n = items.length
   *
   * @param items - Array of content items to search
   * @param filters - Search filter criteria
   * @param options - Search options (sorting, pagination)
   * @returns Promise resolving to filtered and sorted items
   */
  async search(
    items: ContentItem[],
    filters: SearchFilters,
    options?: SearchOptions
  ): Promise<ContentItem[]> {
    const startTime = performance.now();

    // Step 1: Apply filters
    let results = items.filter(item => this.applyFilter(item, filters));

    // Step 2: Sort results
    if (options?.sortBy) {
      results = this.sortResults(results, options.sortBy);
    }

    // Step 3: Apply pagination
    const offset = options?.offset ?? 0;
    const limit = options?.limit;

    if (offset > 0 || limit !== undefined) {
      const end = limit !== undefined ? offset + limit : undefined;
      results = results.slice(offset, end);
    }

    const duration = performance.now() - startTime;

    // Log performance warning if search is slow
    if (duration > 100) {
      console.warn(
        `SearchManager: Search took ${duration.toFixed(2)}ms for ${items.length} items (target: <100ms)`
      );
    }

    return results;
  }

  /**
   * Sort results by specified criteria
   *
   * Supports multiple sort modes:
   * - 'newest': Most recent first (by createdAt)
   * - 'oldest': Oldest first (by createdAt)
   * - 'engagement': Highest engagement score first
   * - 'likes': Most likes first
   * - 'reposts': Most reposts first
   * - 'replies': Most replies first
   *
   * @param items - Items to sort
   * @param sortBy - Sort mode
   * @returns Sorted array (does NOT modify original)
   */
  sortResults(items: ContentItem[], sortBy: string): ContentItem[] {
    // Create shallow copy to avoid mutating original array
    const sorted = [...items];

    switch (sortBy) {
      case 'newest':
        sorted.sort((a, b) => {
          if (!a.createdAt) return 1;
          if (!b.createdAt) return -1;
          return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
        });
        break;

      case 'oldest':
        sorted.sort((a, b) => {
          if (!a.createdAt) return 1;
          if (!b.createdAt) return -1;
          return new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime();
        });
        break;

      case 'engagement':
        sorted.sort((a, b) => {
          const scoreA = this.getOrCalculateEngagement(a);
          const scoreB = this.getOrCalculateEngagement(b);
          return scoreB - scoreA; // Descending
        });
        break;

      case 'likes':
        sorted.sort((a, b) => {
          const likesA = a.likeCount ?? 0;
          const likesB = b.likeCount ?? 0;
          return likesB - likesA; // Descending
        });
        break;

      case 'reposts':
        sorted.sort((a, b) => {
          const repostsA = a.repostCount ?? 0;
          const repostsB = b.repostCount ?? 0;
          return repostsB - repostsA; // Descending
        });
        break;

      case 'replies':
        sorted.sort((a, b) => {
          const repliesA = a.replyCount ?? 0;
          const repliesB = b.replyCount ?? 0;
          return repliesB - repliesA; // Descending
        });
        break;

      default:
        console.warn(`SearchManager: Unknown sort mode "${sortBy}", returning unsorted`);
    }

    return sorted;
  }

  /**
   * Apply filter to a single content item
   *
   * Returns true if the item matches ALL filter criteria.
   * Empty/undefined filter fields are ignored (treated as "match all").
   *
   * @param item - Content item to check
   * @param filters - Filter criteria
   * @returns True if item matches all filters
   */
  applyFilter(item: ContentItem, filters: SearchFilters): boolean {
    // Content type filter
    if (filters.contentType !== ContentType.ALL) {
      // Map content type enum to item's contentType field
      const typeMap: Record<string, string> = {
        [ContentType.POSTS]: 'post',
        [ContentType.REPLIES]: 'reply',
        [ContentType.LIKES]: 'like',
        [ContentType.REPOSTS]: 'repost'
      };

      const expectedType = typeMap[filters.contentType];
      if (expectedType && item.contentType !== expectedType) {
        return false;
      }
    }

    // Keyword filter (case-insensitive, partial match)
    if (filters.keywords && filters.keywords.length > 0) {
      if (!item.text) return false;

      const textLower = item.text.toLowerCase();
      const hasAllKeywords = filters.keywords.every(keyword =>
        textLower.includes(keyword.toLowerCase())
      );

      if (!hasAllKeywords) return false;
    }

    // Engagement score filters
    const engagement = this.getOrCalculateEngagement(item);

    if (filters.minEngagement !== undefined && engagement < filters.minEngagement) {
      return false;
    }

    if (filters.maxEngagement !== undefined && engagement > filters.maxEngagement) {
      return false;
    }

    // Like count filters
    const likes = item.likeCount ?? 0;

    if (filters.minLikes !== undefined && likes < filters.minLikes) {
      return false;
    }

    if (filters.maxLikes !== undefined && likes > filters.maxLikes) {
      return false;
    }

    // Repost count filters
    const reposts = item.repostCount ?? 0;

    if (filters.minReposts !== undefined && reposts < filters.minReposts) {
      return false;
    }

    if (filters.maxReposts !== undefined && reposts > filters.maxReposts) {
      return false;
    }

    // Reply count filters
    const replies = item.replyCount ?? 0;

    if (filters.minReplies !== undefined && replies < filters.minReplies) {
      return false;
    }

    if (filters.maxReplies !== undefined && replies > filters.maxReplies) {
      return false;
    }

    // Date range filters
    if (item.createdAt) {
      const itemDate = new Date(item.createdAt);

      if (filters.startDate) {
        const startDate = this.parseDate(filters.startDate);
        if (startDate && itemDate < startDate) {
          return false;
        }
      }

      if (filters.endDate) {
        const endDate = this.parseDate(filters.endDate);
        if (endDate && itemDate > endDate) {
          return false;
        }
      }
    }

    // Author DID filter
    if (filters.authorDid && 'authorDid' in item) {
      if ((item as any).authorDid !== filters.authorDid) {
        return false;
      }
    }

    // Excluded URIs
    if (filters.excludedUris && filters.excludedUris.length > 0) {
      if (filters.excludedUris.includes(item.uri)) {
        return false;
      }
    }

    return true;
  }

  /**
   * Calculate engagement score using weighted formula
   *
   * Default formula: likes×1 + reposts×2 + replies×3
   *
   * Custom weights can be provided to adjust the formula.
   *
   * @param likes - Number of likes
   * @param reposts - Number of reposts
   * @param replies - Number of replies
   * @param weights - Optional custom weights (defaults to 1/2/3)
   * @returns Calculated engagement score
   */
  calculateEngagement(
    likes: number,
    reposts: number,
    replies: number,
    weights?: Record<string, number>
  ): number {
    const w = weights ?? this.defaultWeights;

    return (
      likes * (w.likes ?? 1) +
      reposts * (w.reposts ?? 2) +
      replies * (w.replies ?? 3)
    );
  }

  /**
   * Get or calculate engagement score for an item
   *
   * Uses cached score if available, otherwise calculates and caches it.
   * This optimization is critical for sorting performance.
   *
   * @param item - Content item
   * @returns Engagement score
   * @private
   */
  private getOrCalculateEngagement(item: ContentItem): number {
    // Check if item already has engagementScore set
    if (item.engagementScore !== undefined && item.engagementScore !== 0) {
      return item.engagementScore;
    }

    // Check cache
    const cached = this.engagementCache.get(item.uri);
    if (cached !== undefined) {
      return cached;
    }

    // Calculate and cache
    const score = this.calculateEngagement(
      item.likeCount ?? 0,
      item.repostCount ?? 0,
      item.replyCount ?? 0
    );

    this.engagementCache.set(item.uri, score);
    return score;
  }

  /**
   * Parse date string to Date object
   *
   * Supports:
   * - ISO8601 strings (e.g., "2024-01-15T12:00:00Z")
   * - YYYY-MM-DD strings (e.g., "2024-01-15")
   *
   * @param dateStr - Date string
   * @returns Date object or null if invalid
   * @private
   */
  private parseDate(dateStr: string): Date | null {
    try {
      // Try parsing as ISO8601 first
      const date = new Date(dateStr);

      // Check if date is valid
      if (isNaN(date.getTime())) {
        return null;
      }

      return date;
    } catch {
      return null;
    }
  }

  /**
   * Clear the engagement score cache
   *
   * Should be called when engagement data is updated to ensure
   * fresh calculations on next search.
   */
  clearCache(): void {
    this.engagementCache.clear();
  }

  /**
   * Update default engagement weights
   *
   * @param weights - New weight configuration
   */
  setEngagementWeights(weights: { likes: number; reposts: number; replies: number }): void {
    this.defaultWeights = weights;
    this.clearCache(); // Clear cache since formula changed
  }

  /**
   * Get current engagement weights
   *
   * @returns Current weight configuration
   */
  getEngagementWeights(): { likes: number; reposts: number; replies: number } {
    return { ...this.defaultWeights };
  }
}
