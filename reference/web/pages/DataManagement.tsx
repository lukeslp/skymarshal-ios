/**
 * Data Management — export your Bluesky data and manage account-level danger operations.
 *
 * - Export: CAR (full repo), JSON, CSV with optional timeframe filtering
 * - Danger Zone: delete records from Bluesky (com.atproto.repo.deleteRecord) with safety guards
 */
import { useState, useCallback } from 'react';
import { useDocumentTitle } from '../hooks/useDocumentTitle';
import { useAuth } from "../components/auth/AuthProvider";
import {
  Download, AlertCircle, CheckCircle, Archive,
  FileJson, FileSpreadsheet, Loader2, Trash2, ShieldAlert, Calendar
} from 'lucide-react';

type ExportFormat = 'car' | 'json' | 'csv';
type TimeframeOption = 'all' | '7d' | '30d' | '90d' | '1y';
type DangerTarget = 'posts' | 'likes' | 'reposts' | 'follows' | 'blocks';

type MessageType = 'success' | 'error' | 'info';
interface Message { type: MessageType; text: string; }

const TIMEFRAME_OPTIONS: { value: TimeframeOption; label: string }[] = [
  { value: 'all', label: 'All time' },
  { value: '7d', label: 'Last 7 days' },
  { value: '30d', label: 'Last 30 days' },
  { value: '90d', label: 'Last 90 days' },
  { value: '1y', label: 'Last year' },
];

const DANGER_TARGETS: { id: DangerTarget; label: string; collection: string; desc: string }[] = [
  { id: 'posts', label: 'All Posts', collection: 'app.bsky.feed.post', desc: 'Delete every post you have ever made' },
  { id: 'likes', label: 'All Likes', collection: 'app.bsky.feed.like', desc: 'Remove all your likes' },
  { id: 'reposts', label: 'All Reposts', collection: 'app.bsky.feed.repost', desc: 'Remove all your reposts' },
  { id: 'follows', label: 'All Follows', collection: 'app.bsky.graph.follow', desc: 'Unfollow everyone' },
  { id: 'blocks', label: 'All Blocks', collection: 'app.bsky.graph.block', desc: 'Remove all blocks' },
];

function getTimeframeCutoff(tf: TimeframeOption): Date | null {
  if (tf === 'all') return null;
  const now = new Date();
  const days = tf === '7d' ? 7 : tf === '30d' ? 30 : tf === '90d' ? 90 : 365;
  return new Date(now.getTime() - days * 86_400_000);
}

function downloadBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return (bytes / Math.pow(k, i)).toFixed(1) + ' ' + sizes[i];
}

