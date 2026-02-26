import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:rooverse/widgets/profile_image_preview.dart';
import 'providers/auth_provider.dart';
import 'providers/post_provider.dart';
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/feed_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/dm_provider.dart';
import 'providers/language_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/story_provider.dart';
import 'providers/wallet_provider.dart';
import 'services/storage_service.dart';
import 'services/supabase_service.dart';
import 'services/presence_service.dart';
import 'services/connectivity_service.dart';
import 'services/deep_link_service.dart';
import 'core/extensions/exception_extensions.dart';
import 'models/view_enum.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/interests_selection_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/verification_screen.dart';
import 'screens/auth/recovery_screen.dart';
import 'screens/auth/suspended_screen.dart';
import 'screens/auth/human_verification_screen.dart';
import 'screens/auth/phone_verification_screen.dart';
import 'screens/feed/feed_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/wallet/wallet_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/create/create_post_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/conversation_thread_page.dart';
import 'screens/support/contact_support_screen.dart';
import 'screens/support/faq_screen.dart';
import 'screens/support/support_chat_screen.dart';
import 'screens/post_detail_screen.dart';
import 'config/app_constants.dart';
import 'config/global_keys.dart';
import 'widgets/adaptive/adaptive_navigation.dart';
import 'screens/auth/banned_screen.dart';
import 'services/push_notification_service.dart';
import 'services/app_update_service.dart';
import 'widgets/connectivity_overlay.dart';
import 'widgets/welcome_dialog.dart';
import 'utils/responsive_utils.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Set up global Flutter error handling (for framework errors)
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('Flutter Error: ${details.exception}');
        // You could also report to Sentry/Firebase Crashlytics here
      };

      // Set up global platform error handling (for async errors)
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Platform Error: $error');
        // You could also report to Sentry/Firebase Crashlytics here
        return true; // Error was handled
      };

      // Replace the default Flutter error widget with a more user-friendly one
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return Material(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Oops! Something went wrong',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exception.userMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      };

      await dotenv.load(fileName: '.env');
      await StorageService().init();
      await SupabaseService().initialize();
      await PushNotificationService().initialize();
      await ConnectivityService().initialize();
      PresenceService().start();

      runApp(const MyApp());
    },
    (error, stackTrace) {
      debugPrint('Zoned Guarded Error: $error');
      debugPrint('Stack trace: $stackTrace');
    },
  );
}

/* ───────────────────────────────────────────── */
/* ROOT APP                                      */
/* ───────────────────────────────────────────── */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => StoryProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => DmProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        Provider(create: (_) => DeepLinkService()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (_, themeProvider, languageProvider, __) {
          return MaterialApp(
            title: AppConstants.appName,
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            navigatorKey: rootNavigatorKey,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.theme,
            locale: Locale(languageProvider.currentLanguage),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('es'),
              Locale('fr'),
              Locale('de'),
              Locale('it'),
              Locale('pt'),
              Locale('ru'),
              Locale('zh'),
              Locale('ja'),
              Locale('ko'),
              Locale('ar'),
              Locale('hi'),
            ],
            routes: {
              '/verify': (context) => HumanVerificationScreen(
                onVerify: () => Navigator.pop(context),
                onPhoneVerify: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhoneVerificationScreen(
                        onVerify: () => Navigator.pop(context),
                        onBack: () => Navigator.pop(context),
                      ),
                    ),
                  );
                },
              ),
              '/wallet': (context) => const WalletScreen(),
            },
            home: const AuthWrapper(),
            builder: (context, child) {
              // Add connectivity overlay and error boundary
              return ConnectivityOverlay(
                child: ErrorBoundary(child: child ?? const SizedBox.shrink()),
              );
            },
          );
        },
      ),
    );
  }
}

