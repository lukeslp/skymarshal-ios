/**
 * Batching and batch processing utilities
 * @module utils/batching
 */

/**
 * Batch processing options
 */
export interface BatchOptions {
  /** Maximum number of concurrent batches */
  concurrency?: number;
  /** Number of retry attempts on failure */
  retryCount?: number;
  /** Delay in ms between retries */
  retryDelay?: number;
  /** Callback for progress updates */
  onProgress?: (processed: number, total: number) => void;
  /** Callback for individual batch completion */
  onBatchComplete?: (batchIndex: number, results: unknown[]) => void;
  /** Continue processing on error or stop */
  stopOnError?: boolean;
}

/**
 * Split array into batches of specified size
 *
 * @param items - Array to split
 * @param batchSize - Size of each batch
 * @returns Array of batches
 *
 * @example
 * batch([1, 2, 3, 4, 5], 2) // [[1, 2], [3, 4], [5]]
 */
export function batch<T>(items: T[], batchSize: number): T[][] {
  if (!Array.isArray(items)) {
    throw new Error('Items must be an array');
  }

  if (batchSize <= 0) {
    throw new Error('Batch size must be positive');
  }

  const batches: T[][] = [];

  for (let i = 0; i < items.length; i += batchSize) {
    batches.push(items.slice(i, i + batchSize));
  }

  return batches;
}

/**
 * Process items in batches with concurrency control
 *
 * @param items - Items to process
 * @param processor - Async function that processes a batch
 * @param options - Batch processing options
 * @returns Array of all results
 *
 * @example
 * await batchProcess(
 *   items,
 *   async (batch) => fetchData(batch),
 *   { concurrency: 3, retryCount: 2 }
 * )
 */
export async function batchProcess<T, R>(
  items: T[],
  processor: (batch: T[]) => Promise<R[]>,
  options: BatchOptions = {}
): Promise<R[]> {
  const {
    concurrency = 5,
    retryCount = 3,
    retryDelay = 1000,
    onProgress,
    onBatchComplete,
    stopOnError = false
  } = options;

  if (!Array.isArray(items)) {
    throw new Error('Items must be an array');
  }

  if (items.length === 0) {
    return [];
  }

  const results: R[] = [];
  const errors: Error[] = [];
  let processedCount = 0;

  // Process batches with concurrency limit
  const processBatch = async (batchItems: T[], batchIndex: number): Promise<R[]> => {
    let lastError: Error | null = null;

    for (let attempt = 0; attempt <= retryCount; attempt++) {
      try {
        const batchResults = await processor(batchItems);

        processedCount += batchItems.length;

        if (onProgress) {
          onProgress(processedCount, items.length);
        }

        if (onBatchComplete) {
          onBatchComplete(batchIndex, batchResults);
        }

        return batchResults;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));

        // If not last attempt, wait before retry
        if (attempt < retryCount) {
          await sleep(retryDelay * Math.pow(2, attempt)); // Exponential backoff
        }
      }
    }

    // All retries failed
    errors.push(lastError!);

    if (stopOnError) {
      throw lastError;
    }

    // Return empty array on failure (if not stopping on error)
    return [];
  };

  // Split into batches for concurrency control
  const batches: T[][] = [];
  for (let i = 0; i < items.length; i += Math.ceil(items.length / concurrency)) {
    batches.push(items.slice(i, i + Math.ceil(items.length / concurrency)));
  }

  // Process all batches
  const batchPromises = batches.map((batchItems, index) => processBatch(batchItems, index));

  const batchResults = await Promise.all(batchPromises);

  // Flatten results
  for (const batchResult of batchResults) {
    results.push(...batchResult);
  }

  // Report errors if any occurred
  if (errors.length > 0 && !stopOnError) {
    console.warn(`Batch processing completed with ${errors.length} errors:`, errors);
  }

  return results;
}

/**
 * Rate-limited fetch for multiple URLs
 *
 * @param urls - URLs to fetch
 * @param rateLimit - Max requests per second
 * @returns Array of responses
 *
 * @example
 * await rateLimitedFetch(['url1', 'url2', 'url3'], 2) // Max 2 req/sec
 */