export default function DataManagement() {
  useDocumentTitle('Data Management');
  const { session } = useAuth();

  const [message, setMessage] = useState<Message | null>(null);
  const [exporting, setExporting] = useState(false);
  const [timeframe, setTimeframe] = useState<TimeframeOption>('all');

  // Danger zone state
  const [dangerTarget, setDangerTarget] = useState<DangerTarget | null>(null);
  const [dangerConfirmText, setDangerConfirmText] = useState('');
  const [dangerCountdown, setDangerCountdown] = useState(0);
  const [dangerDeleting, setDangerDeleting] = useState(false);
  const [dangerProgress, setDangerProgress] = useState<{ done: number; total: number } | null>(null);

  function showMessage(type: MessageType, text: string) {
    setMessage({ type, text });
    setTimeout(() => setMessage(null), 8000);
  }

  const pdsUrl = ((session as any)?.pdsUrl || 'https://bsky.social').replace(/\/$/, '');
  const authHeaders = (): HeadersInit => ({
    Authorization: `Bearer ${(session as any)?.accessJwt}`,
    'Content-Type': 'application/json',
  });

  /** Export full repo as CAR file directly from AT Protocol */
  const handleExportCAR = useCallback(async () => {
    if (!session) return;
    setExporting(true);
    try {
      const res = await fetch(`${pdsUrl}/xrpc/com.atproto.sync.getRepo?did=${session.did}`, {
        headers: { Authorization: `Bearer ${(session as any).accessJwt}` }
      });
      if (!res.ok) throw new Error(`Failed to download repo: ${res.status}`);
      const blob = await res.blob();
      const dateStr = new Date().toISOString().split('T')[0];
      const shortDid = session.did.replace('did:plc:', '').slice(0, 8);
      downloadBlob(blob, `bluesky-repo-${shortDid}-${dateStr}.car`);
      showMessage('success', `CAR backup downloaded (${formatBytes(blob.size)})`);
    } catch (error) {
      showMessage('error', `CAR export failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setExporting(false);
    }
  }, [session, pdsUrl]);

  /** Fetch all records from a collection with optional timeframe filter */
  const fetchRecords = async (collection: string, cutoff: Date | null): Promise<any[]> => {
    const all: any[] = [];
    let cursor: string | undefined;
    do {
      const url = new URL(`${pdsUrl}/xrpc/com.atproto.repo.listRecords`);
      url.searchParams.set('repo', session!.did);
      url.searchParams.set('collection', collection);
      url.searchParams.set('limit', '100');
      if (cursor) url.searchParams.set('cursor', cursor);

      const res = await fetch(url.toString(), { headers: authHeaders() });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();

      for (const rec of data.records || []) {
        if (cutoff) {
          const created = rec.value?.createdAt ? new Date(rec.value.createdAt) : null;
          if (created && created < cutoff) continue;
        }
        all.push(rec);
      }
      cursor = data.cursor;
    } while (cursor);
    return all;
  };

  /** Export posts as JSON */
  const handleExportJSON = useCallback(async () => {
    if (!session) return;
    setExporting(true);
    try {
      const cutoff = getTimeframeCutoff(timeframe);
      const posts = await fetchRecords('app.bsky.feed.post', cutoff);
      const likes = await fetchRecords('app.bsky.feed.like', cutoff);
      const reposts = await fetchRecords('app.bsky.feed.repost', cutoff);

      const exportData = {
        exportedAt: new Date().toISOString(),
        did: session.did,
        handle: session.handle,
        timeframe,
        posts: posts.map(r => ({ uri: r.uri, ...r.value })),
        likes: likes.map(r => ({ uri: r.uri, ...r.value })),
        reposts: reposts.map(r => ({ uri: r.uri, ...r.value })),
      };

      const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' });
      downloadBlob(blob, `bluesky-export-${new Date().toISOString().split('T')[0]}.json`);
      showMessage('success', `Exported ${posts.length} posts, ${likes.length} likes, ${reposts.length} reposts`);
    } catch (error) {
      showMessage('error', `Export failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setExporting(false);
    }
  }, [session, timeframe, pdsUrl]);

  /** Export posts as CSV */
  const handleExportCSV = useCallback(async () => {
    if (!session) return;
    setExporting(true);
    try {
      const cutoff = getTimeframeCutoff(timeframe);
      const posts = await fetchRecords('app.bsky.feed.post', cutoff);

      const headers = ['uri', 'text', 'createdAt', 'langs', 'replyTo'];
      const rows = posts.map(r => {
        const v = r.value || {};
        return [
          r.uri,
          (v.text || '').replace(/"/g, '""'),
          v.createdAt || '',
          (v.langs || []).join(';'),
          v.reply?.parent?.uri || '',
        ].map(cell => `"${cell}"`).join(',');
      });

      const csv = [headers.join(','), ...rows].join('\n');
      const blob = new Blob([csv], { type: 'text/csv' });
      downloadBlob(blob, `bluesky-posts-${new Date().toISOString().split('T')[0]}.csv`);
      showMessage('success', `Exported ${posts.length} posts as CSV`);
    } catch (error) {
      showMessage('error', `Export failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setExporting(false);
    }
  }, [session, timeframe, pdsUrl]);

  /** Start the danger zone countdown */
  const startDangerCountdown = (target: DangerTarget) => {
    setDangerTarget(target);
    setDangerConfirmText('');
    setDangerCountdown(5);
    const interval = setInterval(() => {
      setDangerCountdown(prev => {
        if (prev <= 1) { clearInterval(interval); return 0; }
        return prev - 1;
      });
    }, 1000);
  };

  /** Execute the danger zone deletion */
  const executeDangerDelete = async () => {
    if (!session || !dangerTarget) return;
    const target = DANGER_TARGETS.find(t => t.id === dangerTarget);
    if (!target) return;

    setDangerDeleting(true);
    try {
      // Fetch all records in the collection
      const records = await fetchRecords(target.collection, null);
      setDangerProgress({ done: 0, total: records.length });

      let done = 0;
      for (const rec of records) {
        const parts = rec.uri.split('/');
        const rkey = parts[parts.length - 1];
        try {
          await fetch(`${pdsUrl}/xrpc/com.atproto.repo.deleteRecord`, {
            method: 'POST',
            headers: authHeaders(),
            body: JSON.stringify({
              repo: session.did,
              collection: target.collection,
              rkey,
            }),
          });
        } catch { /* continue */ }
        done++;
        if (done % 5 === 0 || done === records.length) {
          setDangerProgress({ done, total: records.length });
        }
        // Rate limit
        await new Promise(r => setTimeout(r, 200));
      }

      showMessage('success', `Deleted ${done} ${target.label.toLowerCase()} from your Bluesky account`);
    } catch (error) {
      showMessage('error', `Deletion failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setDangerDeleting(false);
      setDangerProgress(null);
      setDangerTarget(null);
      setDangerConfirmText('');
    }
  };

  const expectedConfirm = dangerTarget ? `DELETE ALL ${dangerTarget.toUpperCase()}` : '';
  const canExecuteDanger = dangerCountdown === 0 && dangerConfirmText === expectedConfirm;

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Data Management</h1>
        <p className="text-muted-foreground mt-1">Export your Bluesky data and manage account-level operations</p>
      </div>

      {/* Message Banner */}
      {message && (
        <div className={`p-4 rounded-lg flex items-center gap-3 text-sm ${
          message.type === 'success' ? 'bg-success/10 text-success border border-success/20' :
          message.type === 'error' ? 'bg-destructive/10 text-destructive border border-destructive/20' :
          'bg-primary/10 text-primary border border-primary/20'
        }`}>
          {message.type === 'success' ? <CheckCircle className="w-4 h-4 shrink-0" /> : <AlertCircle className="w-4 h-4 shrink-0" />}
          <span>{message.text}</span>
        </div>
      )}

      {/* Export Section */}
      <section className="bg-card border border-border rounded-xl p-6">
        <h2 className="text-lg font-semibold mb-1 flex items-center gap-2">
          <Download className="w-5 h-5" />
          Export Your Data
        </h2>
        <p className="text-sm text-muted-foreground mb-5">Download your Bluesky data for backup or analysis</p>

        {/* Timeframe selector */}
        <div className="flex items-center gap-3 mb-5">
          <Calendar className="w-4 h-4 text-muted-foreground" />
          <span className="text-sm text-muted-foreground">Timeframe:</span>
          <div className="flex gap-1">
            {TIMEFRAME_OPTIONS.map(opt => (
              <button
                key={opt.value}
                type="button"
                onClick={() => setTimeframe(opt.value)}
                className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
                  timeframe === opt.value
                    ? 'bg-primary/15 text-primary border border-primary/30'
                    : 'bg-muted/50 text-muted-foreground border border-transparent hover:bg-muted'
                }`}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          {/* CAR Export — the primary export */}
          <button type="button"
            onClick={handleExportCAR}
            disabled={exporting || !session}
            className="flex flex-col items-center gap-2 p-5 rounded-lg border-2 border-primary/30 bg-primary/5 hover:bg-primary/10 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {exporting ? <Loader2 className="w-6 h-6 animate-spin" /> : <Archive className="w-6 h-6 text-primary" />}
            <span className="font-medium text-sm">Full Repo (CAR)</span>
            <span className="text-xs text-muted-foreground text-center">Complete AT Protocol backup</span>
          </button>

          <button type="button"
            onClick={handleExportJSON}
            disabled={exporting || !session}
            className="flex flex-col items-center gap-2 p-5 rounded-lg border border-border hover:bg-muted/50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {exporting ? <Loader2 className="w-6 h-6 animate-spin" /> : <FileJson className="w-6 h-6 text-muted-foreground" />}
            <span className="font-medium text-sm">JSON Export</span>
            <span className="text-xs text-muted-foreground text-center">Posts, likes, reposts as JSON</span>
          </button>

          <button type="button"
            onClick={handleExportCSV}
            disabled={exporting || !session}
            className="flex flex-col items-center gap-2 p-5 rounded-lg border border-border hover:bg-muted/50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {exporting ? <Loader2 className="w-6 h-6 animate-spin" /> : <FileSpreadsheet className="w-6 h-6 text-muted-foreground" />}
            <span className="font-medium text-sm">CSV Export</span>
            <span className="text-xs text-muted-foreground text-center">Posts in spreadsheet format</span>
          </button>
        </div>

        {timeframe !== 'all' && (
          <p className="text-xs text-muted-foreground mt-3">
            JSON and CSV exports will be filtered to the selected timeframe. CAR export always includes the full repo.
          </p>
        )}
      </section>

      {/* Danger Zone */}
      <section className="border-2 border-destructive/30 rounded-xl p-6 bg-destructive/5">
        <h2 className="text-lg font-semibold mb-1 text-destructive flex items-center gap-2">
          <ShieldAlert className="w-5 h-5" />
          Danger Zone
        </h2>
        <p className="text-sm text-destructive/70 mb-5">
          Permanently delete records from your Bluesky account. These operations use the AT Protocol API
          and <strong>cannot be undone</strong>. We recommend exporting a CAR backup first.
        </p>

        {/* Danger progress */}
        {dangerDeleting && dangerProgress && (
          <div className="mb-5 space-y-2">
            <p className="text-sm text-destructive font-medium">
              Deleting... {dangerProgress.done} / {dangerProgress.total}
            </p>
            <div className="h-2 bg-muted rounded-full overflow-hidden">
              <div
                className="h-full bg-destructive rounded-full transition-all"
                style={{ width: `${(dangerProgress.done / dangerProgress.total) * 100}%` }}
              />
            </div>
          </div>
        )}

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {DANGER_TARGETS.map(target => (
            <button
              key={target.id}
              type="button"
              onClick={() => startDangerCountdown(target.id)}
              disabled={dangerDeleting}
              className="flex items-start gap-3 p-4 rounded-lg border border-destructive/20 hover:border-destructive/50 hover:bg-destructive/10 transition-colors text-left disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Trash2 className="w-5 h-5 text-destructive flex-shrink-0 mt-0.5" />
              <div>
                <p className="font-medium text-sm text-destructive">{target.label}</p>
                <p className="text-xs text-destructive/60 mt-0.5">{target.desc}</p>
              </div>
            </button>
          ))}
        </div>
      </section>

      {/* Danger Confirmation Modal */}
      {dangerTarget && !dangerDeleting && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm" role="dialog" aria-modal="true">
          <div className="bg-card border-2 border-destructive/50 rounded-xl p-6 max-w-md w-full mx-4 shadow-2xl">
            <div className="flex items-center gap-3 mb-4">
              <ShieldAlert className="w-7 h-7 text-destructive flex-shrink-0" />
              <div>
                <h2 className="text-lg font-bold text-destructive">Confirm Permanent Deletion</h2>
                <p className="text-xs text-muted-foreground">This action is irreversible</p>
              </div>
            </div>

            <div className="bg-destructive/10 border border-destructive/20 rounded-lg p-4 mb-5">
              <p className="text-sm text-foreground">
                You are about to permanently delete <strong className="text-destructive">
                {DANGER_TARGETS.find(t => t.id === dangerTarget)?.label.toLowerCase()}
                </strong> from your Bluesky account. This uses the AT Protocol API to remove records directly
                from your Personal Data Server.
              </p>
            </div>

            <div className="space-y-3 mb-5">
              <label className="block">
                <span className="text-sm font-medium text-foreground">
                  Type <code className="px-1.5 py-0.5 bg-muted rounded text-destructive font-mono text-xs">{expectedConfirm}</code> to confirm:
                </span>
                <input
                  type="text"
                  value={dangerConfirmText}
                  onChange={e => setDangerConfirmText(e.target.value)}
                  placeholder={expectedConfirm}
                  className="mt-2 w-full px-3 py-2.5 bg-background border border-border rounded-lg text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-destructive/50 font-mono text-sm"
                  autoFocus
                />
              </label>
            </div>

            <div className="flex gap-3 justify-end">
              <button
                type="button"
                onClick={() => { setDangerTarget(null); setDangerConfirmText(''); }}
                className="px-4 py-2.5 rounded-lg border border-border hover:bg-muted transition-colors text-sm font-medium"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={executeDangerDelete}
                disabled={!canExecuteDanger}
                className="px-4 py-2.5 rounded-lg bg-destructive text-destructive-foreground hover:bg-destructive/90 transition-colors text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {dangerCountdown > 0
                  ? `Wait ${dangerCountdown}s...`
                  : `Delete ${DANGER_TARGETS.find(t => t.id === dangerTarget)?.label}`
                }
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
