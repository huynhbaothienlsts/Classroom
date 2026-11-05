const url = window.__LABFLOW_CONFIG__?.supabaseUrl;
const key = window.__LABFLOW_CONFIG__?.supabaseAnonKey;

export const isConfigured = Boolean(url && key && !url.includes("YOUR_PROJECT"));
export const supabase = isConfigured && window.supabase
  ? window.supabase.createClient(url, key, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
    })
  : null;

export const uid = () => crypto.randomUUID();
