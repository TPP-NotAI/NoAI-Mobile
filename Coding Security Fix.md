# Security Checklist

### 1. Update Your Dependencies
- **The Problem:** AI might scaffold with packages from 2022. Old versions = known exploits.
- **The Fix:** After building, run `npm audit fix` and ask AI: "Are there breaking changes in the latest versions I should know about?"
- **Why it matters:** 80% of breaches exploit known vulnerabilities in old packages.
- **Status:** ⚠️ PARTIAL — pubspec.lock present with pinned versions; supabase_flutter v2.5.0 (2024). Run `flutter pub outdated` before each release to catch CVEs.

---

### 2. Never Show Raw Errors
- **The Problem:** When something breaks, AI often returns the full stack trace to the user. This tells hackers your file structure.
- **The Fix:** Prompt: "Catch all errors and return generic messages to users. Log detailed errors server-side only"
- **Why it matters:** Stack traces reveal your tech stack and file paths to attackers.
- **Status:** ✅ DONE — Zero raw `$e` in any user-facing SnackBar across entire codebase. All errors show generic messages; raw exceptions logged via `debugPrint` only (stripped in release builds).

---

### 3. Always Verify Webhooks
- **The Problem:** If you accept Stripe/payment webhooks, anyone can POST fake data to that endpoint.
- **The Fix:** Explicitly tell AI: "Verify the webhook signature using Stripe's SDK before processing any payment data"
- **Why it matters:** Unverified webhooks = fake "payment succeeded" messages.
- **Status:** ✅ DONE — Didit KYC webhook uses HMAC-SHA256 signature + timestamp (300s window). `notify-dm` DB webhook secured with shared `WEBHOOK_SECRET` header check.

---

### 4. Remove Debug Statements
- **The Problem:** AI loves to add `console.log(userData)` to help you debug. That data shows up in production browser consoles.
- **The Fix:** Before deploying, run: "Remove all console.log statements and replace with proper error logging"
- **Why it matters:** Sensitive data in console = anyone with DevTools can see it.
- **Status:** ✅ DONE — No `print()` in lib/. Only `debugPrint()` used (stripped in release builds). No PII, passwords, or keys in log messages.

---

### 5. Lock Down Your Storage
- **The Problem:** When you vibe code file uploads, the AI often makes the entire bucket public by default.
- **The Fix:** In Supabase Storage, set RLS policies. Prompt: "Create storage policies so users can only access files they uploaded"
- **Why it matters:** One public bucket = all user files exposed to Google search.
- **Status:** ⚠️ PARTIAL — Supabase defaults to private buckets; app uses `getPublicUrl()` for user-accessible media (correct pattern). RLS policies on storage buckets must be verified and set in the Supabase dashboard.

---

### 6. Check Permissions Server-Side
- **The Problem:** Hiding a "Delete All" button in the UI doesn't stop someone from calling the API directly.
- **The Fix:** Every protected route needs: "Check if user.role === 'admin' on the server before executing"
- **Why it matters:** UI security = no security. Anyone can call your APIs with curl.
- **Status:** ✅ DONE — All edge functions validate Supabase JWT before processing (`roocoin-proxy`, `user-data-export`, `didit`, `notify-wallet`). Supabase RLS enforces row-level authorization server-side (verify policies in dashboard).

---

### 7. Don't Leave CORS Wide Open
- **The Problem:** AI often sets CORS to `*` (allow all domains). Hackers can call your API from their malicious site.
- **The Fix:** Tell the AI: "Configure CORS to only allow requests from my production domain: myapp.com"
- **Why it matters:** Open CORS = Anyone can steal your user's data through their browser.
- **Status:** ✅ DONE — All edge functions now use `ALLOWED_ORIGIN` env var (defaults to `https://rooverse.app`) instead of `*`. Set `ALLOWED_ORIGIN` in Supabase dashboard → Edge Functions → Secrets.

---

### 8. Validate Your Redirects
- **The Problem:** If your login page has `?redirect=/dashboard`, attackers can change it to `?redirect=evil.com/phishing`
- **The Fix:** Ask: "Ensure all redirect URLs are validated against an allowlist before redirecting the user"
- **Why it matters:** Open redirects are the #1 way users get phished after logging in.
- **Status:** 📱 N/A — Native Flutter app uses GoRouter for internal navigation; no URL query parameter redirects. Deep links (Didit callback) use `rooverse://` scheme validated by SDK, not user-controlled input.

