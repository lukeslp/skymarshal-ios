/**
 * Cleanup — follower management and network intelligence.
 * Runs the analysis engine client-side; fetches follows directly via xrpc.
 */
import { useState, useMemo, useCallback } from "react";
import { useAuth } from "../components/auth/AuthProvider";
import { useDocumentTitle } from "../hooks/useDocumentTitle";
import {
  AccountCard,
  FilterPanel,
  BulkSelectBar,
  ScanSummaryBar,
  UnfollowDialog,
} from "../components/bluescreen";
import { useScan } from "../lib/bluescreen/useScan";
import { applyFilters, exportToCSV, downloadFile } from "../lib/bluescreen/filters";
import { computeSummary } from "../lib/bluescreen/analyzer";
import { DEFAULT_FILTERS } from "../lib/bluescreen/types";
import type { AnalyzedAccount, FilterState, ScanSummary } from "../lib/bluescreen/types";
import {
  Scan,
  Loader2,
  Download,
  Users,
  ChevronDown,
  Sparkles,
  Settings2,
} from "lucide-react";

// Scan options persisted to localStorage
const SCAN_OPTIONS_KEY = 'skymarshal:scan-options';
function loadScanOptions() {
  try {
    const raw = localStorage.getItem(SCAN_OPTIONS_KEY);
    if (raw) return JSON.parse(raw);
  } catch { /* ignore */ }
  return { checkEngagement: true, inactivityDays: 90, batchSize: 10 };
}
function saveScanOptions(opts: { checkEngagement: boolean; inactivityDays: number; batchSize: number }) {
  try { localStorage.setItem(SCAN_OPTIONS_KEY, JSON.stringify(opts)); } catch { /* ignore */ }
}

const PAGE_SIZE = 50;

