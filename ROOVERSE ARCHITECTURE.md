# Rooverse Platform Architecture

> A comprehensive technical overview of the Rooverse decentralized social network platform.

---

## Table of Contents

1. [Overview](#overview)
2. [Tech Stack](#tech-stack)
3. [System Architecture](#system-architecture)
4. [Frontend Architecture](#frontend-architecture)
5. [Backend Infrastructure](#backend-infrastructure)
6. [State Management](#state-management)
7. [AI/ML Detection System](#aiml-detection-system)
8. [Roocoin Integration](#roocoin-integration)
9. [Authentication & Security](#authentication--security)
10. [Data Layer](#data-layer)
11. [Platform Features](#platform-features)

---

## Overview

Rooverse is a **decentralized social network** that combines traditional social media features with blockchain-based cryptocurrency rewards and AI-powered content moderation. The platform incentivizes authentic human content creation through its native **Roocoin (ROO)** token while using machine learning to detect and flag AI-generated content.

### Core Principles

- **Human-First Content**: AI detection ensures authentic human-created content
- **Decentralized Rewards**: Roocoin cryptocurrency for user engagement
- **Trust-Based Community**: User trust scores and human verification
- **Cross-Platform**: iOS, Android, Web, and Desktop support

---

## Tech Stack

### Frontend

| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter | 3.9.2+ | Cross-platform UI framework |
| Dart | Latest | Programming language |
| Provider | 6.1.1 | State management |
| go_router | 14.6.2 | Navigation & routing |

### Backend

| Technology | Purpose |
|------------|---------|
| Supabase | Database, Auth, Storage, Realtime |
| PostgreSQL | Primary database (via Supabase) |
| Supabase Edge Functions | Serverless backend logic |

### External APIs

| Service | Endpoint | Purpose |
|---------|----------|---------|
| NOAI Detection API | `noai-lm-production.up.railway.app` | AI content detection |
| Roocoin API | `roocoin-production.up.railway.app` | Cryptocurrency operations |

### Key Dependencies

```yaml
# Core
supabase_flutter: ^2.5.0      # Backend services
provider: ^6.1.1              # State management
go_router: ^14.6.2            # Navigation

# Media
video_player: ^2.10.1         # Video playback
image_picker: ^1.0.7          # Media selection
cached_network_image: ^3.3.1  # Image caching

# Security
flutter_secure_storage: ^9.2.4 # Encrypted storage

# Utilities
flutter_dotenv: ^5.2.1        # Environment config
uuid: ^4.3.3                  # ID generation
```

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    ROOVERSE PLATFORM                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              FLUTTER APPLICATION                         │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐    │   │
│  │  │   iOS   │  │ Android │  │   Web   │  │ Desktop │    │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘    │   │
│  └─────────────────────────┬───────────────────────────────┘   │
│                            │                                    │
│  ┌─────────────────────────▼───────────────────────────────┐   │
│  │              PROVIDER STATE LAYER                        │   │
│  │  AuthProvider │ WalletProvider │ FeedProvider │ etc.    │   │
│  └─────────────────────────┬───────────────────────────────┘   │
│                            │                                    │
│  ┌─────────────────────────▼───────────────────────────────┐   │
│  │              REPOSITORY LAYER                            │   │
│  │  PostRepo │ WalletRepo │ StoryRepo │ CommentRepo │ etc. │   │
│  └─────────────────────────┬───────────────────────────────┘   │
│                            │                                    │
└────────────────────────────┼────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│   SUPABASE    │   │  NOAI API     │   │  ROOCOIN API  │
│  • PostgreSQL │   │  • Text ML    │   │  • Wallets    │
│  • Auth       │   │  • Image ML   │   │  • Transfers  │
│  • Storage    │   │  • Video ML   │   │  • Rewards    │
│  • Realtime   │   │  • Feedback   │   │  • Staking    │
└───────────────┘   └───────────────┘   └───────────────┘
```

---

## Frontend Architecture

### Application Structure

```
lib/
├── main.dart                 # App entry point
├── config/                   # Configuration
│   ├── app_constants.dart    # Global constants
│   ├── supabase_config.dart  # Database config
│   ├── app_colors.dart       # Color schemes
│   └── app_router.dart       # Route definitions
├── models/                   # Data models
├── providers/                # State management
├── repositories/             # Data access layer
├── services/                 # External services
├── screens/                  # UI screens
└── widgets/                  # Reusable components
```

### Initialization Flow

```dart
main() {
  // 1. Load environment variables
  await dotenv.load();

  // 2. Initialize Supabase
  await SupabaseService().initialize();

  // 3. Initialize local storage
  await StorageService().init();

  // 4. Start presence tracking
  PresenceService().start();

  // 5. Run app with providers
  runApp(MultiProvider(...));
}
```

### Navigation Architecture

The app uses `go_router` with nested navigation:

```
AuthWrapper (auth state listener)
├── Unauthenticated Routes
│   ├── /splash
│   ├── /onboarding
│   ├── /login
│   └── /signup
└── Authenticated Routes (MainShell)
    ├── /feed (home)
    ├── /explore
    ├── /create
    ├── /notifications
    └── /profile
```

---

## Backend Infrastructure

### Supabase Configuration

**Connection Setup** ([supabase_config.dart](lib/config/supabase_config.dart)):

```dart
await Supabase.initialize(
  url: dotenv.env['SUPABASE_URL']!,
  anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
);
```

### Database Schema

#### Core Tables

| Table | Purpose |
|-------|---------|
| `profiles` | User profile data |
| `wallets` | Roocoin wallet accounts |
| `roocoin_transactions` | Token transaction history |
| `staking_positions` | Staking records |

#### Social Tables

| Table | Purpose |
|-------|---------|
| `posts` | User posts with content |
| `comments` | Post comments |
| `reactions` | Likes/reactions |
| `follows` | Follow relationships |
| `stories` | Ephemeral 24-hour content |
| `bookmarks` | Saved posts |

#### Messaging Tables

| Table | Purpose |
|-------|---------|
| `dm_threads` | Direct message conversations |
| `dm_messages` | Individual messages |
| `dm_participants` | Thread participants |

#### Moderation Tables

| Table | Purpose |
|-------|---------|
| `human_verifications` | Verification records |
| `user_reports` | Abuse reports |
| `moderation_cases` | Moderation decisions |
| `trust_events` | Trust score changes |

### Storage Buckets

- `avatars` - Profile pictures
- `post-media` - Post images/videos
- `dm-attachments` - DM file attachments

---

## State Management

### Provider Pattern

Rooverse uses the **Provider** package with `ChangeNotifier` for reactive state management.

```
┌─────────────────────────────────────────────────────┐
│                 MultiProvider                        │
├─────────────────────────────────────────────────────┤
│  AuthProvider      │ Authentication state           │
│  ThemeProvider     │ Light/dark mode                │
│  UserProvider      │ Current user profile           │
│  WalletProvider    │ Roocoin wallet & balance       │
│  FeedProvider      │ Feed posts & filtering         │
│  StoryProvider     │ Stories/statuses               │
│  StakingProvider   │ Staking positions              │
│  ChatProvider      │ Chat conversations             │
│  NotificationProvider │ In-app notifications        │
│  LanguageProvider  │ App localization               │
└─────────────────────────────────────────────────────┘
```

### Key Provider: AuthProvider

**File**: [auth_provider.dart](lib/providers/auth_provider.dart)

```dart
enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  User? _user;

  // Auth methods
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password, String username);
  Future<void> signOut();
  Future<void> verifyOtp(String email, String token);

  // Account status detection
  bool get isBanned;
  bool get isSuspended;
}
```

### Key Provider: WalletProvider

**File**: [wallet_provider.dart](lib/providers/wallet_provider.dart)

```dart
class WalletProvider extends ChangeNotifier {
  Wallet? _wallet;
  List<RoocoinTransaction> _transactions = [];

  // Wallet operations
  Future<void> initWallet(String userId);
  Future<void> spendRoo(double amount, String activityType);
  Future<void> earnRoo(double amount, String activityType);
  Future<void> transferToExternal(String toAddress, double amount);
  Future<void> refreshWallet();
}
```

---

## AI/ML Detection System

### Overview

The NOAI Detection System analyzes content to determine whether it was created by humans or AI. This is central to Rooverse's mission of promoting authentic human content.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                 NOAI DETECTION API                       │
│           noai-lm-production.up.railway.app             │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Text Model  │  │ Image Model  │  │ Video Model  │  │
│  │  Analysis    │  │  Analysis    │  │  Analysis    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│           │                │                │           │
│           └────────────────┼────────────────┘           │
│                            ▼                            │
│                   ┌──────────────┐                      │
│                   │   Consensus  │                      │
│                   │    Engine    │                      │
│                   └──────────────┘                      │
│                            │                            │
│                            ▼                            │
│                   ┌──────────────┐                      │
│                   │   Result     │                      │
│                   │   + Score    │                      │
│                   └──────────────┘                      │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Service Implementation

**File**: [ai_detection_service.dart](lib/services/ai_detection_service.dart)

```dart
class AiDetectionService {
  static const String baseUrl = 'https://noai-lm-production.up.railway.app';

  // Detection methods
  Future<AiDetectionResult> detectText(String content);
  Future<AiDetectionResult> detectImage(File file);
  Future<AiDetectionResult> detectMixed(String content, File file);

  // Feedback for model improvement
  Future<void> submitFeedback({
    required String analysisId,
    required String correctResult,
    String? feedbackNotes,
    String source = 'user',
  });

  // Health check
  Future<bool> healthCheck();
}
```

### Detection Result Model

**File**: [ai_detection_result.dart](lib/models/ai_detection_result.dart)

```dart
class AiDetectionResult {
  final String analysisId;        // Unique analysis ID
  final String result;            // "HUMAN-GENERATED" | "AI-GENERATED" | "MIXED"
  final double confidence;        // 0-100 confidence score
  final String contentType;       // "text" | "image" | "mixed"
  final String consensusStrength; // "strong" | "moderate" | "weak" | "split"
  final String rationale;         // Human-readable explanation
  final List<Evidence> combinedEvidence;
  final List<ModelAnalysis> modelAnalyses;
}
```

### Integration Points

| Feature | Detection Type | Trigger |
|---------|---------------|---------|
| Post Creation | Text + Media | On publish |
| Story Upload | Image/Video | On upload |
| Comments | Text | On submit |
| Chat Messages | Text | On send |
| Profile Bio | Text | On save |

### Moderation Workflow

```
User creates content
        │
        ▼
┌───────────────────┐
│  AI Detection     │
│  API Call         │
└─────────┬─────────┘
          │
          ▼
    ┌─────────────┐
    │ Confidence  │
    │  > 70%?     │
    └──────┬──────┘
           │
     ┌─────┴─────┐
     │           │
    Yes          No
     │           │
     ▼           ▼
┌─────────┐  ┌─────────┐
│ Flag for│  │ Auto    │
│ Review  │  │ Approve │
└─────────┘  └─────────┘
```

---

## Roocoin Integration

### Overview

Roocoin (ROO) is Rooverse's native cryptocurrency token that rewards users for authentic engagement. It features wallet management, peer-to-peer transfers, and staking for yield.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  ROOCOIN ECOSYSTEM                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │              ROOCOIN API                         │    │
│  │       roocoin-production.up.railway.app         │    │
│  ├─────────────────────────────────────────────────┤    │
│  │  • Wallet Creation    • Balance Queries         │    │
│  │  • Transfers          • Reward Distribution     │    │
│  │  • Staking            • Transaction History     │    │
│  └─────────────────────────────────────────────────┘    │
│                            │                             │
│                            ▼                             │
│  ┌─────────────────────────────────────────────────┐    │
│  │              SUPABASE SYNC                       │    │
│  │  • wallets table      • roocoin_transactions    │    │
│  │  • staking_positions  • staking_rewards         │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Service Implementation

**File**: [roocoin_service.dart](lib/services/roocoin_service.dart)

```dart
class RoocoinService {
  static const String baseUrl = 'https://roocoin-production.up.railway.app';

  // Wallet management
  Future<Map<String, String>> createWallet();
  Future<double> getBalance(String address);

  // Transactions
  Future<void> spend({
    required String userPrivateKey,
    required double amount,
    required String activityType,
    Map<String, dynamic>? metadata,
  });

  Future<void> transfer({
    required String fromPrivateKey,
    required String toAddress,
    required double amount,
  });

  // Rewards
  Future<void> distributeReward({
    required String userAddress,
    required String activityType,
    Map<String, dynamic>? metadata,
  });
}
```

### Reward Structure

| Activity | ROO Reward |
|----------|------------|
| `WELCOME_BONUS` | 100 ROO |
| `REFERRAL` | 50 ROO |
| `PROFILE_COMPLETE` | 25 ROO |
| `POST_CREATE` | 10 ROO |
| `POST_SHARE` | 5 ROO |
| `POST_COMMENT` | 2 ROO |
| `DAILY_LOGIN` | 1 ROO |
| `POST_LIKE` | 0.1 ROO |
| `CONTENT_VIRAL` | 100 ROO |

### Wallet Model

**File**: [wallet.dart](lib/models/wallet.dart)

```dart
class Wallet {
  final String userId;
  final String walletAddress;      // EVM-compatible (0x...)
  final double balanceRc;          // Current balance
  final double pendingBalanceRc;   // Pending rewards
  final double lifetimeEarnedRc;   // Total earned
  final double lifetimeSpentRc;    // Total spent
  final bool isFrozen;             // Frozen status
  final String? frozenReason;      // Freeze reason
  final double dailySendLimitRc;   // Daily transfer limit
  final double dailySentTodayRc;   // Sent today
}
```

### Staking System

**File**: [staking.dart](lib/models/staking.dart)

| Tier | APY | Min Stake | Lock Period |
|------|-----|-----------|-------------|
| Flexible | 3% | 100 ROO | None |
| Bronze | 5% | 500 ROO | 30 days |
| Silver | 8% | 1,000 ROO | 90 days |
| Gold | 12% | 5,000 ROO | 180 days |
| Platinum | 15% | 10,000 ROO | 365 days |

### Transaction Flow

```
User Action (e.g., create post)
            │
            ▼
┌───────────────────────┐
│   WalletProvider      │
│   earnRoo()           │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│   WalletRepository    │
│   recordTransaction() │
└───────────┬───────────┘
            │
     ┌──────┴──────┐
     │             │
     ▼             ▼
┌─────────┐  ┌─────────┐
│ Roocoin │  │Supabase │
│   API   │  │  Sync   │
└─────────┘  └─────────┘
```

---

## Authentication & Security

### Auth Flow

```
┌─────────┐    ┌─────────────┐    ┌──────────────┐    ┌─────────┐
│ Splash  │───▶│ Onboarding  │───▶│ Login/Signup │───▶│  OTP    │
└─────────┘    └─────────────┘    └──────────────┘    └────┬────┘
                                                           │
                                                           ▼
┌─────────┐    ┌─────────────┐    ┌──────────────┐    ┌─────────┐
│  Main   │◀───│  Interests  │◀───│    Human     │◀───│  Phone  │
│   App   │    │  Selection  │    │ Verification │    │  Verify │
└─────────┘    └─────────────┘    └──────────────┘    └─────────┘
```

### Auth Methods

- **Email/Password**: Primary authentication
- **Email OTP**: Verification codes
- **Phone OTP**: Optional phone verification
- **Password Recovery**: Email-based reset

### Security Features

| Feature | Implementation |
|---------|---------------|
| Credential Storage | `flutter_secure_storage` (encrypted) |
| Session Management | Supabase Auth with JWT |
| Private Key Storage | AES-256 encrypted in secure storage |
| API Keys | Environment variables (`.env`) |

### Account Status

| Status | Access Level |
|--------|-------------|
| `active` | Full access |
| `suspended` | Limited access, warning shown |
| `banned` | No access, forced sign out |

### Human Verification

Human verification is used to confirm authentic human users:

```dart
class HumanVerification {
  final String verificationId;
  final String userId;
  final String verificationMethod;  // "selfie" | "captcha" | "phone"
  final bool isVerified;
  final DateTime? verifiedAt;
}
```

---

## Data Layer

### Repository Pattern

Each domain has a dedicated repository for data access:

```
┌───────────────────────────────────────────────────┐
│                  REPOSITORIES                      │
├───────────────────────────────────────────────────┤
│                                                    │
│  post_repository.dart        │ Posts CRUD         │
│  comment_repository.dart     │ Comments           │
│  story_repository.dart       │ Stories            │
│  wallet_repository.dart      │ Wallet operations  │
│  staking_repository.dart     │ Staking positions  │
│  notification_repository.dart│ Notifications      │
│  follow_repository.dart      │ Follow relations   │
│  block_repository.dart       │ Block/mute         │
│  report_repository.dart      │ User reports       │
│  media_repository.dart       │ Media uploads      │
│                                                    │
└───────────────────────────────────────────────────┘
```

### Model Structure

**File**: [post.dart](lib/models/post.dart)

```dart
class Post {
  final String id;
  final String authorId;
  final String content;
  final List<PostMedia> media;
  final List<String> tags;
  final String privacySetting;     // "everyone" | "followers" | "private"
  final String? aiModerationStatus; // AI detection result
  final double? aiConfidenceScore;
  final int reactionCount;
  final int commentCount;
  final int repostCount;
  final DateTime createdAt;
}
```

**File**: [user.dart](lib/models/user.dart)

```dart
class User {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final int trustScore;           // 0-100
  final double? mlAiDetectionScore;
  final bool isHumanVerified;
  final int followerCount;
  final int followingCount;
  final List<String> interests;
  final String accountStatus;     // "active" | "suspended" | "banned"
}
```

---

## Platform Features

### Core Social Features

| Feature | Description | Files |
|---------|-------------|-------|
| Feed | Personalized content feed | [feed_screen.dart](lib/screens/feed/feed_screen.dart) |
| Posts | Text + media posts | [create_post_screen.dart](lib/screens/create/create_post_screen.dart) |
| Stories | 24-hour ephemeral content | [story_viewer.dart](lib/widgets/story_viewer.dart) |
| Comments | Nested discussions | [comments_sheet.dart](lib/widgets/comments_sheet.dart) |
| Reactions | Like/react to content | [reaction_repository.dart](lib/repositories/reaction_repository.dart) |
| Follows | Follow other users | [follow_repository.dart](lib/repositories/follow_repository.dart) |

### Wallet Features

| Feature | Description | Files |
|---------|-------------|-------|
| Balance | View ROO balance | [wallet_screen.dart](lib/screens/wallet/wallet_screen.dart) |
| Send | Transfer tokens | [send_roo_screen.dart](lib/screens/wallet/send_roo_screen.dart) |
| Receive | Receive tokens | [receive_roo_screen.dart](lib/screens/wallet/receive_roo_screen.dart) |
| History | Transaction history | [transaction_history_screen.dart](lib/screens/wallet/transaction_history_screen.dart) |
| Staking | Stake for yield | [staking_screen.dart](lib/screens/wallet/staking_screen.dart) |

### Messaging

| Feature | Description | Files |
|---------|-------------|-------|
| DMs | Direct messages | [dm_list_screen.dart](lib/screens/dm/dm_list_screen.dart) |
| Chat | Group conversations | [chat_list_screen.dart](lib/screens/chat/chat_list_screen.dart) |
| AI Detection | Message AI scanning | [chat_service.dart](lib/services/chat_service.dart) |

### Moderation

| Feature | Description |
|---------|-------------|
| Reports | User abuse reporting |
| Trust Score | Reputation system (0-100) |
| Appeals | Suspension appeals |
| Mod Queue | Content moderation interface |

---

## Environment Configuration

### Required Environment Variables

```env
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# Roocoin API
ROOCOIN_API_KEY=your-roocoin-api-key
```

### Build Targets

| Platform | Build Command |
|----------|--------------|
| Android | `flutter build apk` |
| iOS | `flutter build ios` |
| Web | `flutter build web` |
| Windows | `flutter build windows` |
| macOS | `flutter build macos` |
| Linux | `flutter build linux` |

---

## Summary

Rooverse is a modern social platform that combines:

1. **Flutter** for cross-platform native performance
2. **Supabase** for scalable backend infrastructure
3. **NOAI API** for AI content detection and moderation
4. **Roocoin** for blockchain-based rewards and engagement incentives
5. **Provider** for clean state management architecture

The platform prioritizes authentic human content through AI detection while rewarding users with cryptocurrency for genuine engagement.

---

*Last updated: February 2025*