---

### 9. Set Session Expiration
- **The Problem:** Default AI auth often keeps users logged in forever. Stolen cookies = permanent access.
- **The Fix:** Tell AI: "Set JWT expiration to 7 days and implement refresh token rotation"
- **Why it matters:** Permanent sessions = one stolen cookie = forever access.
- **Status:** ✅ DONE — 30-minute inactivity auto-logout implemented (AuthProvider + Listener in main.dart). Supabase JWT expiry and refresh token rotation handled by Supabase Auth. "Sign Out All Other Sessions" available in security screen.

---

### 10. Add Rate Limit Reset Requests
- **The Problem:** Attackers spam the "forgot password" endpoint to flood someone's email or guess tokens.
- **The Fix:** "Add rate limiting to the password reset route: max 3 requests per email per hour"
- **Why it matters:** Unlimited resets = email bombing and token brute-forcing.
- **Status:** ⚠️ PARTIAL — Supabase Auth enforces server-side rate limiting on password reset (5 req/hour/email). App surfaces "too many requests" errors. No additional app-level counter (Supabase's limit is sufficient).

---

### 11. Sanitize User Input Everywhere
- **The Problem:** AI often trusts user input blindly, leading to XSS (Cross-Site Scripting) or SQL injection.
- **The Fix:** "Sanitize and escape all user input before displaying it in HTML or using it in database queries"
- **Why it matters:** One unsanitized comment field = hackers can steal cookies or drop malicious scripts.
- **Status:** ✅ DONE — `validators.dart` enforces email, password (8 chars + complexity), name, and phone regex. Supabase ORM parameterises all queries. Flutter renders text as plain text (no HTML execution risk in native app).

---

### 12. Use Prepared Statements for Databases
- **The Problem:** AI might concatenate strings directly into SQL queries, creating injection holes.
- **The Fix:** "Always use parameterized queries or prepared statements for database operations"
- **Why it matters:** String concatenation = attackers can drop your tables with `'; DROP TABLE users; --`
- **Status:** ✅ DONE — All DB queries use Supabase's parameterized ORM (`.from().select().eq()`). No raw SQL string concatenation in the codebase.

---

### 13. Implement CSRF Protection
- **The Problem:** If you're using cookies for auth, AI often forgets to protect against Cross-Site Request Forgery.
- **The Fix:** "Add CSRF tokens to all state-changing forms and API endpoints"
- **Why it matters:** Without CSRF, attackers can trick logged-in users into changing their email/password on your site.
- **Status:** 📱 N/A — Native mobile app uses JWT Bearer tokens (not cookies). CSRF is a cookie-session web vulnerability; not applicable here.

---

### 14. Hash Passwords Properly
- **The Problem:** AI might store passwords in plain text or use weak hashing like MD5 or SHA1.
- **The Fix:** "Use bcrypt or argon2 with a cost factor of 12+ to hash passwords before storing"
- **Why it matters:** If your DB leaks, weak hashes get cracked in hours, exposing user passwords everywhere.
- **Status:** ✅ DONE — Supabase Auth uses bcrypt server-side. App never handles raw passwords beyond the sign-in call. No custom password hashing in codebase.

---

### 15. Set Secure Cookie Flags
- **The Problem:** AI-generated auth cookies often lack security flags, making them stealable.
- **The Fix:** "Set HttpOnly, Secure, and SameSite=Strict flags on all session cookies"
- **Why it matters:** Missing flags = JavaScript can read cookies (XSS) or they travel over HTTP (network sniffing).
- **Status:** 📱 N/A — Native mobile app uses JWT tokens in Authorization headers, not cookies.

---

### 16. Validate File Uploads Thoroughly
- **The Problem:** AI often only checks file extensions, letting attackers upload PHP/JS files disguised as images.
- **The Fix:** "Validate file types by MIME type, scan contents, and store files outside the web root"
- **Why it matters:** A single uploaded webshell = full server compromise.
- **Status:** ⚠️ PARTIAL — Extension allowlist enforced (`jpg/png/gif/bmp/mp4/mov/avi/webm/mkv`). Size limits enforced (images ≤ 10 MB, videos ≤ 100 MB). MIME type verification and content scanning not implemented (low risk for Supabase storage which doesn't execute files).

---

### 17. Implement Account Lockout
- **The Problem:** AI auth usually has no protection against brute force login attempts.
- **The Fix:** "Lock accounts for 15 minutes after 5 failed login attempts"
- **Why it matters:** No lockout = attackers can try thousands of passwords until one works.
- **Status:** ⚠️ PARTIAL — Supabase Auth enforces server-side rate limiting. App detects and surfaces "too many requests" errors. No client-side lockout counter (Supabase's server enforcement is the right layer for this).

---

### 18. Add Security Headers
- **The Problem:** AI never adds security headers to your responses.
- **The Fix:** "Add Helmet.js or configure CSP, X-Frame-Options, and HSTS headers"
- **Why it matters:** Missing headers = your site can be iframed for clickjacking or MIME-sniffed for attacks.
- **Status:** ✅ DONE — All edge functions now return `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, and `Strict-Transport-Security: max-age=31536000; includeSubDomains`.

---

### 19. Rotate API Keys and Secrets
- **The Problem:** AI often hardcodes API keys or suggests storing them in plain config files.
- **The Fix:** "Use environment variables for secrets and implement key rotation every 90 days"
- **Why it matters:** Hardcoded keys in GitHub = bots scanning for Stripe/AWS keys within minutes.
- **Status:** ⚠️ PARTIAL — `ROOCOIN_API_KEY` moved to server-side edge function secret (no longer in client binary). Supabase anon key in `.env` asset is acceptable (public by design). Firebase config keys in asset (standard practice). Establish a 90-day key rotation schedule for `ROOCOIN_API_KEY` and `FCM_SERVER_KEY`.

---

### 20. Don't Expose Internal IDs
- **The Problem:** AI uses sequential IDs in URLs (`/user/123`), letting anyone iterate through all users.
- **The Fix:** "Use UUIDs instead of sequential integers for resource identifiers"
- **Why it matters:** Sequential IDs = competitors can see exactly how many users/customers you have.
- **Status:** ✅ DONE — All DB tables use `gen_random_uuid()` UUIDs for primary keys (users, posts, comments, wallets, etc.). No sequential integer IDs exposed.

---

### 21. Implement Proper Logging
- **The Problem:** AI logs everything (including passwords and credit cards) to "debug" files.
- **The Fix:** "Log authentication attempts and errors, but never log PII, passwords, or payment data"
- **Why it matters:** Logs full of PII become a compliance nightmare and a target for attackers.
- **Status:** ✅ DONE — `ActivityLogService` logs `activity_type`, `description`, metadata only (no PII/passwords). Wallet operations log amounts and types, not private keys. Edge functions log errors without sensitive data.

---

### 22. Add Security Questions Carefully
- **The Problem:** AI might add "What's your mother's maiden name?" which is easily guessable.
- **The Fix:** "If using security questions, ensure answers are hashed and questions aren't publicly discoverable"
- **Why it matters:** Most answers (pet names, schools) are on social media = easy account takeover.
- **Status:** 📱 N/A — No security questions implemented. Password reset uses Supabase email OTP (secure token, expiring, one-time use).

---

### 23. Set Up Monitoring and Alerts
- **The Problem:** AI builds the app but forgets to tell you when it's under attack.
- **The Fix:** "Add simple monitoring for failed logins, unusual traffic, and database changes"
- **Why it matters:** You can't stop what you can't see. Early detection limits damage.
- **Status:** ⚠️ PARTIAL — `ActivityLogService` + `audit_logs` table records security events (login, password change, wallet actions, data export). No real-time alerting or anomaly detection pipeline. Consider adding Supabase Logflare alerts or a monitoring webhook.

---

### 24. Create a Data Backup Strategy
- **The Problem:** AI assumes nothing will ever break or get deleted.
- **The Fix:** "Implement automated daily backups with 30-day retention and test restores monthly"
- **Why it matters:** Ransomware or accidental deletion = business over without backups.
- **Status:** ⏳ DEFERRED — Supabase managed service provides automated backups (Pro plan). No explicit backup configuration, retention policy, or documented restore procedure in the codebase. Configure and document in Supabase dashboard.

---

====================================================

## Quick Audit Checklist

### By Category

**Dependencies**
- ⚠️ Run `flutter pub outdated` before each release — check for CVEs

**Error Handling**
- ✅ Stack traces hidden from users — all errors are generic messages

**Authentication**
- ✅ Sessions expire (30-min idle timeout + Supabase JWT expiry)
- ✅ MFA available (email OTP 2FA)
- ✅ Re-auth required for password change, wallet send, account deletion

**Authorization**
- ✅ Permissions checked server-side (JWT validation in all edge functions)
- ⚠️ Confirm RLS policies in Supabase dashboard

**Input Validation**
- ✅ All user input validated (validators.dart + Supabase ORM)

**Database**
- ✅ Prepared statements used everywhere (Supabase ORM)

**File Uploads**
- ⚠️ Extension allowlist + size limits (10MB images / 100MB video). MIME scanning not implemented.

**API Security**
- ✅ Rate limiting enabled (Supabase)
- ✅ CORS locked down (ALLOWED_ORIGIN env var, not `*`)

**Logging**
- ✅ Logs free of PII and passwords

**Infrastructure**
- ✅ Security headers set on all edge functions (X-Content-Type-Options, X-Frame-Options, HSTS)

**Data Protection**
- ✅ Passwords hashed with bcrypt (Supabase Auth)

**Storage**
- ⚠️ Supabase private buckets — verify RLS policies in dashboard

**Secrets**
- ✅ ROOCOIN_API_KEY server-side only; Supabase anon key in .env (public by design)
- ⚠️ Establish 90-day rotation schedule for ROOCOIN_API_KEY and FCM_SERVER_KEY

**Redirects**
- 📱 N/A — native mobile app, no URL query redirects

**CSRF**
- 📱 N/A — JWT auth, not cookie-based

**Session Cookies**
- 📱 N/A — JWT tokens, not cookies

**Account Lockout**
- ⚠️ Supabase server-side rate limiting only; no client-side counter

**Monitoring**
- ⚠️ Audit log in DB; no real-time alerting pipeline

**Backups**
- ⏳ Supabase managed backups — configure retention and test restores in dashboard

=====================================================

### By Priority Areas

**Input**
- ✅ Everything sanitized (validators.dart + Supabase ORM)
- ✅ No SQL concatenation (Supabase ORM throughout)

**Auth**
- ✅ Sessions expiring (30-min idle + JWT expiry)
- ✅ Passwords hashed (Supabase bcrypt)
- ✅ MFA available (email OTP 2FA)
- ✅ Re-auth for sensitive actions

**Output**
- ✅ Errors generic (zero raw exceptions in UI)
- ✅ Debug logs stripped in release builds

**Infra**
- ⚠️ Dependencies — run `flutter pub outdated` regularly
- ✅ CORS locked down (ALLOWED_ORIGIN, not `*`)

**Data**
- ⚠️ Storage — verify RLS policies in Supabase dashboard
- ⚠️ File uploads — extension + size limits enforced; MIME scanning deferred

---

## Legend
- ✅ Done
- ⚠️ Partial / needs verification or a non-code step
- ⏳ Deferred (infrastructure/ops task)
- 📱 N/A (native mobile app — web-specific concern)

## Action Items Before Launch
1. Set `ALLOWED_ORIGIN` in Supabase dashboard → Edge Functions → Secrets
2. Set `WEBHOOK_SECRET` in Supabase dashboard → Webhooks → Secret (and as edge function secret)
3. Run `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS deletion_requested_at timestamptz;`
4. Verify RLS policies on all Supabase tables and storage buckets in dashboard
5. Run `flutter pub outdated` and update any packages with known CVEs
6. Configure backup retention policy in Supabase dashboard (Pro plan)
7. Establish 90-day rotation calendar for `ROOCOIN_API_KEY` and `FCM_SERVER_KEY`
