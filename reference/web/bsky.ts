/** Shared Bluesky types for server and client */

export interface BskyProfile {
  did: string;
  handle: string;
  displayName?: string;
  description?: string;
  avatar?: string;
  banner?: string;
  followersCount: number;
  followsCount: number;
  postsCount: number;
  createdAt: string;
  labels?: Array<{ val: string }>;
  viewer?: {
    muted?: boolean;
    blockedBy?: boolean;
    blocking?: string;
    following?: string;
    followedBy?: string;
  };
}

export interface AnalyzedAccount extends BskyProfile {
  ratio: number;
  botScore: number;
  botFlags: string[];
  influenceScore: number;
  influenceTier: "mega" | "macro" | "micro" | "nano";
  accountAgeDays: number;
  postsPerDay: number;
  profileCompleteness: number;
  lastPostDate: string | null;
  daysSinceLastPost: number | null;
  isInactive: boolean;
  isDeleted: boolean;
  isMutual: boolean;
  engagementScore: number;
  interactedRecently: boolean | null;
}

export interface ScanProgress {
  phase: "fetching" | "analyzing" | "engagement" | "complete" | "error";
  current: number;
  total: number;
  message: string;
}

export interface ScanSummary {
  totalAnalyzed: number;
  badRatio: number;
  inactive: number;
  deleted: number;
  bots: number;
  disengaged: number;
  mutuals: number;
  avgBotScore: number;
  avgInfluenceScore: number;
}

export type SortField =
  | "handle"
  | "ratio"
  | "botScore"
  | "influenceScore"
  | "followersCount"
  | "followsCount"
  | "postsCount"
  | "accountAgeDays"
  | "postsPerDay"
  | "lastPostDate"
  | "engagementScore"
  | "profileCompleteness";

export type SortDirection = "asc" | "desc";

export interface FilterState {
  search: string;
  showBadRatio: boolean;
  showInactive: boolean;
  showDeleted: boolean;
  showBots: boolean;
  showDisengaged: boolean;
  showMutualOnly: boolean;
  showNonMutualOnly: boolean;
  showMuted: boolean;
  showBlocked: boolean;
  minFollowers: number | null;
  maxFollowers: number | null;
  minFollowing: number | null;
  maxFollowing: number | null;
  minBotScore: number | null;
  maxBotScore: number | null;
  minAccountAgeDays: number | null;
  maxAccountAgeDays: number | null;
  minPostsPerDay: number | null;
  maxPostsPerDay: number | null;
  minProfileCompleteness: number | null;
  hasAvatar: boolean | null;
  hasDescription: boolean | null;
  hasBanner: boolean | null;
  influenceTier: string | null;
  hasLabels: boolean | null;
  sortField: SortField;
  sortDirection: SortDirection;
}

export const DEFAULT_FILTERS: FilterState = {
  search: "",
  showBadRatio: false,
  showInactive: false,
  showDeleted: false,
  showBots: false,
  showDisengaged: false,
  showMutualOnly: false,
  showNonMutualOnly: false,
  showMuted: false,
  showBlocked: false,
  minFollowers: null,
  maxFollowers: null,
  minFollowing: null,
  maxFollowing: null,
  minBotScore: null,
  maxBotScore: null,
  minAccountAgeDays: null,
  maxAccountAgeDays: null,
  minPostsPerDay: null,
  maxPostsPerDay: null,
  minProfileCompleteness: null,
  hasAvatar: null,
  hasDescription: null,
  hasBanner: null,
  influenceTier: null,
  hasLabels: null,
  sortField: "botScore",
  sortDirection: "desc",
};
