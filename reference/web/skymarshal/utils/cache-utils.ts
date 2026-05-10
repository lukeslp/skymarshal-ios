/**
 * Cache utilities for TTL management and freshness
 * @module utils/cache-utils
 */

/**
 * Cache item with metadata
 */
export interface CacheItem<T> {
  data: T;
  cachedAt: number;
  expiresAt: number;
}

/**
 * Calculate dynamic TTL based on content age
 * New posts (< 24h): 1 hour cache
 * Recent posts (< 7d): 6 hour cache
 * Old posts (> 7d): 24 hour cache
 *
 * @param createdAt - ISO8601 timestamp when content was created
 * @returns TTL in milliseconds
 *
 * @example
 * calculateTTL('2024-01-15T10:00:00Z') // 3600000 for new post
 * calculateTTL('2023-01-15T10:00:00Z') // 86400000 for old post
 */
export function calculateTTL(createdAt: string): number {
  if (!createdAt) {
    // Default to 1 hour if no creation date
    return 3600000;
  }

  const created = new Date(createdAt).getTime();
  const now = Date.now();
  const ageMs = now - created;

  const ONE_HOUR = 3600000;
  const SIX_HOURS = 6 * ONE_HOUR;
  const ONE_DAY = 24 * ONE_HOUR;
  const SEVEN_DAYS = 7 * ONE_DAY;

  // Content less than 1 day old: cache for 1 hour
  if (ageMs < ONE_DAY) {
    return ONE_HOUR;
  }

  // Content less than 7 days old: cache for 6 hours
  if (ageMs < SEVEN_DAYS) {
    return SIX_HOURS;
  }

  // Content older than 7 days: cache for 24 hours
  return ONE_DAY;
}

/**
 * Check if cached item is stale
 *
 * @param cachedAt - Timestamp when item was cached (milliseconds)
 * @param ttl - Time-to-live in milliseconds
 * @returns True if cache is stale
 *
 * @example
 * isStale(Date.now() - 7200000, 3600000) // true (cached 2h ago, TTL 1h)
 * isStale(Date.now() - 1800000, 3600000) // false (cached 30m ago, TTL 1h)
 */
export function isStale(cachedAt: number, ttl: number): boolean {
  if (typeof cachedAt !== 'number' || typeof ttl !== 'number') {
    return true; // Treat invalid cache as stale
  }

  if (cachedAt <= 0 || ttl <= 0) {
    return true;
  }

  const now = Date.now();
  const age = now - cachedAt;

  return age > ttl;
}

/**
 * Generate cache key from URI and type
 *
 * @param uri - AT Protocol URI
 * @param type - Cache type (e.g., 'engagement', 'profile', 'thread')
 * @returns Cache key string
 *
 * @example
 * getCacheKey('at://did:plc:abc/app.bsky.feed.post/123', 'engagement')
 * // 'engagement:at://did:plc:abc/app.bsky.feed.post/123'
 */
export function getCacheKey(uri: string, type: string): string {
  return `${type}:${uri}`;
}

/**
 * Check if item should be refreshed based on age and TTL
 *
 * @param item - Item with optional cache metadata
 * @returns True if item should be refreshed
 *
 * @example
 * shouldRefresh({ cachedAt: Date.now() - 7200000, createdAt: '2024-01-15T10:00:00Z' })
 * // true (cached 2h ago, but new content should refresh after 1h)
 */
export function shouldRefresh(item: { cachedAt?: number; createdAt?: string }): boolean {
  // If never cached, should refresh
  if (!item.cachedAt) {
    return true;
  }

  // If no creation date, use default 1 hour TTL
  const ttl = item.createdAt ? calculateTTL(item.createdAt) : 3600000;

  return isStale(item.cachedAt, ttl);
}

/**
 * Calculate expiration timestamp
 *
 * @param ttl - Time-to-live in milliseconds
 * @returns Expiration timestamp (milliseconds)
 *
 * @example
 * calculateExpiration(3600000) // Date.now() + 3600000
 */
export function calculateExpiration(ttl: number): number {
  return Date.now() + ttl;
}

/**
 * Check if cache entry has expired
 *
 * @param expiresAt - Expiration timestamp
 * @returns True if expired
 *
 * @example
 * isExpired(Date.now() - 1000) // true
 * isExpired(Date.now() + 1000) // false
 */
export function isExpired(expiresAt: number): boolean {
  return Date.now() > expiresAt;
}