/// Global error boundary to catch and display unhandled errors
class ErrorBoundary extends StatefulWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Catch UI-level errors that don't trigger ErrorWidget.builder
    // such as errors in builds or async operations that affect this branch
  }

  void _handleError(Object error, StackTrace stackTrace) {
    if (!mounted) return;

    setState(() {
      _hasError = true;
      _errorMessage = error.userMessage;
    });

    debugPrint('ErrorBoundary caught error: $error');
    debugPrint('Stack trace: $stackTrace');
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Oops! Something went wrong'.tr(context),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'An unexpected error occurred',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _errorMessage = null;
                    });
                  },
                  child: Text('Retry'.tr(context)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}

/// Wrapper that handles auth state and shows appropriate screen.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _deepLinkHandled = false;
  bool _handlingPendingNotificationTap = false;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeHandleDeepLink());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeHandlePendingNotificationTap(),
    );

    final authProvider = context.watch<AuthProvider>();
    // Watch WalletProvider so AuthWrapper rebuilds when balance changes,
    // which re-triggers the addPostFrameCallback balance sync to FeedProvider.
    context.watch<WalletProvider>();

    // Sync user when auth state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // This check prevents the callback from running when the widget is no longer in the tree.
      if (mounted) {
        final userProvider = context.read<UserProvider>();
        final feedProvider = context.read<FeedProvider>();

        // Set up callback for real-time block list sync
        userProvider.onBlockListChanged ??= (blocked, blockedBy) {
          feedProvider.setBlockedUserIds(blocked, blockedBy);
        };

        // Set up callback for real-time mute list sync
        userProvider.onMuteListChanged ??= (muted) {
          feedProvider.setMutedUserIds(muted);
        };

        if (authProvider.currentUser != null &&
            userProvider.currentUser?.id != authProvider.currentUser!.id) {
          userProvider.setCurrentUser(authProvider.currentUser!);
          // Refresh and start listening for notifications
          final notificationProvider = context.read<NotificationProvider>();
          notificationProvider.refreshNotifications(
            authProvider.currentUser!.id,
          );
          notificationProvider.startListening(authProvider.currentUser!.id);

          // Load conversations and start listening for real-time chat updates
          final chatProvider = context.read<ChatProvider>();
          chatProvider.loadConversations();
          chatProvider.startListening(authProvider.currentUser!.id);

          // Initialize wallet
          context.read<WalletProvider>().initWallet(
            authProvider.currentUser!.id,
          );
        } else if (authProvider.status == AuthStatus.unauthenticated &&
            userProvider.currentUser != null) {
          userProvider.clearCurrentUser();
          context.read<NotificationProvider>().clear();
          context.read<ChatProvider>().clear();
        }

        // Sync blocked user IDs to FeedProvider for filtering
        feedProvider.setBlockedUserIds(
          userProvider.blockedUserIds,
          userProvider.blockedByUserIds,
        );

        // Sync muted user IDs to FeedProvider for filtering
        feedProvider.setMutedUserIds(userProvider.mutedUserIds);

        // Sync wallet balance to FeedProvider for activation gate (Gate 2)
        final walletProvider = context.read<WalletProvider>();
        feedProvider.setCurrentUserBalance(
          walletProvider.wallet?.balanceRc ?? 0.0,
        );

        // Refresh user interests when authenticated
        if (authProvider.status == AuthStatus.authenticated) {
          feedProvider.refreshInterests();
        }
      }
    });

    switch (authProvider.status) {
      case AuthStatus.initial:
        // Show splash while checking auth state
        return SplashScreen(onComplete: () {});
      case AuthStatus.loading:
        // If password reset is pending, stay on recovery screen during loading
        if (authProvider.isPasswordResetPending) {
          return const AppNavigator(
            key: ValueKey('recovery_navigator'),
            initialView: ViewType.recover,
          );
        }
        // If email verification is pending, stay on verify screen during loading
        if (authProvider.pendingEmail != null) {
          return const AppNavigator(
            key: ValueKey('verify_navigator'),
            initialView: ViewType.verify,
          );
        }
        // Show splash while checking auth state
        return SplashScreen(onComplete: () {});
      case AuthStatus.authenticated:
        final user = authProvider.currentUser;
        if (user != null) {
          // Handle suspended users (banned now has its own state)
          if (user.status == 'suspended') {
            return const SuspendedScreen();
          }
        }
        // User is logged in and verified, show main app
        final userProvider = context.watch<UserProvider>();
        if (userProvider.currentUser != null &&
            !userProvider.isProfileComplete) {
          return const AppNavigator(initialView: ViewType.interests);
        }
        return const MainShell();
      case AuthStatus.banned:
        return const BannedScreen();
      case AuthStatus.unauthenticated:
        // User needs to login or verify email
        if (authProvider.pendingEmail != null) {
          return const AppNavigator(
            key: ValueKey('verify_navigator'),
            initialView: ViewType.verify,
          );
        }
        if (authProvider.isPasswordResetPending) {
          return const AppNavigator(
            key: ValueKey('recovery_navigator'),
            initialView: ViewType.recover,
          );
        }
        // Default auth flow
        return const AppNavigator();
    }
  }

  void _maybeHandleDeepLink() {
    if (_deepLinkHandled || !mounted) return;
    final destination = context
        .read<DeepLinkService>()
        .consumePendingDestination();
    if (destination == null) return;
    _deepLinkHandled = true;

    if (destination == DeepLinkDestination.verificationCallback) return;

    final screen = destination == DeepLinkDestination.helpCenter
        ? const FAQScreen()
        : const ContactSupportScreen();

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _maybeHandlePendingNotificationTap() async {
    if (!mounted || _handlingPendingNotificationTap) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.status != AuthStatus.authenticated ||
        authProvider.currentUser == null) {
      return;
    }

    final data = PushNotificationService().consumePendingNotificationData();
    if (data == null) return;

    _handlingPendingNotificationTap = true;
    try {
      await _handlePendingNotificationTapData(data);
    } finally {
      _handlingPendingNotificationTap = false;
    }
  }

  Future<void> _handlePendingNotificationTapData(
    Map<String, dynamic> data,
  ) async {
    final notificationId = _payloadString(data, 'notification_id');
    if (notificationId != null) {
      await context.read<NotificationProvider>().markAsRead(notificationId);
    }

    final type = (_payloadString(data, 'type') ?? '').toLowerCase();
    final title = (_payloadString(data, 'title') ?? '').toLowerCase();
    final body = (_payloadString(data, 'body') ?? '').toLowerCase();
    final threadId = _payloadString(data, 'thread_id');
    final ticketId = _payloadString(data, 'ticket_id');
    final postId = _payloadString(data, 'post_id');
    final actorId = _payloadString(data, 'actor_id');

    final isSupportNotification =
        type == 'support_chat' ||
        (type == 'mention' &&
            postId == null &&
            (title.contains('support') ||
                body.contains('support') ||
                title.contains('update') ||
                title.contains('announcement') ||
                title.contains('notice') ||
                title.contains('maintenance') ||
                body.contains('support team')));

    if (isSupportNotification && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SupportChatScreen(initialTicketId: ticketId),
        ),
      );
      return;
    }

    if (threadId != null) {
      final chatProvider = context.read<ChatProvider>();
      var index = chatProvider.conversations.indexWhere(
        (c) => c.id == threadId,
      );
      var conversation = index >= 0 ? chatProvider.conversations[index] : null;

      if (conversation == null) {
        await chatProvider.loadConversations();
        if (!mounted) return;
        index = chatProvider.conversations.indexWhere((c) => c.id == threadId);
        conversation = index >= 0 ? chatProvider.conversations[index] : null;
      }

      if (conversation != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationThreadPage(conversation: conversation!),
          ),
        );
        return;
      }
    }

    if (postId != null) {
      final post = await context.read<FeedProvider>().getPostById(postId);
      if (!mounted) return;
      if (post != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
        return;
      }
    }

    final shouldOpenChatFromActor =
        actorId != null &&
        (type == 'message' ||
            type == 'chat' ||
            (type == 'mention' && postId == null));

    if (shouldOpenChatFromActor) {
      final conversation = await context.read<ChatProvider>().startConversation(
        actorId!,
      );
      if (!mounted) return;
      if (conversation != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationThreadPage(conversation: conversation),
          ),
        );
        return;
      }
    }

    if (actorId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: actorId, showAppBar: true),
        ),
      );
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    }
  }

  String? _payloadString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }
}

