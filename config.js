/* Skylines — Supabase connection.
 *
 * Fill these in with the values from your project:
 *   Supabase dashboard -> Project Settings -> API
 *
 * The anon key is a PUBLIC key and is meant to ship in the browser. It is safe
 * to commit, because every table is protected by row level security (see
 * supabase/schema.sql) — a signed-in user can only ever touch their own rows.
 * Never put the service_role key in this file.
 *
 * Leave them blank and Skylines runs fully offline, storing flights in this
 * browser only. You can also paste the values into the in-app setup screen,
 * which keeps them in localStorage instead of here.
 */
window.SKYLINES_CONFIG = {
  SUPABASE_URL: 'https://ykvjuhmoaetrbalsyukd.supabase.co',
  SUPABASE_ANON_KEY: 'sb_publishable_pbxkJ_AoFWkXePjg_osZzw_G9NFx8fi'
};
