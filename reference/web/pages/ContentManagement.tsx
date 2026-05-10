/**
 * Content Management — full Skymarshal content management hub.
 *
 * Fetches user's posts/likes/reposts/follows/blocks directly from the AT Protocol,
 * provides search (including alt text), engagement analysis, bulk selection,
 * and deletion workflows with progress tracking.
 */
import { useState, useEffect, useMemo, useCallback, useRef } from 'react';
import { useAuth } from '../components/auth/AuthProvider';
import { useDocumentTitle } from '../hooks/useDocumentTitle';
import {
  Search, Trash2, Download, Loader2,
  Heart, Repeat2, MessageSquare, Image,
  RefreshCw, CheckSquare, Square, AlertTriangle, ArrowUpDown
} from 'lucide-react';
import { usePostCache } from '../contexts/PostCacheContext';

type ContentTab = 'posts' | 'likes' | 'reposts';

interface ContentRecord {
  uri: string;
  cid: string;
  text?: string;
  createdAt?: string;
  likeCount?: number;
  repostCount?: number;
  replyCount?: number;
  embed?: any;
  altTexts?: string[];
  langs?: string[];
  subjectUri?: string;
  handle?: string;
  displayName?: string;
}

interface FetchProgress { phase: string; current: number; total: number; }
type SortField = 'date' | 'likes' | 'reposts' | 'replies' | 'engagement';
type SortDir = 'asc' | 'desc';

const TABS: { id: ContentTab; label: string }[] = [
  { id: 'posts', label: 'Posts' },
  { id: 'likes', label: 'Likes' },
  { id: 'reposts', label: 'Reposts' },
];
const PAGE_SIZE = 50;

function extractAltTexts(embed: any): string[] {
  const alts: string[] = [];
  if (!embed) return alts;
  if (embed.images) for (const img of embed.images) { if (img.alt) alts.push(img.alt); }
  if (embed.media?.images) for (const img of embed.media.images) { if (img.alt) alts.push(img.alt); }
  return alts;
}

function engScore(r: ContentRecord): number {
  return (r.likeCount || 0) + 2 * (r.repostCount || 0) + 2.5 * (r.replyCount || 0);
}

function parseAtUri(uri: string) {
  const m = uri.match(/^at:\/\/([^/]+)\/([^/]+)\/([^/]+)$/);
  return m ? { repo: m[1], collection: m[2], rkey: m[3] } : null;
}

function relTime(iso?: string): string {
  if (!iso) return '';
  const diff = Date.now() - new Date(iso).getTime();
  if (diff < 60_000) return 'just now';
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m`;
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h`;
  if (diff < 2_592_000_000) return `${Math.floor(diff / 86_400_000)}d`;
  return new Date(iso).toLocaleDateString();
}