/**
 * Create cache item with TTL
 *
 * @param data - Data to cache
 * @param ttl - Time-to-live in milliseconds
 * @returns Cache item with metadata
 *
 * @example
 * createCacheItem({ likes: 10 }, 3600000)
 * // { data: { likes: 10 }, cachedAt: ..., expiresAt: ... }
 */
export function createCacheItem<T>(data: T, ttl: number): CacheItem<T> {
  const now = Date.now();

  return {
    data,
    cachedAt: now,
    expiresAt: now + ttl
  };
}

/**
 * Get remaining TTL for cached item
 *
 * @param cachedAt - Timestamp when cached
 * @param ttl - Original TTL
 * @returns Remaining TTL in milliseconds (0 if expired)
 *
 * @example
 * getRemainingTTL(Date.now() - 1800000, 3600000) // ~1800000 (30m left)
 */
export function getRemainingTTL(cachedAt: number, ttl: number): number {
  const age = Date.now() - cachedAt;
  const remaining = ttl - age;

  return Math.max(0, remaining);
}

/**
 * Cache statistics
 */
export interface CacheStats {
  hits: number;
  misses: number;
  size: number;
  hitRate: number;
}

/**
 * Simple in-memory cache with TTL support
 */
export class TTLCache<T> {
  private cache = new Map<string, CacheItem<T>>();
  private stats = { hits: 0, misses: 0 };

  constructor(private defaultTTL: number = 3600000) {
    if (defaultTTL <= 0) {
      throw new Error('Default TTL must be positive');
    }
  }

  /**
   * Set cache entry
   */
  set(key: string, value: T, ttl?: number): void {
    const effectiveTTL = ttl ?? this.defaultTTL;
    this.cache.set(key, createCacheItem(value, effectiveTTL));
  }

  /**
   * Get cache entry
   */
  get(key: string): T | null {
    const entry = this.cache.get(key);

    if (!entry) {
      this.stats.misses++;
      return null;
    }

    // Check if expired
    if (isExpired(entry.expiresAt)) {
      this.cache.delete(key);
      this.stats.misses++;
      return null;
    }

    this.stats.hits++;
    return entry.data;
  }

  /**
   * Check if key exists and is not expired
   */
  has(key: string): boolean {
    const entry = this.cache.get(key);

    if (!entry) {
      return false;
    }

    if (isExpired(entry.expiresAt)) {
      this.cache.delete(key);
      return false;
    }

    return true;
  }

  /**
   * Delete cache entry
   */
  delete(key: string): boolean {
    return this.cache.delete(key);
  }

  /**
   * Clear all cache entries
   */
  clear(): void {
    this.cache.clear();
    this.stats = { hits: 0, misses: 0 };
  }

  /**
   * Get cache size
   */
  get size(): number {
    return this.cache.size;
  }

  /**
   * Get cache statistics
   */
  getStats(): CacheStats {
    const total = this.stats.hits + this.stats.misses;
    const hitRate = total > 0 ? this.stats.hits / total : 0;

    return {
      hits: this.stats.hits,
      misses: this.stats.misses,
      size: this.cache.size,
      hitRate
    };
  }

  /**
   * Prune expired entries
   */
  prune(): number {
    let pruned = 0;

    for (const [key, entry] of this.cache.entries()) {
      if (isExpired(entry.expiresAt)) {
        this.cache.delete(key);
        pruned++;
      }
    }

    return pruned;
  }

  /**
   * Get all keys
   */
  keys(): string[] {
    return Array.from(this.cache.keys());
  }

  /**
   * Get all values (non-expired)
   */
  values(): T[] {
    const values: T[] = [];

    for (const [key, entry] of this.cache.entries()) {
      if (!isExpired(entry.expiresAt)) {
        values.push(entry.data);
      } else {
        this.cache.delete(key);
      }
    }

    return values;
  }
}

/**
 * Memoize async function with TTL cache
 *
 * @param fn - Async function to memoize
 * @param keyFn - Function to generate cache key from args
 * @param ttl - Time-to-live in milliseconds
 * @returns Memoized function
 *
 * @example
 * const memoized = memoize(
 *   async (id: string) => fetchData(id),
 *   (id) => id,
 *   3600000
 * )
 */
export function memoize<Args extends unknown[], R>(
  fn: (...args: Args) => Promise<R>,
  keyFn: (...args: Args) => string,
  ttl: number = 3600000
): (...args: Args) => Promise<R> {
  const cache = new TTLCache<R>(ttl);

  return async (...args: Args): Promise<R> => {
    const key = keyFn(...args);
    const cached = cache.get(key);

    if (cached !== null) {
      return cached;
    }

    const result = await fn(...args);
    cache.set(key, result);

    return result;
  };
}