export async function rateLimitedFetch<T>(
  urls: string[],
  rateLimit: number
): Promise<T[]> {
  if (!Array.isArray(urls)) {
    throw new Error('URLs must be an array');
  }

  if (rateLimit <= 0) {
    throw new Error('Rate limit must be positive');
  }

  const results: T[] = [];
  const delayMs = 1000 / rateLimit;

  for (const url of urls) {
    try {
      const response = await fetch(url);

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json() as T;
      results.push(data);

      // Wait before next request (except for last one)
      if (urls.indexOf(url) < urls.length - 1) {
        await sleep(delayMs);
      }
    } catch (error) {
      console.error(`Failed to fetch ${url}:`, error);
      // Continue with other URLs
    }
  }

  return results;
}

/**
 * Deduplicate array by key function
 *
 * @param items - Array to deduplicate
 * @param keyFn - Function to extract unique key
 * @returns Deduplicated array
 *
 * @example
 * deduplicate([{id: 1}, {id: 2}, {id: 1}], item => item.id)
 * // [{id: 1}, {id: 2}]
 */
export function deduplicate<T>(items: T[], keyFn: (item: T) => string | number): T[] {
  const seen = new Set<string | number>();
  const result: T[] = [];

  for (const item of items) {
    const key = keyFn(item);

    if (!seen.has(key)) {
      seen.add(key);
      result.push(item);
    }
  }

  return result;
}

/**
 * Chunk array into smaller arrays
 * Alias for batch() function
 *
 * @param items - Array to chunk
 * @param size - Chunk size
 * @returns Array of chunks
 */
export function chunk<T>(items: T[], size: number): T[][] {
  return batch(items, size);
}

/**
 * Sleep for specified milliseconds
 *
 * @param ms - Milliseconds to sleep
 * @returns Promise that resolves after delay
 */
export function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Retry async function with exponential backoff
 *
 * @param fn - Async function to retry
 * @param maxAttempts - Maximum retry attempts
 * @param delayMs - Initial delay in ms
 * @returns Result of successful execution
 *
 * @example
 * await retry(() => fetchData(), 3, 1000)
 */
export async function retry<T>(
  fn: () => Promise<T>,
  maxAttempts: number = 3,
  delayMs: number = 1000
): Promise<T> {
  let lastError: Error | null = null;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));

      // If not last attempt, wait before retry
      if (attempt < maxAttempts - 1) {
        await sleep(delayMs * Math.pow(2, attempt)); // Exponential backoff
      }
    }
  }

  throw lastError || new Error('Retry failed');
}

/**
 * Queue for sequential processing with concurrency limit
 */
export class AsyncQueue<T> {
  private queue: Array<() => Promise<T>> = [];
  private processing = 0;
  private results: T[] = [];

  constructor(private concurrency: number = 5) {
    if (concurrency <= 0) {
      throw new Error('Concurrency must be positive');
    }
  }

  /**
   * Add task to queue
   */
  add(task: () => Promise<T>): void {
    this.queue.push(task);
    this.process();
  }

  /**
   * Process queue
   */
  private async process(): Promise<void> {
    if (this.processing >= this.concurrency || this.queue.length === 0) {
      return;
    }

    this.processing++;
    const task = this.queue.shift();

    if (task) {
      try {
        const result = await task();
        this.results.push(result);
      } catch (error) {
        console.error('Queue task failed:', error);
      } finally {
        this.processing--;
        this.process(); // Process next task
      }
    }
  }

  /**
   * Wait for all tasks to complete
   */
  async drain(): Promise<T[]> {
    while (this.queue.length > 0 || this.processing > 0) {
      await sleep(100);
    }
    return this.results;
  }

  /**
   * Get current queue size
   */
  get size(): number {
    return this.queue.length;
  }

  /**
   * Check if queue is empty and not processing
   */
  get idle(): boolean {
    return this.queue.length === 0 && this.processing === 0;
  }
}

/**
 * Parallel map with concurrency limit
 *
 * @param items - Items to map
 * @param mapper - Async mapper function
 * @param concurrency - Max concurrent operations
 * @returns Mapped results
 *
 * @example
 * await parallelMap(urls, fetchUrl, 5) // Max 5 concurrent fetches
 */
export async function parallelMap<T, R>(
  items: T[],
  mapper: (item: T, index: number) => Promise<R>,
  concurrency: number = 5
): Promise<R[]> {
  const queue = new AsyncQueue<R>(concurrency);

  items.forEach((item, index) => {
    queue.add(() => mapper(item, index));
  });

  return queue.drain();
}