export default function ContentManagement() {
  useDocumentTitle('Content');
  const { client, session } = useAuth();

  const [records, setRecords] = useState<Map<ContentTab, ContentRecord[]>>(new Map());
  const [activeTabs, setActiveTabs] = useState<Set<ContentTab>>(new Set(['posts']));
  const [loading, setLoading] = useState(false);
  const [progress, setProgress] = useState<FetchProgress | null>(null);
  const [fetchLimit, setFetchLimit] = useState<number>(0); // 0 = all
  const postCache = usePostCache();

  const [query, setQuery] = useState('');
  const [searchAltText, setSearchAltText] = useState(false);
  const [sortField, setSortField] = useState<SortField>('date');
  const [sortDir, setSortDir] = useState<SortDir>('desc');

  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [deleting, setDeleting] = useState(false);
  const [deleteProgress, setDeleteProgress] = useState<{ done: number; total: number } | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE);

  const collectionMap: Record<ContentTab, string> = {
    posts: 'app.bsky.feed.post',
    likes: 'app.bsky.feed.like',
    reposts: 'app.bsky.feed.repost',
  };

  const fetchContent = useCallback(async (tab: ContentTab, limit: number = 0, forceRefresh = false) => {
    if (!session?.did || !client) return;

    const cacheKey = `content:${session.did}:${tab}:${limit}`;
    if (!forceRefresh) {
      const cached = postCache.getCached(cacheKey);
      if (cached) {
        setRecords(prev => new Map(prev).set(tab, cached.posts as ContentRecord[]));
        return;
      }
    }

    setLoading(true);
    setProgress({ phase: `Fetching ${tab}...`, current: 0, total: 0 });
    const all: ContentRecord[] = [];
    let cursor: string | undefined;
    const pdsUrl = (session as any).pdsUrl || 'https://bsky.social';

    try {
      do {
        const url = new URL(`${pdsUrl}/xrpc/com.atproto.repo.listRecords`);
        url.searchParams.set('repo', session.did);
        url.searchParams.set('collection', collectionMap[tab]);
        url.searchParams.set('limit', '100');
        if (cursor) url.searchParams.set('cursor', cursor);

        const res = await fetch(url.toString(), {
          headers: { Authorization: `Bearer ${(session as any).accessJwt}` },
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();

        for (const rec of data.records || []) {
          const val = rec.value || {};
          all.push({
            uri: rec.uri,
            cid: rec.cid,
            text: val.text,
            createdAt: val.createdAt,
            embed: val.embed,
            altTexts: extractAltTexts(val.embed),
            langs: val.langs,
            subjectUri: val.subject?.uri,
            handle: typeof val.subject === 'string' ? val.subject : undefined,
          });
        }
        cursor = data.cursor;
        setProgress({ phase: `Fetching ${tab}...`, current: all.length, total: all.length });
        // Stop if we've hit the user-specified limit
        if (limit > 0 && all.length >= limit) {
          all.splice(limit);
          break;
        }
      } while (cursor);

      if (tab === 'posts' && all.length > 0) {
        setProgress({ phase: 'Loading engagement...', current: 0, total: all.length });
        for (let i = 0; i < all.length; i += 25) {
          const batch = all.slice(i, i + 25).map(p => p.uri);
          try {
            const url = `https://public.api.bsky.app/xrpc/app.bsky.feed.getPosts?${batch.map(u => `uris=${encodeURIComponent(u)}`).join('&')}`;
            const res = await fetch(url);
            if (res.ok) {
              const data = await res.json();
              for (const post of data.posts || []) {
                const item = all.find(a => a.uri === post.uri);
                if (item) {
                  item.likeCount = post.likeCount || 0;
                  item.repostCount = post.repostCount || 0;
                  item.replyCount = post.replyCount || 0;
                }
              }
            }
          } catch { /* continue */ }
          setProgress({ phase: 'Loading engagement...', current: Math.min(i + 25, all.length), total: all.length });
        }
      }
      setRecords(prev => new Map(prev).set(tab, all));
      postCache.setCached(cacheKey, {
        posts: all,
        cursor: undefined,
        fetchedAt: Date.now(),
        totalFetched: all.length,
      });
    } catch (err) {
      console.error(`Failed to fetch ${tab}:`, err);
    } finally {
      setLoading(false);
      setProgress(null);
    }
  }, [client, session, postCache]);

  // Fetch all active tabs on mount or when tabs change
  const fetchActiveTabs = useCallback(async () => {
    for (const tab of activeTabs) {
      if (!records.has(tab)) {
        await fetchContent(tab, fetchLimit);
      }
    }
  }, [activeTabs, fetchLimit]);

  useEffect(() => {
    fetchActiveTabs();
    setSelected(new Set());
    setVisibleCount(PAGE_SIZE);
  }, [activeTabs]);

  const toggleTab = (tab: ContentTab) => {
    setActiveTabs(prev => {
      const next = new Set(prev);
      if (next.has(tab)) {
        if (next.size > 1) next.delete(tab); // keep at least one
      } else {
        next.add(tab);
      }
      return next;
    });
  };

  // Merge records from all active tabs
  const currentRecords = useMemo(() => {
    const merged: ContentRecord[] = [];
    for (const tab of activeTabs) {
      merged.push(...(records.get(tab) || []));
    }
    return merged;
  }, [activeTabs, records]);

  const filtered = useMemo(() => {
    let items = [...currentRecords];
    const q = query.toLowerCase().trim();
    if (q) {
      items = items.filter(item => {
        const textMatch = item.text?.toLowerCase().includes(q);
        const altMatch = searchAltText && item.altTexts?.some(a => a.toLowerCase().includes(q));
        const handleMatch = item.handle?.toLowerCase().includes(q);
        const nameMatch = item.displayName?.toLowerCase().includes(q);
        return textMatch || altMatch || handleMatch || nameMatch;
      });
    }
    items.sort((a, b) => {
      let cmp = 0;
      switch (sortField) {
        case 'date': cmp = new Date(a.createdAt || 0).getTime() - new Date(b.createdAt || 0).getTime(); break;
        case 'likes': cmp = (a.likeCount || 0) - (b.likeCount || 0); break;
        case 'reposts': cmp = (a.repostCount || 0) - (b.repostCount || 0); break;
        case 'replies': cmp = (a.replyCount || 0) - (b.replyCount || 0); break;
        case 'engagement': cmp = engScore(a) - engScore(b); break;
      }
      return sortDir === 'desc' ? -cmp : cmp;
    });
    return items;
  }, [currentRecords, query, searchAltText, sortField, sortDir]);

  const visible = useMemo(() => filtered.slice(0, visibleCount), [filtered, visibleCount]);

  const toggleSelect = (uri: string) => {
    setSelected(prev => { const n = new Set(prev); if (n.has(uri)) n.delete(uri); else n.add(uri); return n; });
  };
  const selectAll = () => {
    setSelected(selected.size === filtered.length ? new Set() : new Set(filtered.map(r => r.uri)));
  };

  const handleDelete = async () => {
    if (!session?.did || !client || selected.size === 0) return;
    setDeleting(true);
    setShowDeleteConfirm(false);
    const toDelete = [...selected];
    setDeleteProgress({ done: 0, total: toDelete.length });
    const pdsUrl = (session as any).pdsUrl || 'https://bsky.social';
    let done = 0;
    for (const uri of toDelete) {
      const parsed = parseAtUri(uri);
      if (!parsed) continue;
      try {
        await fetch(`${pdsUrl}/xrpc/com.atproto.repo.deleteRecord`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${(session as any).accessJwt}` },
          body: JSON.stringify({ repo: session.did, collection: parsed.collection, rkey: parsed.rkey }),
        });
      } catch (err) { console.error(`Failed to delete ${uri}:`, err); }
      done++;
      setDeleteProgress({ done, total: toDelete.length });
    }
    setRecords(prev => {
      const next = new Map(prev);
      for (const tab of activeTabs) {
        next.set(tab, (next.get(tab) || []).filter(r => !selected.has(r.uri)));
      }
      return next;
    });
    setSelected(new Set());
    setDeleting(false);
    setDeleteProgress(null);
  };

  const handleExport = () => {
    const data = filtered.map(r => ({
      uri: r.uri, text: r.text || '', createdAt: r.createdAt || '',
      likes: r.likeCount || 0, reposts: r.repostCount || 0, replies: r.replyCount || 0,
      altTexts: (r.altTexts || []).join(' | '), langs: (r.langs || []).join(', '),
    }));
    const csv = [Object.keys(data[0] || {}).join(','), ...data.map(row => Object.values(row).map(v => `"${String(v).replace(/"/g, '""')}"`).join(','))].join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const tabNames = [...activeTabs].join('-');
    const a = document.createElement('a'); a.href = url; a.download = `bluescreen-${tabNames}-${new Date().toISOString().split('T')[0]}.csv`; a.click();
    URL.revokeObjectURL(url);
  };

  const isPostLike = activeTabs.has('posts') || activeTabs.has('likes') || activeTabs.has('reposts');

  return (
    <div className="max-w-5xl mx-auto">
      <div className="mb-4">
        <h1 className="text-2xl font-bold">My Content</h1>
        <p className="text-sm text-muted-foreground">Browse, search, and manage your own posts, likes, and reposts on Bluesky</p>
      </div>

      {/* Content type checkboxes + fetch limit */}
      <div className="flex flex-wrap items-center gap-4 mb-4">
        <div className="flex flex-wrap gap-2">
          {TABS.map(tab => (
            <label key={tab.id}
              className={`flex items-center gap-2 px-3 py-2 rounded-lg border cursor-pointer transition-colors text-sm font-medium ${
                activeTabs.has(tab.id)
                  ? 'border-primary bg-primary/10 text-primary'
                  : 'border-border hover:bg-muted text-muted-foreground'
              }`}>
              <input type="checkbox" checked={activeTabs.has(tab.id)} onChange={() => toggleTab(tab.id)}
                className="rounded border-border accent-primary" />
              {tab.label}
              {records.has(tab.id) && <span className="text-xs opacity-60">({(records.get(tab.id) || []).length})</span>}
            </label>
          ))}
        </div>
        <div className="flex items-center gap-2 text-sm">
          <span className="text-muted-foreground">Fetch:</span>
          <select value={fetchLimit} onChange={e => setFetchLimit(Number(e.target.value))}
            className="bg-muted border border-border rounded px-2 py-1 text-sm text-foreground" aria-label="Records to fetch">
            <option value={0}>All</option>
            <option value={100}>100</option>
            <option value={500}>500</option>
            <option value={1000}>1000</option>
          </select>
        </div>
      </div>

      {/* Search */}
      <div className="space-y-3 mb-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <input type="text" value={query} onChange={e => setQuery(e.target.value)}
            placeholder="Search content..." aria-label="Search content"
            className="w-full pl-10 pr-4 py-2.5 bg-muted/50 border border-border rounded-lg text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/50" />
        </div>
        <div className="flex flex-wrap items-center gap-4 text-sm">
          <label className="flex items-center gap-2 text-muted-foreground cursor-pointer">
            <input type="checkbox" checked={searchAltText} onChange={e => setSearchAltText(e.target.checked)} className="rounded border-border accent-primary" />
            <Image className="w-3.5 h-3.5" /> Search alt text
          </label>
          {isPostLike && (
            <div className="flex items-center gap-2 ml-auto">
              <span className="text-muted-foreground">Sort:</span>
              <select value={sortField} onChange={e => setSortField(e.target.value as SortField)} aria-label="Sort field"
                className="bg-muted border border-border rounded px-2 py-1 text-sm text-foreground">
                <option value="date">Date</option>
                <option value="likes">Likes</option>
                <option value="reposts">Reposts</option>
                <option value="replies">Replies</option>
                <option value="engagement">Engagement</option>
              </select>
              <button type="button" onClick={() => setSortDir(d => d === 'asc' ? 'desc' : 'asc')}
                className="p-1 rounded hover:bg-muted" aria-label={`Sort ${sortDir === 'asc' ? 'descending' : 'ascending'}`}>
                <ArrowUpDown className="w-4 h-4" />
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Toolbar */}
      <div className="flex items-center gap-2 mb-3 text-sm">
        <button type="button" onClick={selectAll}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded border border-border hover:bg-muted transition-colors">
          {selected.size === filtered.length && filtered.length > 0 ? <CheckSquare className="w-4 h-4" /> : <Square className="w-4 h-4" />}
          {selected.size > 0 ? `${selected.size} selected` : 'Select all'}
        </button>
        {selected.size > 0 && (
          <button type="button" onClick={() => setShowDeleteConfirm(true)} disabled={deleting}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded bg-destructive text-destructive-foreground hover:bg-destructive/90 transition-colors disabled:opacity-50">
            <Trash2 className="w-4 h-4" /> Delete ({selected.size})
          </button>
        )}
        <button type="button" onClick={handleExport} disabled={filtered.length === 0}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded border border-border hover:bg-muted transition-colors disabled:opacity-50">
          <Download className="w-4 h-4" /> Export CSV
        </button>
        <button type="button" onClick={() => { postCache.clearCache(`content:${session?.did}`); setRecords(new Map()); fetchActiveTabs(); }} disabled={loading}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded border border-border hover:bg-muted transition-colors disabled:opacity-50 ml-auto">
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} /> Refresh
        </button>
      </div>

      {/* Progress */}
      {(progress || deleteProgress) && (
        <div className="mb-4 space-y-1">
          <p className="text-sm text-muted-foreground">
            {deleteProgress ? `Deleting ${deleteProgress.done}/${deleteProgress.total}...` : `${progress!.phase} ${progress!.current}${progress!.total ? `/${progress!.total}` : ''}`}
          </p>
          <div className="h-1.5 bg-muted rounded-full overflow-hidden">
            <div className="h-full bg-primary rounded-full transition-all"
              style={{ width: `${deleteProgress ? (deleteProgress.done / deleteProgress.total) * 100 : progress!.total ? (progress!.current / progress!.total) * 100 : 0}%` }} />
          </div>
        </div>
      )}

      {/* Content list */}
      {loading && !progress ? (
        <div className="flex items-center justify-center py-16"><Loader2 className="w-8 h-8 animate-spin text-primary" /></div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 text-muted-foreground">
          {currentRecords.length === 0 ? 'No content found. Select content types above and click Refresh.' : 'No items match your search.'}
        </div>
      ) : (
        <div className="space-y-1">
          {visible.map(item => (
            <div key={item.uri}
              className={`flex items-start gap-3 p-3 rounded-lg border transition-colors ${selected.has(item.uri) ? 'border-primary/50 bg-primary/5' : 'border-border hover:bg-muted/50'}`}>
              <button type="button" onClick={() => toggleSelect(item.uri)} className="mt-0.5 flex-shrink-0"
                aria-label={selected.has(item.uri) ? 'Deselect' : 'Select'}>
                {selected.has(item.uri) ? <CheckSquare className="w-5 h-5 text-primary" /> : <Square className="w-5 h-5 text-muted-foreground" />}
              </button>
              <div className="flex-1 min-w-0">
                {item.text && <p className="text-sm text-foreground whitespace-pre-wrap break-words line-clamp-4">{item.text}</p>}
                {item.altTexts && item.altTexts.length > 0 && (
                  <p className="text-xs text-muted-foreground mt-1 italic"><Image className="w-3 h-3 inline mr-1" />Alt: {item.altTexts.join(' | ')}</p>
                )}
                {(item.handle || item.displayName) && <p className="text-sm text-foreground">{item.displayName || item.handle}</p>}
                <div className="flex items-center gap-3 mt-1.5 text-xs text-muted-foreground">
                  {item.createdAt && <span>{relTime(item.createdAt)}</span>}
                  {item.likeCount != null && <span className="flex items-center gap-0.5"><Heart className="w-3 h-3" /> {item.likeCount}</span>}
                  {item.repostCount != null && <span className="flex items-center gap-0.5"><Repeat2 className="w-3 h-3" /> {item.repostCount}</span>}
                  {item.replyCount != null && <span className="flex items-center gap-0.5"><MessageSquare className="w-3 h-3" /> {item.replyCount}</span>}
                  {item.langs && item.langs.length > 0 && <span className="opacity-60">{item.langs.join(', ')}</span>}
                </div>
              </div>
            </div>
          ))}
          {visibleCount < filtered.length && (
            <button type="button" onClick={() => setVisibleCount(v => Math.min(v + PAGE_SIZE, filtered.length))}
              className="w-full py-3 text-sm text-muted-foreground hover:text-foreground transition-colors">
              Show more ({filtered.length - visibleCount} remaining)
            </button>
          )}
        </div>
      )}

      {/* Delete confirmation */}
      {showDeleteConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" role="dialog" aria-modal="true">
          <div className="bg-card border border-border rounded-xl p-6 max-w-md w-full mx-4 shadow-xl">
            <div className="flex items-center gap-3 mb-4">
              <AlertTriangle className="w-6 h-6 text-destructive flex-shrink-0" />
              <h2 className="text-lg font-semibold">Confirm Deletion</h2>
            </div>
            <p className="text-sm text-muted-foreground mb-6">
              This will permanently delete <strong>{selected.size}</strong> items from your Bluesky account. This cannot be undone.
            </p>
            <div className="flex gap-3 justify-end">
              <button type="button" onClick={() => setShowDeleteConfirm(false)}
                className="px-4 py-2 rounded-lg border border-border hover:bg-muted transition-colors text-sm">Cancel</button>
              <button type="button" onClick={handleDelete}
                className="px-4 py-2 rounded-lg bg-destructive text-destructive-foreground hover:bg-destructive/90 transition-colors text-sm">
                Delete {selected.size} items
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
