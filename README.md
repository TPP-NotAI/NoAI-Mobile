# NoAI App

A modern Flutter application demonstrating best practices for building cross-platform mobile applications with clean architecture, state management, and API integration.

## Features

- **Posts Management**: Browse, view, and interact with posts
- **User Directory**: View user profiles and their associated posts
- **Dark Mode**: Toggle between light and dark themes with persistent storage
- **State Management**: Provider pattern for efficient state management
- **API Integration**: RESTful API integration with JSONPlaceholder
- **Responsive Design**: Material Design 3 with modern UI components
- **Error Handling**: Comprehensive error handling with user-friendly messages
- **Local Storage**: Persistent settings storage using SharedPreferences

## Screenshots

The app includes three main screens accessible via bottom navigation:
- **Posts Screen**: Displays all posts with pull-to-refresh functionality
- **Users Screen**: Shows all users with their profile information
- **Settings Screen**: Theme toggle and app information

## Architecture

The project follows a clean architecture pattern with separation of concerns:

```
lib/
├── config/           # App-wide configuration and constants
│   ├── app_constants.dart
│   └── app_router.dart
├── models/           # Data models with JSON serialization
│   ├── post.dart
│   ├── post.g.dart
│   ├── user.dart
│   └── user.g.dart
├── providers/        # State management (Provider pattern)
│   ├── post_provider.dart
│   ├── theme_provider.dart
│   └── user_provider.dart
├── screens/          # UI screens
│   ├── home_screen.dart
│   ├── post_detail_screen.dart
│   ├── settings_screen.dart
│   ├── user_detail_screen.dart
│   └── users_screen.dart
├── services/         # Business logic and API services
│   ├── api_service.dart
│   └── storage_service.dart
├── utils/            # Utility functions and validators
│   ├── date_utils.dart
│   └── validators.dart
├── widgets/          # Reusable widget components
│   ├── error_widget.dart
│   ├── loading_widget.dart
│   ├── post_card.dart
│   └── user_card.dart
└── main.dart         # App entry point
```

## Dependencies

### Core Dependencies
- **flutter**: Flutter SDK
- **provider**: State management solution (^6.1.1)
- **http**: HTTP client for API calls (^1.2.0)
- **shared_preferences**: Local storage (^2.2.2)
- **go_router**: Declarative routing (^14.6.2)

### JSON & Serialization
- **json_annotation**: JSON serialization annotations (^4.8.1)
- **build_runner**: Code generation (^2.4.8)
- **json_serializable**: JSON serialization code generator (^6.7.1)

### UI Enhancements
- **flutter_svg**: SVG rendering support (^2.0.9)
- **cached_network_image**: Optimized image loading (^3.3.1)
- **shimmer**: Loading skeleton effect (^3.0.0)

### Utilities
- **intl**: Internationalization and date formatting (^0.19.0)
- **uuid**: UUID generation (^4.3.3)
- **cupertino_icons**: iOS-style icons (^1.0.8)

## Getting Started

### Prerequisites

- Flutter SDK (3.18.0 or higher)
- Dart SDK (3.9.2 or higher)
- An IDE (VS Code, Android Studio, or IntelliJ IDEA)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd noai
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate JSON serialization code:
```bash
dart run build_runner build --delete-conflicting-outputs
```

4. Run the app:
```bash
flutter run
```

### Platform-Specific Setup

#### Android
```bash
flutter run -d android
```

#### iOS
```bash
flutter run -d ios
```

#### Web
```bash
flutter run -d chrome
```

#### Windows
```bash
flutter run -d windows
```

#### macOS
```bash
flutter run -d macos
```

#### Linux
```bash
flutter run -d linux
```

## API Integration

The app uses [JSONPlaceholder](https://jsonplaceholder.typicode.com/) as a free fake REST API for testing and prototyping.

### Available Endpoints:
- `GET /posts` - Fetch all posts
- `GET /posts/{id}` - Fetch a single post
- `GET /posts?userId={userId}` - Fetch posts by user
- `GET /users` - Fetch all users
- `GET /users/{id}` - Fetch a single user
- `POST /posts` - Create a new post
- `PUT /posts/{id}` - Update a post
- `DELETE /posts/{id}` - Delete a post

## State Management

The app uses the **Provider** pattern for state management:

- **PostProvider**: Manages posts state (fetching, creating, updating, deleting)
- **UserProvider**: Manages users state and current user
- **ThemeProvider**: Manages theme state with persistent storage

## Code Generation

The project uses code generation for JSON serialization:

```bash
# Watch for changes and automatically generate code
dart run build_runner watch

# Generate code once
dart run build_runner build

# Generate code and delete conflicting outputs
dart run build_runner build --delete-conflicting-outputs
```

## Testing

Run tests using:
```bash
flutter test
```

## Building for Production

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

### Windows
```bash
flutter build windows --release
```

### macOS
```bash
flutter build macos --release
```

### Linux
```bash
flutter build linux --release
```

## Project Structure Explanation

### Models
Data classes with JSON serialization support using `json_annotation` and code generation.

### Providers
ChangeNotifier classes that manage state and notify listeners when data changes.

### Services
Business logic layer that handles API calls, local storage, and other services.

### Screens
Full-page widgets representing different screens in the app.

### Widgets
Reusable UI components used across multiple screens.

### Utils
Helper functions and utilities for common tasks like validation and date formatting.

### Config
App-wide configuration including constants, routes, and theme settings.

## Key Features Implementation

### Pull-to-Refresh
All list screens support pull-to-refresh functionality for manual data updates.

### Error Handling
Comprehensive error handling with user-friendly error messages and retry functionality.

### Loading States
Loading indicators displayed while fetching data from the API.

### Dark Mode
Theme toggle with persistent storage using SharedPreferences.

### Navigation
Bottom navigation bar for easy access to main screens.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Provider Package](https://pub.dev/packages/provider)
- [JSONPlaceholder API](https://jsonplaceholder.typicode.com/)
- [Material Design 3](https://m3.material.io/)

## Support

For issues and questions, please open an issue in the GitHub repository.
