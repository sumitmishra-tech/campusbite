# Test plan

## Automated checks
- `npm test`: payment calculations and menu data checks.
- `npm run typecheck`: backend and frontend TypeScript.
- `npm run lint`: frontend ESLint.
- `npm run build`: both production builds.

## Critical scenarios

| Scenario | Expected result |
|---|---|
| Day Scholar ₹100 order | ₹10 advance, ₹90 later, zero discount |
| Verified Hosteller ₹100 order | ₹0 advance, ₹100 later |
| Discount attempt | `discount_paise=0`; database check constraint rejects nonzero |
| Invalid Razorpay signature | HTTP 400; no confirmation |
| Duplicate capture webhook | Captured transaction and confirmation not duplicated |
| Cross-student order lookup | HTTP 404 |
| Unverified Hosteller checkout/emergency | HTTP 403 |
| Blocked user checkout/emergency | HTTP 403 |
| Unavailable menu item | HTTP 409 |
| Full pickup slot | HTTP 409 |
| Cancellation after preparing | HTTP 409 |
| Owner confirms repeated misuse | Warning at configured threshold; temporary block at threshold |
| Owner unblocks student | Restriction cleared and audit entry created |

Integration tests require a separate Supabase test project and seeded auth users. Never test with production student data.
