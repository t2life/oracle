# admin_app

Next.js admin console scaffold aligned with A-01 to A-08 requirements.

## Structure

- `app/login/page.tsx`: A-01 admin authentication
- `app/dashboard/page.tsx`: A-02 KPI dashboard
- `app/themes/page.tsx`: A-03 theme management
- `app/decks/page.tsx`: A-03 deck management
- `app/cards/page.tsx`: A-03 card management
- `app/announcements/page.tsx`: A-04 announcement management
- `app/campaigns/page.tsx`: A-05 push campaign management
- `app/users/page.tsx`: A-06 user management
- `app/inquiries/page.tsx`: A-07 inquiry management
- `app/analytics/page.tsx`: A-08 analytics management
- `lib/api.ts`: backend admin API client
- `components/nav-shell.tsx`: shared admin navigation shell

## Run

```bash
npm install
npm run dev
```
