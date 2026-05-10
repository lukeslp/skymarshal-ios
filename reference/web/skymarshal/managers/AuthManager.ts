/**
 * Authentication Manager for Skymarshal
 *
 * Wraps @bluesky/api-client's AuthManager with additional functionality:
 * - Handle validation and normalization
 * - Session state tracking
 * - Error handling and normalization
 * - Convenience methods for auth state
 *
 * @module managers/AuthManager
 */

import type { IAuthManager } from '../types';
import { isValidHandle } from '../utils/validation';

/**
 * Custom error for authentication failures
 */
export class AuthError extends Error {
  constructor(message: string, public code: string = 'AUTH_ERROR') {
    super(message);
    this.name = 'AuthError';
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
 * Authentication Manager
 *
 * Thin wrapper around @bluesky/api-client AuthManager that adds:
 * - Handle validation before login
 * - Session state tracking
 * - Error normalization
 * - Convenience methods
 */
export class AuthManager implements IAuthManager {
  private apiClientAuth: any; // AuthManager from @bluesky/api-client
  private currentSession: any | null = null; // Session from api-client

  /**
   * Create a new AuthManager
   *
   * @param apiClientAuth - AuthManager instance from @bluesky/api-client
   *
   * @example
   * ```typescript
   * import { BlueSkyClient } from '@bluesky/api-client';
   * import { AuthManager as SkymarshalAuthManager } from '@bluesky/skymarshal';
   *
   * const client = new BlueSkyClient();
   * const authManager = new SkymarshalAuthManager(client.auth);
   * ```
   */
  constructor(apiClientAuth: any) {
    this.apiClientAuth = apiClientAuth;
    this.currentSession = this.apiClientAuth.getSession();
  }

  /**
   * Normalize and validate a Bluesky handle
   *
   * @param handle - Raw handle input (may include @ prefix, may be missing .bsky.social)
   * @returns Normalized handle
   * @throws ValidationError if handle format is invalid
   *
   * @example
   * ```typescript
   * normalizeHandle('@alice') // 'alice.bsky.social'
   * normalizeHandle('bob.bsky.social') // 'bob.bsky.social'
   * normalizeHandle('charlie.custom.com') // 'charlie.custom.com'
   * ```
   */
  private normalizeHandle(handle: string): string {
    if (!handle || typeof handle !== 'string') {
      throw new ValidationError('Handle must be a non-empty string');
    }

    // Remove @ prefix if present
    let normalized = handle.trim().toLowerCase();
    if (normalized.startsWith('@')) {
      normalized = normalized.slice(1);
    }

    // Add .bsky.social if no domain present
    if (!normalized.includes('.')) {
      normalized = `${normalized}.bsky.social`;
    }

    // Validate final format
    if (!isValidHandle(normalized)) {
      throw new ValidationError(`Invalid handle format: ${handle}`);
    }

    return normalized;
  }

  /**
   * Login with handle and password
   *
   * @param handle - Bluesky handle (with or without @ prefix, domain optional)
   * @param password - Account password or app password
   * @returns Session object from api-client
   * @throws ValidationError for invalid handle format
   * @throws AuthError for authentication failures
   *
   * @example
   * ```typescript
   * try {
   *   const session = await authManager.login('alice', 'password123');
   *   console.log('Logged in as:', session.handle);
   * } catch (error) {
   *   if (error instanceof ValidationError) {
   *     console.error('Invalid handle:', error.message);
   *   } else if (error instanceof AuthError) {
   *     console.error('Login failed:', error.message);
   *   }
   * }
   * ```
   */
  async login(handle: string, password: string): Promise<any> {
    // Validate and normalize handle
    const normalizedHandle = this.normalizeHandle(handle);

    if (!password || typeof password !== 'string' || password.length === 0) {
      throw new ValidationError('Password must be a non-empty string');
    }

    try {
      // Delegate to api-client's AuthManager
      const session = await this.apiClientAuth.login({
        identifier: normalizedHandle,
        password: password,
      });

      // Track session locally
      this.currentSession = session;

      return session;
    } catch (error: any) {
      // Normalize errors from api-client
      if (error.message?.includes('Invalid identifier or password')) {
        throw new AuthError('Invalid credentials', 'INVALID_CREDENTIALS');
      } else if (error.message?.includes('Session expired')) {
        throw new AuthError('Session expired', 'SESSION_EXPIRED');
      } else if (error.message?.includes('network') || error.message?.includes('fetch')) {
        throw new AuthError('Network error during login', 'NETWORK_ERROR');
      } else {
        throw new AuthError(error.message || 'Login failed', 'AUTH_FAILED');
      }
    }
  }

  /**
   * Logout and clear current session
   *
   * @example
   * ```typescript
   * await authManager.logout();
   * console.log('Logged out');
   * ```
   */
  async logout(): Promise<void> {
    try {
      // Delegate to api-client
      this.apiClientAuth.logout();

      // Clear local session
      this.currentSession = null;
    } catch (error: any) {
      // Logout should always succeed, even if there's an error
      console.warn('Error during logout:', error);
      this.currentSession = null;
    }
  }

  /**
   * Refresh the current session
   *
   * @returns Updated session object
   * @throws AuthError if session refresh fails
   *
   * @example
   * ```typescript
   * try {
   *   const newSession = await authManager.refreshSession();
   *   console.log('Session refreshed');
   * } catch (error) {
   *   console.error('Failed to refresh session, please login again');
   *   await authManager.login(handle, password);
   * }
   * ```
   */
  async refreshSession(): Promise<any> {
    if (!this.currentSession) {
      throw new AuthError('No active session to refresh', 'NO_SESSION');
    }

    try {
      // Delegate to api-client
      const success = await this.apiClientAuth.refreshSession();

      if (!success) {
        this.currentSession = null;
        throw new AuthError('Session refresh failed', 'REFRESH_FAILED');
      }

      // Get updated session
      this.currentSession = this.apiClientAuth.getSession();

      return this.currentSession;
    } catch (error: any) {
      this.currentSession = null;

      if (error instanceof AuthError) {
        throw error;
      }

      throw new AuthError(
        error.message || 'Failed to refresh session',
        'REFRESH_ERROR'
      );
    }
  }

  /**
   * Get the current session
   *
   * @returns Current session or null if not authenticated
   *
   * @example
   * ```typescript
   * const session = authManager.getCurrentSession();
   * if (session) {
   *   console.log('Logged in as:', session.handle);
   * }
   * ```
   */
  getCurrentSession(): any | null {
    // Always sync with api-client's session
    this.currentSession = this.apiClientAuth.getSession();
    return this.currentSession;
  }

  /**
   * Check if user is currently authenticated
   *
   * @returns True if there is an active session
   *
   * @example
   * ```typescript
   * if (!authManager.isAuthenticated()) {
   *   console.log('Please login first');
   * }
   * ```
   */
  isAuthenticated(): boolean {
    // Sync with api-client
    this.currentSession = this.apiClientAuth.getSession();
    return this.currentSession !== null;
  }

  /**
   * Get the current user's handle
   *
   * @returns Handle or null if not authenticated
   *
   * @example
   * ```typescript
   * const handle = authManager.getCurrentHandle();
   * console.log('Current user:', handle || 'Not logged in');
   * ```
   */
  getCurrentHandle(): string | null {
    // Sync with api-client
    this.currentSession = this.apiClientAuth.getSession();
    return this.currentSession?.handle ?? null;
  }

  /**
   * Get the current user's DID
   *
   * @returns DID or null if not authenticated
   *
   * @example
   * ```typescript
   * const did = authManager.getCurrentDid();
   * if (did) {
   *   console.log('User DID:', did);
   * }
   * ```
   */
  getCurrentDid(): string | null {
    // Sync with api-client
    this.currentSession = this.apiClientAuth.getSession();
    return this.currentSession?.did ?? null;
  }
}
