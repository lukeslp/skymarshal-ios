/**
 * Search Page — rebuilt from first principles.
 * Simple by default, powerful when needed.
 * Supports: text search, from:me filter, alt text / language search.
 */
import { useState, useCallback, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search as SearchIcon, User, Image, Loader2, MessageSquare, Heart, Repeat2, ChevronDown } from 'lucide-react';
import { useDocumentTitle } from '../hooks/useDocumentTitle';
import { useAuth } from '../components/auth/AuthProvider';

interface SearchResult {
  uri: string;
  cid: string;
  author: {
    did: string;
    handle: string;
    displayName?: string;
    avatar?: string;
  };
  record: {
    text?: string;
    createdAt?: string;
    embed?: any;
    langs?: string[];
  };
  likeCount?: number;
  repostCount?: number;
  replyCount?: number;
  indexedAt?: string;
  altTexts?: string[];
}

const RESULTS_PER_PAGE = 25;

export function Search() {
  useDocumentTitle('Search');
  const navigate = useNavigate();
  const { session } = useAuth();
  const inputRef = useRef<HTMLInputElement>(null);

  const [query, setQuery] = useState('');
  const [fromMe, setFromMe] = useState(false);
  const [searchAltText, setSearchAltText] = useState(false);
  const [results, setResults] = useState<SearchResult[]>([]);
  const [cursor, setCursor] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [hasSearched, setHasSearched] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  const buildQuery = useCallback(() => {
    let q = query.trim();
    if (!q) return '';
    if (fromMe && session?.handle) {
      q = `from:${session.handle} ${q}`;
    }
    return q;
  }, [query, fromMe, session?.handle]);

  function extractAltTexts(record: any): string[] {
    const alts: string[] = [];
    try {
      const embed = record?.embed;
      if (!embed) return alts;
      if (embed.images) {
        for (const img of embed.images) {
          if (img.alt) alts.push(img.alt);
        }
      }
      if (embed.media?.images) {
        for (const img of embed.media.images) {
          if (img.alt) alts.push(img.alt);
        }
      }
    } catch {
      // ignore
    }
    return alts;
  }

  const doSearch = useCallback(async (newSearch: boolean) => {
    const q = buildQuery();
    if (!q) return;

    if (newSearch) {
      setLoading(true);
      setResults([]);
      setCursor(undefined);
    } else {
      setLoadingMore(true);
    }
    setHasSearched(true);

    try {
      const pdsUrl = session?.pdsUrl || session?.serviceUrl || 'https://bsky.social';
      const params = new URLSearchParams({
        q,
        limit: String(RESULTS_PER_PAGE),
      });
      if (!newSearch && cursor) {
        params.append('cursor', cursor);
      }

      const response = await fetch(
        `${pdsUrl}/xrpc/app.bsky.feed.searchPosts?${params}`,
        {
          headers: {
            Authorization: `Bearer ${session?.accessJwt}`,
          },
        }
      );

      if (!response.ok) {
        throw new Error(`Search failed: ${response.statusText}`);
      }

      const data = await response.json();
      let posts: SearchResult[] = (data.posts || []).map((post: any) => ({
        uri: post.uri,
        cid: post.cid,
        author: {
          did: post.author?.did,
          handle: post.author?.handle,
          displayName: post.author?.displayName,
          avatar: post.author?.avatar,
        },
        record: post.record || {},
        likeCount: post.likeCount,
        repostCount: post.repostCount,
        replyCount: post.replyCount,
        indexedAt: post.indexedAt,
        altTexts: extractAltTexts(post.record),
      }));

      // Client-side alt text filtering if enabled
      if (searchAltText && query.trim()) {
        const lowerQuery = query.trim().toLowerCase();
        posts = posts.filter(
          (p) =>
            p.record.text?.toLowerCase().includes(lowerQuery) ||
            p.altTexts?.some((alt) => alt.toLowerCase().includes(lowerQuery))
        );
      }

      if (newSearch) {
        setResults(posts);
      } else {
        setResults((prev) => [...prev, ...posts]);
      }
      setCursor(data.cursor);
    } catch (err: any) {
      console.error('Search error:', err);
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  }, [buildQuery, cursor, session, searchAltText, query]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    doSearch(true);
  };

  const handleLoadMore = () => {
    if (cursor && !loadingMore) {
      doSearch(false);
    }
  };

  const formatDate = (dateStr?: string) => {
    if (!dateStr) return '';
    return new Date(dateStr).toLocaleDateString(undefined, {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const handlePostClick = (uri: string) => {
    const encoded = encodeURIComponent(uri);
    navigate(`/thread/${encoded}`);
  };

  return (
    <div className="max-w-3xl mx-auto">
      <h1 className="text-2xl font-bold mb-6">Search</h1>

      <form onSubmit={handleSubmit} className="mb-6 space-y-3">
        <div className="relative">
          <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search posts..."
            className="w-full pl-11 pr-4 py-3 bg-card border border-border rounded-lg text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/50 text-base"
            aria-label="Search query"
          />
        </div>

        <div className="flex flex-wrap items-center gap-4">
          <label className="flex items-center gap-2 text-sm cursor-pointer select-none">
            <input
              type="checkbox"
              checked={fromMe}
              onChange={(e) => setFromMe(e.target.checked)}
              className="rounded border-border accent-primary w-4 h-4"
            />
            <User className="w-3.5 h-3.5 text-muted-foreground" aria-hidden="true" />
            <span className="text-foreground">From me</span>
          </label>

          <label className="flex items-center gap-2 text-sm cursor-pointer select-none">
            <input
              type="checkbox"
              checked={searchAltText}
              onChange={(e) => setSearchAltText(e.target.checked)}
              className="rounded border-border accent-primary w-4 h-4"
            />
            <Image className="w-3.5 h-3.5 text-muted-foreground" aria-hidden="true" />
            <span className="text-foreground">Include alt text</span>
          </label>

          <button
            type="submit"
            disabled={!query.trim() || loading}
            className="ml-auto px-5 py-2 bg-primary text-primary-foreground rounded-lg font-medium text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed transition-opacity"
          >
            {loading ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              'Search'
            )}
          </button>
        </div>
      </form>

      {loading && (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="w-8 h-8 animate-spin text-primary" />
        </div>
      )}

      {!loading && hasSearched && results.length === 0 && (
        <div className="text-center py-12 text-muted-foreground">
          <SearchIcon className="w-12 h-12 mx-auto mb-3 opacity-50" />
          <p>No results found. Try different keywords.</p>
        </div>
      )}

      {!loading && results.length > 0 && (
        <div className="space-y-1">
          <p className="text-sm text-muted-foreground mb-3">
            {results.length} result{results.length !== 1 ? 's' : ''}
            {cursor ? '+' : ''}
          </p>

          {results.map((post) => (
            <button
              key={post.uri}
              type="button"
              onClick={() => handlePostClick(post.uri)}
              className="w-full text-left bg-card border border-border rounded-lg p-4 hover:bg-accent/50 transition-colors"
            >
              <div className="flex items-center gap-2 mb-2">
                {post.author.avatar ? (
                  <img
                    src={post.author.avatar}
                    alt=""
                    className="w-8 h-8 rounded-full object-cover"
                  />
                ) : (
                  <div className="w-8 h-8 rounded-full bg-muted flex items-center justify-center">
                    <User className="w-4 h-4 text-muted-foreground" />
                  </div>
                )}
                <div className="min-w-0">
                  <span className="font-medium text-foreground text-sm truncate block">
                    {post.author.displayName || post.author.handle}
                  </span>
                  <span className="text-xs text-muted-foreground">
                    @{post.author.handle} · {formatDate(post.record.createdAt || post.indexedAt)}
                  </span>
                </div>
              </div>

              {post.record.text && (
                <p className="text-sm text-foreground mb-2 whitespace-pre-wrap line-clamp-4">
                  {post.record.text}
                </p>
              )}

              {post.altTexts && post.altTexts.length > 0 && searchAltText && (
                <div className="text-xs text-info bg-info/10 rounded px-2 py-1 mb-2 inline-block">
                  <Image className="w-3 h-3 inline mr-1" aria-hidden="true" />
                  Alt: {post.altTexts.join('; ').substring(0, 120)}
                  {post.altTexts.join('; ').length > 120 ? '...' : ''}
                </div>
              )}

              <div className="flex items-center gap-4 text-xs text-muted-foreground">
                <span className="flex items-center gap-1">
                  <MessageSquare className="w-3.5 h-3.5" aria-hidden="true" />
                  {post.replyCount ?? 0}
                </span>
                <span className="flex items-center gap-1">
                  <Repeat2 className="w-3.5 h-3.5" aria-hidden="true" />
                  {post.repostCount ?? 0}
                </span>
                <span className="flex items-center gap-1">
                  <Heart className="w-3.5 h-3.5" aria-hidden="true" />
                  {post.likeCount ?? 0}
                </span>
              </div>
            </button>
          ))}

          {cursor && (
            <div className="pt-4 text-center">
              <button
                type="button"
                onClick={handleLoadMore}
                disabled={loadingMore}
                className="px-6 py-2.5 bg-card border border-border rounded-lg text-sm font-medium text-foreground hover:bg-accent/50 disabled:opacity-50 transition-colors"
              >
                {loadingMore ? (
                  <Loader2 className="w-4 h-4 animate-spin inline mr-2" />
                ) : (
                  <ChevronDown className="w-4 h-4 inline mr-2" />
                )}
                Load More
              </button>
            </div>
          )}
        </div>
      )}

      {!hasSearched && (
        <div className="text-center py-16 text-muted-foreground">
          <SearchIcon className="w-16 h-16 mx-auto mb-4 opacity-30" />
          <p className="text-lg mb-2">Search Bluesky</p>
          <p className="text-sm">
            Find posts by keyword. Use "From me" to search your own posts.
            <br />
            Enable "Include alt text" to also search image descriptions.
          </p>
        </div>
      )}
    </div>
  );
}