/* ───────────────────────────────────────────── */
/* AUTH FLOW                                     */
/* ───────────────────────────────────────────── */

class AppNavigator extends StatefulWidget {
  final ViewType? initialView;

  const AppNavigator({super.key, this.initialView});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  late ViewType _view;

  @override
  void initState() {
    super.initState();
    _view = widget.initialView ?? ViewType.onboarding;
  }

  void _go(ViewType v) => setState(() => _view = v);

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case ViewType.splash:
        return SplashScreen(onComplete: () => _go(ViewType.onboarding));
      case ViewType.onboarding:
        return OnboardingScreen(onComplete: () => _go(ViewType.login));
      case ViewType.interests:
        return InterestsSelectionScreen(
          onComplete: () {
            if (context.read<AuthProvider>().isAuthenticated) {
              // If already logged in, we are in the "Complete Profile" flow
              _go(ViewType.feed);
            } else {
              _go(ViewType.login);
            }
          },
        );
      case ViewType.login:
        return LoginScreen(
          onLogin: () => _go(ViewType.feed),
          onSignup: () => _go(ViewType.signup),
          onRecover: () => _go(ViewType.recover),
        );
      case ViewType.signup:
        return SignupScreen(
          onSignup: () => _go(ViewType.verify),
          onLogin: () => _go(ViewType.login),
        );
      case ViewType.verify:
        return VerificationScreen(
          onVerify: () => _go(ViewType.humanVerify),
          onBack: () => _go(ViewType.signup),
          onChangeEmail: () => _go(ViewType.signup),
        );
      case ViewType.humanVerify:
        return HumanVerificationScreen(
          onVerify: () => _go(ViewType.feed),
          onPhoneVerify: () => _go(ViewType.phoneVerify),
          onBack: context.read<AuthProvider>().isAuthenticated
              ? null
              : () => _go(ViewType.verify),
        );
      case ViewType.phoneVerify:
        return PhoneVerificationScreen(
          onVerify: () => _go(ViewType.feed),
          onBack: () => _go(ViewType.humanVerify),
        );
      case ViewType.recover:
        return RecoveryScreen(onBack: () => _go(ViewType.login));
      default:
        return const MainShell();
    }
  }
}

