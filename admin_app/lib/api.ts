export const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://127.0.0.1:8000';

type HttpMethod = 'GET' | 'POST';

type RequestOptions = {
  method?: HttpMethod;
  token?: string;
  body?: unknown;
};

async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = 'GET', token, body } = options;
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(token ? { 'X-Admin-Token': token } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
    cache: 'no-store',
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`API ${response.status}: ${detail}`);
  }

  return (await response.json()) as T;
}

export type AdminLoginResponse = {
  token: string;
  admin_user_id: string;
  role_id: string;
};

export type DashboardResponse = {
  users_total: number;
  inquiries_total: number;
  announcements_total: number;
  campaigns_total: number;
  reading_completed: number;
  ticket_purchased: number;
  subscription_started: number;
  updated_at: string;
};

export type UserSummary = {
  user_id: string;
  plan: string;
  tickets: number;
  created_at: string;
};

export type InquirySummary = {
  inquiry_id: string;
  user_id: string;
  category: string;
  body: string;
  email: string | null;
  created_at: string;
};

export type Announcement = {
  announcement_id: string;
  title: string;
  body: string;
  category: string;
  start_at: string;
  end_at: string;
  is_important: boolean;
  link_url: string | null;
};

export type Campaign = {
  campaign_id: string;
  title: string;
  body: string;
  category: string;
  target_segment: string;
  scheduled_at: string;
  created_at: string;
  status: string;
  is_ab_test: boolean;
};

export type ThemeAdmin = {
  theme_id: string;
  name_ja: string;
  is_visible: boolean;
};

export type DeckAdmin = {
  deck_id: string;
  name_ja: string;
  sort_order: number;
  is_published: boolean;
};

export type Card = {
  card_id: string;
  deck_id: string;
  name_ja: string;
  keywords: string[];
};

export type KpiResponse = {
  values: Record<string, number>;
};

export async function adminLogin(email: string, password: string) {
  return request<AdminLoginResponse>('/admin/login', {
    method: 'POST',
    body: { email, password },
  });
}

export async function fetchDashboard(token: string) {
  return request<DashboardResponse>('/admin/dashboard', { token });
}

export async function fetchUsers(token: string) {
  return request<UserSummary[]>('/admin/users', { token });
}

export async function fetchInquiries(token: string) {
  return request<InquirySummary[]>('/admin/inquiries', { token });
}

export async function fetchAnnouncements(token: string) {
  return request<Announcement[]>('/admin/announcements', { token });
}

export async function createAnnouncement(token: string, payload: Omit<Announcement, 'announcement_id'>) {
  return request<Announcement>('/admin/announcements', {
    method: 'POST',
    token,
    body: payload,
  });
}

export async function fetchCampaigns(token: string) {
  return request<Campaign[]>('/admin/campaigns', { token });
}

export async function createCampaign(token: string, payload: Omit<Campaign, 'campaign_id' | 'created_at' | 'status'>) {
  return request<Campaign>('/admin/campaigns', {
    method: 'POST',
    token,
    body: payload,
  });
}

export async function dispatchCampaign(token: string, campaignId: string) {
  return request<Campaign>(`/admin/campaigns/${campaignId}/dispatch`, {
    method: 'POST',
    token,
  });
}

export async function fetchThemes(token: string) {
  return request<ThemeAdmin[]>('/admin/themes', { token });
}

export async function fetchDecks(token: string) {
  return request<DeckAdmin[]>('/admin/decks', { token });
}

export async function fetchCards(deckId?: string) {
  const query = deckId ? `?deck_id=${encodeURIComponent(deckId)}` : '';
  return request<Card[]>(`/cards${query}`);
}

export async function fetchKpi(token: string) {
  return request<KpiResponse>('/admin/analytics/kpi', { token });
}
