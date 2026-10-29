# REST API

Base URL: `http://localhost:4000/api`. Protected endpoints accept `Authorization: Bearer <Supabase access token>`. JSON errors are `{ "error": "..." }`.

| Method | Path | Access | Purpose |
|---|---|---|---|
| GET | `/health` | Public | Service/config status |
| GET | `/menu` | Public | Menu list |
| GET/POST | `/profile` | Signed-in | Read/update safe profile fields |
| POST | `/orders` | Unblocked student | Server-priced checkout |
| GET | `/orders` | Signed-in | Own orders for students, all for staff/owner |
| GET | `/orders/:id` | Signed-in | Own order or staff order |
| POST | `/orders/:id/cancel` | Unblocked student | Cancel with reason when eligible |
| POST | `/payments/verify` | Order owner | Razorpay signature verification |
| POST | `/payments/simulate` | Unblocked student | Development-only simulated advance |
| POST | `/payments/webhook` | Razorpay signature | Capture/refund webhook handler |
| GET | `/pickup-slots` | Public | Active slots with availability |
| POST | `/emergency-requests` | Verified Hosteller | Request urgent food, not guaranteed immediate service |
| GET/PATCH | `/emergency-requests` | Staff/owner | List/update emergency requests |
| GET | `/admin/metrics` | Owner | Revenue, collected/outstanding, popular items |
| GET/PATCH | `/admin/users` | Owner | User management and hosteller verification |
| POST | `/admin/bootstrap-owner` | Setup secret + signed-in user | First owner only |
| GET/POST/PATCH | `/admin/pickup-slots` | Owner | Manage slot times, capacity and availability |
| GET | `/admin/settings` | Owner | Read policy settings |
| PATCH | `/admin/settings/anti-prank-policy` | Owner | Configure warning/block thresholds and duration |
| GET/POST/PATCH | `/admin/menu` | Owner | Menu management |
| GET/PATCH | `/admin/orders` | Staff/owner | Incoming orders and lifecycle updates |
| GET | `/admin/cancellations` | Owner | Cancellation review |
| POST | `/admin/orders/:id/flag-uncollected` | Owner | Record an uncollected order for misuse review |
| POST | `/admin/cancellations/:id/confirm-misuse` | Owner | Apply configured warning/block thresholds |
| POST | `/admin/users/:id/unblock` | Owner | Unblock a user |

Day Scholars require 10% advance; order stays pending until verified capture or simulator success. Verified Hostellers have zero advance and owe the full amount at pickup. Browser totals and roles are never trusted. Razorpay signature is verified server-side and final order confirmation waits for a signed capture webhook. Simulator records are explicitly marked development-only.