/* ───────────────────────────────────────────── */
/* MAIN SHELL (ONE APPBAR)                        */
/* ───────────────────────────────────────────── */

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _updateCheckTriggered = false;

  @override
  void initState() {
    super.initState();
    // Check and award daily login reward
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkWelcomeBonus();
      await _checkForAppUpdate();
    });
  }

  Future<void> _checkForAppUpdate() async {
    if (_updateCheckTriggered || !mounted) return;
    _updateCheckTriggered = true;

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await AppUpdateService.instance.checkAndPromptForUpdate(
      context,
      force: true,
    );
  }

  Future<void> _checkWelcomeBonus() async {
    final walletProvider = context.read<WalletProvider>();
    if (walletProvider.wasWelcomeBonusAwarded && mounted) {
      walletProvider.consumeWelcomeBonus();
      await WelcomeDialog.show(
        context,
        onViewWallet: () {
          setState(() => _index = 2);
        },
        onStartExploring: () {
          // Stay on feed (index 0)
        },
      );
    }
  }

  void _onPostCreated() {
    // Navigate back to feed after creating a post
    setState(() => _index = 0);
  }

  List<Widget> get _screens => [
    const FeedScreen(),
    const ExploreScreen(),
    CreatePostScreen(onPostCreated: _onPostCreated),
    const WalletScreen(),
    const ProfileScreen(),
  ];

  List<AdaptiveNavigationDestination> _destinations(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      AdaptiveNavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: l10n.home,
      ),
      AdaptiveNavigationDestination(
        icon: const Icon(Icons.explore_outlined),
        selectedIcon: const Icon(Icons.explore),
        label: l10n.discover,
      ),
      AdaptiveNavigationDestination(
        icon: const Icon(Icons.add_circle_outline),
        selectedIcon: const Icon(Icons.add_circle),
        label: l10n.create,
      ),
      AdaptiveNavigationDestination(
        icon: const Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: const Icon(Icons.account_balance_wallet),
        label: l10n.wallet,
      ),
      AdaptiveNavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: l10n.profile,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: const RooverseAppBar(),
      body: Consumer2<AuthProvider, WalletProvider>(
        builder: (context, auth, wallet, _) {
          final user = auth.currentUser;
          final balance = wallet.wallet?.balanceRc ?? 0.0;
          // Show banner when user has 0 ROO balance (regardless of verification status)
          final needsActivation = user != null && balance <= 0;

          return Column(
            children: [
              if (needsActivation)
                _ActivationBanner(
                  onBuyTap: () => setState(() => _index = 3), // Wallet tab
                ),
              Expanded(
                child: IndexedStack(index: _index, children: _screens),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: AdaptiveNavigationBar(
        currentIndex: _index,
        destinations: _destinations(context),
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

/* ───────────────────────────────────────────── */
/* ACTIVATION BANNER                             */
/* ───────────────────────────────────────────── */

class _ActivationBanner extends StatelessWidget {
  final VoidCallback onBuyTap;

  const _ActivationBanner({required this.onBuyTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.lock_open, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Buy ROO to unlock posting, commenting, and all platform features."
                  .tr(context),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: onBuyTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Buy ROO'.tr(context),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────────────────────────── */
/* ROOVERSE WEB-PARITY APP BAR                    */
/* ───────────────────────────────────────────── */

class RooverseAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RooverseAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final user = context.watch<UserProvider>().currentUser;
    final isCompact = ResponsiveUtils.isCompact(context);

    return AppBar(
      elevation: 0,
      backgroundColor: colors.surface,
      surfaceTintColor: colors.surface,
      titleSpacing: isCompact ? 8 : 16,
      title: Row(
        children: [
          Text('🛡️'.tr(context), style: TextStyle(fontSize: 22)),
          SizedBox(width: isCompact ? 4 : 8),
          Text(
            isCompact ? 'ROO' : 'ROOVERSE',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: isCompact ? 15 : 18,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        IconTheme(
          data: IconThemeData(size: isCompact ? 20 : 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  final unreadCount = chatProvider.totalUnreadCount;
                  return Badge(
                    label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                    isLabelVisible: unreadCount > 0,
                    child: IconButton(
                      icon: Icon(
                        Icons.chat_bubble_outline,
                        color: colors.onSurface,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChatListScreen(),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              Consumer<NotificationProvider>(
                builder: (context, notificationProvider, child) {
                  return IconButton(
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: colors.onSurface,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  );
                },
              ),
              if (!isCompact)
                IconButton(
                  icon: Icon(
                    themeProvider.isDarkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    color: colors.onSurface,
                  ),
                  onPressed: () => themeProvider.toggleTheme(),
                ),
              Padding(
                padding: EdgeInsets.only(right: isCompact ? 8 : 12),
                child: GestureDetector(
                  onTap: () => _showProfileSheet(context),
                  child: _ProfileAvatar(
                    user: user,
                    colors: colors,
                    radius: isCompact ? 14 : 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/* ───────────────────────────────────────────── */
/* PROFILE AVATAR WITH LOADING FALLBACK          */
/* ───────────────────────────────────────────── */

class _ProfileAvatar extends StatefulWidget {
  final dynamic user;
  final ColorScheme colors;
  final double radius;

  const _ProfileAvatar({
    required this.user,
    required this.colors,
    this.radius = 16,
  });

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  bool _imageLoaded = false;
  bool _imageError = false;

  @override
  Widget build(BuildContext context) {
    // If no avatar URL, show icon only
    if (widget.user?.avatar == null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.colors.surfaceContainerHighest,
        child: Icon(
          Icons.person,
          size: widget.radius + 2,
          color: widget.colors.onSurface,
        ),
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.colors.surfaceContainerHighest,
      child: Stack(
        children: [
          // Fallback icon shown while loading or on error
          if (!_imageLoaded || _imageError)
            Center(
              child: Icon(
                Icons.person,
                size: widget.radius + 2,
                color: widget.colors.onSurface.withOpacity(0.5),
              ),
            ),
          // Actual image
          ClipOval(
            child: Image.network(
              widget.user!.avatar,
              width: widget.radius * 2,
              height: widget.radius * 2,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  // Image loaded successfully
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_imageLoaded) {
                      setState(() => _imageLoaded = true);
                    }
                  });
                  return child;
                }
                // Still loading
                return const SizedBox.shrink();
              },
              errorBuilder: (context, error, stackTrace) {
                // Error loading image
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_imageError) {
                    setState(() => _imageError = true);
                  }
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────────────────────────── */
/* PROFILE MENU (WEB DROPDOWN → MOBILE SHEET)     */
/* ───────────────────────────────────────────── */

void _showProfileSheet(BuildContext parentContext) {
  final colors = Theme.of(parentContext).colorScheme;
  final l10n = AppLocalizations.of(parentContext)!;
  final user = parentContext.read<UserProvider>().currentUser;
  final themeProvider = parentContext.read<ThemeProvider>();

  showModalBottomSheet(
    context: parentContext,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(sheetContext).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Profile header with avatar
              if (user != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final avatarUrl = user.avatar?.trim();
                          if (avatarUrl != null && avatarUrl.isNotEmpty) {
                            Navigator.pop(sheetContext);
                            ProfileImagePreview.show(
                              parentContext,
                              imageUrl: avatarUrl,
                            );
                          }
                        },
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: colors.surfaceContainerHighest,
                          child: user.avatar != null
                              ? ClipOval(
                                  child: Image.network(
                                    user.avatar!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (imageContext, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Icon(
                                            Icons.person,
                                            size: 24,
                                            color: colors.onSurface,
                                          );
                                        },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.person,
                                        size: 24,
                                        color: colors.onSurface,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 24,
                                  color: colors.onSurface,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${user.username}'.tr(parentContext),
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              _ProfileItem(
                icon: Icons.person_outline,
                label: l10n.profile,
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    parentContext,
                    MaterialPageRoute(
                      builder: (_) => const ProfileScreen(showAppBar: true),
                    ),
                  );
                },
              ),
              _ProfileItem(
                icon: Icons.settings_outlined,
                label: l10n.settings,
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    parentContext,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              _ProfileItem(
                icon: themeProvider.isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                label: themeProvider.isDarkMode ? 'Light Mode' : l10n.darkMode,
                onTap: () => themeProvider.toggleTheme(),
              ),
              _ProfileItem(
                icon: Icons.headset_mic,
                label: l10n.contactSupport,
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    parentContext,
                    MaterialPageRoute(
                      builder: (_) => const SupportChatScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 28),
              _ProfileItem(
                icon: Icons.logout,
                label: l10n.logOut,
                destructive: true,
                onTap: () {
                  // Close bottom sheet first
                  Navigator.pop(sheetContext);

                  // Show confirmation dialog
                  showDialog(
                    context: parentContext,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: colors.surface,
                      title: Text(
                        l10n.logOut,
                        style: TextStyle(color: colors.onSurface),
                      ),
                      content: Text(
                        l10n.areYouSureLogOut,
                        style: TextStyle(
                          color: colors.onSurface.withOpacity(0.7),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(l10n.cancel),
                        ),
                        TextButton(
                          onPressed: () async {
                            // Read from a stable ancestor context (not the sheet context).
                            final auth = parentContext.read<AuthProvider>();

                            // Pop the dialog first
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            // Then perform signout
                            // The auth state change will trigger a rebuild,
                            // but we've already captured the reference safely
                            await auth.signOut();
                          },
                          child: Text(
                            l10n.logOut,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = destructive ? colors.error : colors.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
