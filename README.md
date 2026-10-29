# CampusBite — Fresh Food. Smarter Breaks.

A full-stack college canteen ordering project built with React + TypeScript + Vite + Tailwind, Express + TypeScript, Supabase Auth/PostgreSQL, and Razorpay test-mode integration. The frontend includes a responsive, premium canteen storefront; the backend exposes authenticated REST APIs for ordering, payments, emergency requests, administration and order tracking.

> **Payment honesty:** when `PAYMENT_MODE=simulator`, the app records a development-only simulated advance. It is not a real payment. Razorpay requires real test credentials and a configured webhook before real test-mode checkout can work.

## Features

- Responsive menu, search/category filters, cart drawer, checkout payment breakdown and student registration/login UI.
- Day Scholar: 10% advance; remaining 90% after pickup. Verified Hosteller: no advance; full amount after pickup. Discounts are always zero.
- Supabase Auth session verification, profile bootstrap, role-aware API authorization and one-time first-owner setup.
- Server-side menu pricing, item price snapshots, payment ledger, status history, cancellation reasons and audit log.
- Hosteller verification, emergency food requests, staff order lifecycle, owner menu/user/restriction controls, metrics and configurable abuse review policy.
- SQL schema and RLS, realistic menu/slot seed data, payment calculation tests and frontend data tests.

## Prerequisites

Node.js 20+ and npm; a Supabase project; optional Razorpay test account.

## Windows PowerShell setup

1. Extract the folder and open PowerShell in `campusbite`.
2. Install dependencies: `npm install`
3. Create environment config: `Copy-Item .env.example .env`
4. In Supabase SQL Editor run `database/migrations/001_initial_schema.sql`, then `database/seed.sql`.
5. In Supabase Authentication → URL Configuration add `http://localhost:5173`. Enable email confirmation for production; local demos may disable confirmation in Supabase Auth settings.
6. Copy the Supabase URL and anon key into `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `VITE_SUPABASE_URL`, and `VITE_SUPABASE_ANON_KEY`. Put the service-role key only in `SUPABASE_SERVICE_ROLE_KEY`; never put it in a `VITE_` variable.
7. Set a long random `OWNER_SETUP_SECRET`, then start both apps: `npm run dev`. Frontend: `http://localhost:5173`; health endpoint: `http://localhost:4000/api/health`.
8. Create a normal user through registration. To bootstrap the first owner, obtain that user's Supabase access token and run:

   ```powershell
   $token = "PASTE_OWNER_USER_ACCESS_TOKEN"
   Invoke-RestMethod -Method Post -Uri "http://localhost:4000/api/admin/bootstrap-owner" -Headers @{ Authorization = "Bearer $token"; "x-owner-setup-secret" = "YOUR_OWNER_SETUP_SECRET" }
   ```

   This endpoint only works if no owner exists. Rotate/remove the setup secret afterward. Owners can promote staff and verify hostellers through the protected API. Never promote every user.
9. Optional Razorpay: set `PAYMENT_MODE=razorpay`, `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, and `RAZORPAY_WEBHOOK_SECRET`; configure webhook `POST /api/payments/webhook`. Without those credentials, simulator mode is explicitly development-only.
10. Checks: `npm test`, `npm run typecheck`, `npm run lint`, `npm run build`.

## Demo account matrix

Create accounts through the normal signup flow. Bootstrap one owner, promote one account to staff, register one Day Scholar, register one Hosteller and verify them as owner, and register another Hosteller without verification. These are demo roles, not hardcoded accounts. Avoid real student data in screenshots.

## Commands

- `npm run dev` — Express and Vite
- `npm run build` — production build
- `npm test` — backend and frontend tests
- `npm run typecheck` — TypeScript checks
- `npm run lint` — frontend ESLint

## Security and known hardening tasks

This is a college-project implementation, not a compliance-certified production system. Before public deployment, add an unpaid-order expiry/release worker, compensate reservations if Razorpay order creation fails, complete automated provider-side refund initiation, add real-time order updates, and review email delivery, audit retention, monitoring and backups. Service-role credentials remain backend-only.
