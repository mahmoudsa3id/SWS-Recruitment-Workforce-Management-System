# SWS Professional UI Refresh

- Arabic-first RTL layout with a dark evergreen, warm cream, and muted gold palette.
- Shared Material 3 theme for forms, dialogs, cards, navigation, data tables, buttons, and feedback.
- Branded responsive admin sidebar on wide screens; mobile bottom navigation is preserved.
- Login page has a responsive desktop split layout and a compact mobile layout.
- Cairo was requested, but the original archive did not contain the Cairo font and this build environment could not fetch external font binaries. The bundled Noto Sans Arabic remains the default offline font; Noto Kufi Arabic is added as a secondary Arabic family when available in the environment. Replace/register the actual licensed Cairo TTF under `assets/fonts/` to use Cairo exactly.
- Business logic, Cubit/Repository wiring, Supabase configuration, and accounting workflows were intentionally not rewritten as part of this UI pass.


## Dashboard analytics addition

- All-time traveler agreement total, total collected, and outstanding balance for active (non-archived) travelers are computed server-side from `travelers.agreement_total` and posted traveler collection movements.
- Per-traveler outstanding is clamped at zero before aggregation, so an overpayment on one record cannot incorrectly offset another traveler's debt.
- Adds paid/balance traveler counts, stage distribution, and six-month cash inflow/outflow series.
- Run `supabase/migrations/202610190001_sws_dashboard_analytics.sql` on an existing database. It replaces only the dashboard summary RPC and does not modify business rows.
