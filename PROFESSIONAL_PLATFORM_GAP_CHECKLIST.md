# Professional Platform Gap-Closure Checklist

## Scope
This checklist maps the current app state to professional social platform standards and prioritizes gaps into P0/P1/P2.

## P0 (Ship-Blocking, Do First)

### 1. Production Observability and Alerting
- Goal: Wire crash/error reporting and release health monitoring.
- Files:
  - `lib/main.dart:68`
  - `lib/main.dart:74`
  - `lib/core/errors/error_mapper.dart`
- Tasks:
  - Integrate Sentry or Crashlytics.
  - Add environment tags and release/version metadata.
  - Capture user/session context for debugging.
  - Configure alert routing for critical errors.
- Effort: 1-2 days.

### 2. Wallet Key Custody Hardening
- Goal: Remove or strongly secure DB private-key backup flow.
- Files:
  - `lib/repositories/wallet_repository.dart:56`
  - `lib/repositories/wallet_repository.dart:1037`
- Tasks:
  - Move to HSM/KMS-backed server-side custody or non-custodial model.
  - Define key rotation and recovery policy.
  - Run threat-model review and abuse scenarios.
- Effort: 3-7 days (backend dependent).

### 3. CI Baseline and Quality Gates
- Goal: Enforce automated checks on every PR.
- Files:
  - Repository root (missing `.github/workflows`)
  - `test/widget_test.dart`
  - `test/ai_detection_test.dart`
  - `test/roocoin_smoke_test.dart`
- Tasks:
  - Add Flutter CI workflow.
  - Enforce `flutter analyze`.
  - Enforce `flutter test`.
  - Add build smoke check for target platforms.
- Effort: 0.5-1 day.

## P1 (High Value, Next)

### 1. Admin RBAC and Audit Trail Verification
- Goal: Enforce moderator/admin permissions end-to-end.
- Files:
  - `lib/config/supabase_config.dart.example:43`
  - `lib/screens/moderation/mod_queue_screen.dart:745`
  - `lib/repositories/post_repository.dart:902`
- Tasks:
  - Validate RLS and role claims.
  - Ensure immutable moderation audit logs.
  - Preserve reviewer attribution and decision lineage.
- Effort: 2-4 days.

### 2. Abuse/Risk Controls Beyond Moderation UI
- Goal: Add robust anti-abuse controls for auth/post/message/report flows.
- Files:
  - `lib/providers/auth_provider.dart:557`
  - `lib/services/chat_service.dart`
  - `lib/services/dm_service.dart`
- Tasks:
  - Add backend throttling/rate limits.
  - Add device/IP heuristics and anomaly detection.
  - Build abuse monitoring dashboards.
- Effort: 2-5 days.

### 3. Documentation Correction
- Goal: Align documentation with current platform implementation.
- Files:
  - `README.md`
  - `ROOVERSE ARCHITECTURE.md`
- Tasks:
  - Remove outdated JSONPlaceholder references.
  - Add current setup, deploy, and release workflows.
  - Add operational notes for moderation, wallet, and verification flows.
- Effort: 0.5-1 day.

## P2 (Polish and Scale Readiness)

### 1. Accessibility Hardening
- Goal: Improve screen-reader and contrast compliance.
- Files:
  - `lib/screens/feed/feed_screen.dart`
  - `lib/screens/profile/profile_screen.dart`
  - `lib/screens/create/create_post_screen.dart`
- Tasks:
  - Add semantic labels and better focus order.
  - Validate dynamic text scaling and tap targets.
  - Run accessibility QA checks.
- Effort: 2-4 days.

### 2. Test Depth Expansion
- Goal: Improve confidence across critical user journeys.
- Files:
  - `test/*`
  - Provider and repository modules
- Tasks:
  - Add auth edge-case coverage.
  - Add moderation decision-path tests.
  - Add wallet transfer failure/retry tests.
  - Add realtime sync and notification behavior tests.
- Effort: 2-5 days.

### 3. SLOs and Operational Runbooks
- Goal: Establish production reliability and incident response standards.
- Files:
  - Operations documentation/configs
- Tasks:
  - Define uptime and error-budget SLOs.
  - Create on-call and incident playbooks.
  - Define rollback and postmortem templates.
- Effort: 1-2 days.

## Recommended Execution Order
1. P0.1 Observability
2. P0.3 CI gates
3. P0.2 Wallet custody hardening
4. P1.1 RBAC/audit
5. P1.2 Abuse controls
6. P1.3 Documentation updates
7. P2 items