export default function Cleanup() {
  useDocumentTitle('Cleanup');
  const { session } = useAuth();

  // Scan results
  const [accounts, setAccounts] = useState<AnalyzedAccount[]>([]);
  const [summary, setSummary] = useState<ScanSummary | null>(null);
  const [followingCount, setFollowingCount] = useState(0);

  // Filters + selection
  const [filters, setFilters] = useState<FilterState>(DEFAULT_FILTERS);
  const [selectedDids, setSelectedDids] = useState<Set<string>>(new Set());
  const [unfollowOpen, setUnfollowOpen] = useState(false);
  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE);
  const [exportOpen, setExportOpen] = useState(false);

  // Scan options
  const [scanOptions, setScanOptions] = useState(() => loadScanOptions());
  const [showOptions, setShowOptions] = useState(false);

  const updateScanOption = <K extends keyof typeof scanOptions>(key: K, value: typeof scanOptions[K]) => {
    const updated = { ...scanOptions, [key]: value };
    setScanOptions(updated);
    saveScanOptions(updated);
  };

  // Scan hook
  const { progress, scanning, startScan } = useScan(({ accounts: scanned, summary: sum, followingCount: fc }) => {
    setAccounts(scanned);
    setSummary(sum);
    setFollowingCount(fc);
    setSelectedDids(new Set());
    setVisibleCount(PAGE_SIZE);
  });

  // Filtered + visible slices
  const filtered = useMemo(() => applyFilters(accounts, filters), [accounts, filters]);
  const visible = useMemo(() => filtered.slice(0, visibleCount), [filtered, visibleCount]);

  const selectedAccounts = useMemo(
    () => accounts.filter((a) => selectedDids.has(a.did)),
    [accounts, selectedDids]
  );

  const toggleSelect = useCallback((did: string) => {
    setSelectedDids((prev) => {
      const next = new Set(prev);
      if (next.has(did)) next.delete(did);
      else next.add(did);
      return next;
    });
  }, []);

  const loadMore = useCallback(() => {
    setVisibleCount((v) => Math.min(v + PAGE_SIZE, filtered.length));
  }, [filtered.length]);

  const handleUnfollowComplete = (unfollowedDids: string[]) => {
    const removedSet = new Set(unfollowedDids);
    const remaining = accounts.filter((a) => !removedSet.has(a.did));
    setAccounts(remaining);
    setSelectedDids(new Set());
    setSummary(computeSummary(remaining));
    setFollowingCount((prev) => Math.max(0, prev - unfollowedDids.length));
  };

  const handleExportCSV = (data: AnalyzedAccount[], label: string) => {
    downloadFile(exportToCSV(data), `cleanup-${label}-${Date.now()}.csv`, "text/csv");
    setExportOpen(false);
  };

  const handleExportJSON = (data: AnalyzedAccount[], label: string) => {
    downloadFile(
      JSON.stringify(data, null, 2),
      `cleanup-${label}-${Date.now()}.json`,
      "application/json"
    );
    setExportOpen(false);
  };

  if (!session) {
    return (
      <div className="max-w-4xl mx-auto p-8">
        <div className="bg-warning/10 border border-yellow-200 rounded-lg p-6">
          <p className="text-warning">Please log in to use the cleanup tool.</p>
        </div>
      </div>
    );
  }

  const scanProgressPct =
    progress && progress.total > 0
      ? Math.round((progress.current / progress.total) * 100)
      : 0;

  return (
    <div className="max-w-4xl mx-auto px-4 py-6 space-y-6">
      {/* Page header */}
      <div className="flex items-center gap-3">
        <Sparkles size={28} className="text-primary shrink-0" />
        <div>
          <h1 className="text-2xl font-bold text-foreground">Follower Cleanup</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Analyze who you follow — detect bots, inactive accounts, bad ratios, and disengaged users.
            Manage your following list to keep your network healthy.
          </p>
        </div>
      </div>

      {/* Scan controls */}
      <div className="bg-background rounded-xl border border-border p-5 space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center gap-4">
          <div className="flex-1 space-y-0.5">
            <h2 className="font-semibold text-base text-foreground">Network Scan</h2>
            <p className="text-xs text-muted-foreground">
              Fetches everyone you follow and scores each account locally.
              Large networks may take a minute.
            </p>
          </div>

          <button type="button"
            onClick={() => startScan(scanOptions)}
            disabled={scanning}
            className="flex items-center gap-2 px-5 py-2.5 bg-primary text-primary-foreground text-sm font-medium rounded-lg hover:bg-primary/70 disabled:opacity-60 disabled:cursor-not-allowed transition-colors shrink-0"
          >
            {scanning ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" aria-hidden="true" />
                Scanning…
              </>
            ) : (
              <>
                <Scan className="w-4 h-4" />
                {accounts.length > 0 ? "Re-scan" : "Start Scan"}
              </>
            )}
          </button>
        </div>

        {/* Scan options panel */}
        <div>
          <button
            type="button"
            onClick={() => setShowOptions((v) => !v)}
            className="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors"
            aria-expanded={showOptions}
          >
            <Settings2 size={13} />
            Scan options
            <ChevronDown size={13} className={`transition-transform ${showOptions ? 'rotate-180' : ''}`} />
          </button>
          {showOptions && (
            <div className="mt-3 grid grid-cols-1 sm:grid-cols-3 gap-4 p-4 bg-muted/30 rounded-lg border border-border">
              {/* Engagement check toggle */}
              <div className="space-y-1">
                <label className="text-xs font-medium text-foreground flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={scanOptions.checkEngagement}
                    onChange={(e) => updateScanOption('checkEngagement', e.target.checked)}
                    className="rounded border-border"
                  />
                  Check engagement
                </label>
                <p className="text-xs text-muted-foreground pl-5">
                  Detect accounts that never interact with your posts (slower scan)
                </p>
              </div>
              {/* Inactivity threshold */}
              <div className="space-y-1">
                <label htmlFor="inactivity-days" className="text-xs font-medium text-foreground">
                  Inactivity threshold
                </label>
                <div className="flex items-center gap-2">
                  <input
                    id="inactivity-days"
                    type="number"
                    min={7}
                    max={365}
                    value={scanOptions.inactivityDays}
                    onChange={(e) => updateScanOption('inactivityDays', Math.max(7, Math.min(365, Number(e.target.value))))}
                    className="w-20 px-2 py-1 text-xs bg-background text-foreground border border-border rounded focus:outline-none focus:ring-1 focus:ring-primary/50"
                  />
                  <span className="text-xs text-muted-foreground">days</span>
                </div>
                <p className="text-xs text-muted-foreground">Mark as inactive if no posts in this many days</p>
              </div>
              {/* Batch size */}
              <div className="space-y-1">
                <label htmlFor="batch-size" className="text-xs font-medium text-foreground">
                  Batch size
                </label>
                <select
                  id="batch-size"
                  value={scanOptions.batchSize}
                  onChange={(e) => updateScanOption('batchSize', Number(e.target.value))}
                  className="w-full px-2 py-1 text-xs bg-background text-foreground border border-border rounded focus:outline-none focus:ring-1 focus:ring-primary/50"
                >
                  <option value={5}>5 — slower, less rate limiting</option>
                  <option value={10}>10 — balanced (default)</option>
                  <option value={25}>25 — faster, may hit limits</option>
                </select>
                <p className="text-xs text-muted-foreground">Profiles fetched per API request</p>
              </div>
            </div>
          )}
        </div>

        {/* Progress bar */}
        {scanning && progress && (
          <div className="space-y-1.5">
            <div className="w-full bg-muted rounded-full h-1.5">
              <div
                className="bg-primary h-1.5 rounded-full transition-all duration-300"
                style={{
                  width: `${
                    progress.phase === "fetching"
                      ? Math.min(scanProgressPct, 50)
                      : 50 + Math.min(scanProgressPct / 2, 50)
                  }%`,
                }}
              />
            </div>
            <p className="text-xs text-muted-foreground">{progress.message}</p>
          </div>
        )}

        {/* Error */}
        {progress?.phase === "error" && (
          <p className="text-sm text-destructive bg-destructive/10 rounded-lg px-3 py-2">
            {progress.message}
          </p>
        )}
      </div>

      {/* Results */}
      {accounts.length > 0 && summary && (
        <>
          {/* Summary bar */}
          <ScanSummaryBar summary={summary} followingCount={followingCount} />

          {/* Action bar */}
          <div className="flex items-center gap-2 flex-wrap">
            <BulkSelectBar
              allAccounts={accounts}
              filteredAccounts={filtered}
              selectedDids={selectedDids}
              onSelectionChange={setSelectedDids}
              onUnfollow={() => setUnfollowOpen(true)}
            />

            <div className="flex-1" />

            {/* Export dropdown */}
            <div className="relative">
              <button type="button"
                onClick={() => setExportOpen((v) => !v)}
                className="flex items-center gap-1.5 px-3 py-1.5 text-xs border border-border rounded-lg bg-background hover:bg-muted/50 transition-colors"
              >
                <Download className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Export</span>
                <ChevronDown className="w-3 h-3" />
              </button>

              {exportOpen && (
                <>
                  <div
                    className="fixed inset-0 z-10"
                    onClick={() => setExportOpen(false)}
                  />
                  <div className="absolute right-0 top-full mt-1 w-52 bg-background border border-border rounded-lg shadow-lg z-20 py-1">
                    <ExportItem
                      label="Export filtered as CSV"
                      onClick={() =>
                        handleExportCSV(
                          filtered.length > 0 ? filtered : accounts,
                          "filtered"
                        )
                      }
                    />
                    <ExportItem
                      label="Export filtered as JSON"
                      onClick={() =>
                        handleExportJSON(
                          filtered.length > 0 ? filtered : accounts,
                          "filtered"
                        )
                      }
                    />
                    <div className="border-t border-border my-1" />
                    <ExportItem
                      label="Export all as CSV"
                      onClick={() => handleExportCSV(accounts, "all")}
                    />
                    <ExportItem
                      label="Export all as JSON"
                      onClick={() => handleExportJSON(accounts, "all")}
                    />
                  </div>
                </>
              )}
            </div>
          </div>

          {/* Filter panel */}
          <FilterPanel
            filters={filters}
            onChange={setFilters}
            resultCount={filtered.length}
            totalCount={accounts.length}
          />

          <hr className="border-border" />

          {/* Account list */}
          <div className="space-y-2">
            {visible.map((account) => (
              <AccountCard
                key={account.did}
                account={account}
                selected={selectedDids.has(account.did)}
                onToggle={toggleSelect}
              />
            ))}

            {visible.length === 0 && (
              <div className="text-center py-12 text-muted-foreground">
                <Users className="w-8 h-8 mx-auto mb-3 opacity-30" />
                <p className="text-sm">No accounts match your current filters.</p>
                <button type="button"
                  className="mt-2 text-sm text-primary hover:underline"
                  onClick={() => setFilters(DEFAULT_FILTERS)}
                >
                  Reset filters
                </button>
              </div>
            )}

            {visibleCount < filtered.length && (
              <div className="flex justify-center pt-4">
                <button type="button"
                  onClick={loadMore}
                  className="px-5 py-2 border border-border text-sm rounded-lg hover:bg-muted/50 transition-colors"
                >
                  Load more ({filtered.length - visibleCount} remaining)
                </button>
              </div>
            )}
          </div>
        </>
      )}

      {/* Empty state before first scan */}
      {accounts.length === 0 && !scanning && (
        <div className="text-center py-16 text-muted-foreground">
          <Scan className="w-12 h-12 mx-auto mb-4 opacity-30" />
          <p className="text-sm">Run a scan to analyze your following list.</p>
        </div>
      )}

      {/* Unfollow dialog */}
      <UnfollowDialog
        open={unfollowOpen}
        onOpenChange={setUnfollowOpen}
        accounts={selectedAccounts}
        onComplete={handleUnfollowComplete}
      />
    </div>
  );
}

function ExportItem({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <button type="button"
      onClick={onClick}
      className="w-full text-left px-3 py-2 text-xs hover:bg-muted/50 transition-colors"
    >
      {label}
    </button>
  );
}
