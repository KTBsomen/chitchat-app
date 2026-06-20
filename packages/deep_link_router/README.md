# Deep Link Router for Flutter

A powerful, extensible deep link handler for Flutter apps supporting:

- ✅ App Links (Android)
- ✅ Universal Links (iOS)
- ✅ Install Referrer fallback (Android cold installs)
- ✅ Clipboard fallback (iOS cold installs)
- ✅ Custom path, query, or subdomain route matching
- ✅ Delayed redirection after registration/login

---

## 🚀 Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  deep_link_router: ^0.0.2

```

---

## 🔧 Platform Setup

### ✅ Android Setup

1. **AndroidManifest.xml**

```xml
<activity ...>
  <meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
  <intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="yourapp.com" android:pathPrefix="/" />
  </intent-filter>
</activity>
```

2. **assetlinks.json** (script provided below)

Upload to:
```
https://yourapp.com/.well-known/assetlinks.json
```

### 🍎 iOS Setup

1. **Enable Associated Domains**:

In Xcode → Target → Signing & Capabilities → Add `Associated Domains`:
```
applinks:yourapp.com
```

2. **apple-app-site-association** (script below)

Upload to:
```
https://yourapp.com/.well-known/apple-app-site-association
```
No `.json` extension. Must be served as `application/json`.

---

## 🔌 Usage

### 1. Define your routes

```dart
import 'package:deep_link_router/deep_link_router.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
     MaterialApp(
      navigatorKey: navigatorKey, 
      home: LoginScreen()
      )
     );
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = false;
  bool showSplashScreen = true;

  void setLoading(bool loading) {
    setState(() {
      isLoading = loading;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    DeepLinkRouter.instance.configure(routes: [
      // Match /join?group=abc
      DeepLinkRoute(
        matcher: (uri) =>
            uri.path == '/join' && uri.queryParameters.containsKey('group'),
        handler: (context, uri) async {
          try {
            final groupId = uri.queryParameters['group']!;

            print("Navigating to GroupPublicViewScreen with groupId: $groupId");
            navigatorKey.currentState?.push(MaterialPageRoute(
              builder: (_) => GroupPublicViewScreen(groupId: groupId),
            ));
            return true;
          } catch (e) {
            return false;
          }
        },
      ),
    ]);

    DeepLinkRouter.instance.initialize(context);
    UserService.isLoggedIn().then((value) async {
      if (value) {
  
        Uri? pendingLink = await DeepLinkRouter.getPendingDeepLink();
        print("Pending Link: $pendingLink");
        if (pendingLink != null) {
          await DeepLinkRouter.completePendingNavigation(context);
        } else {
          Future.delayed(Duration(seconds: 2), () {
            Navigator.pushReplacement(
                context,
                PageTransition(
                    isIos: true,
                    type: PageTransitionType.leftToRight,
                    child: HomePage()));
          });
        }
      } else {
        setState(() {
          showSplashScreen = false;
        });
      }
    });
  }
}
/// build method here
```

### 3. After registration/login

```dart
await deepLinkRouter.completePendingNavigation(context);
```

---
## Get SHA Fingerprint
### 📱 Android
```bash
cd android
gradlew signingReport
```
## 📂 CLI Scripts to Generate Hosting Files

### ✅ Bash (Linux/macOS): `generate-links.sh`

```bash
#!/bin/bash
mkdir -p .well-known

# Android: assetlinks.json
cat <<EOF > .well-known/assetlinks.json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.app",
      "sha256_cert_fingerprints": [
        "YOUR:SHA:256:FINGERPRINT"
      ]
    }
  }
]
EOF

echo "Generated .well-known/assetlinks.json"

# iOS: apple-app-site-association
cat <<EOF > .well-known/apple-app-site-association
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "YOURTEAMID.com.example.app",
        "paths": ["/*"]
      }
    ]
  }
}
EOF

echo "Generated .well-known/apple-app-site-association"
```

Make it executable:
```bash
chmod +x generate-links.sh
./generate-links.sh
```

---

### ✅ Windows: `generate-links.bat`

```bat
@echo off
mkdir .well-known

:: assetlinks.json
echo [ > .well-known\assetlinks.json
echo   { >> .well-known\assetlinks.json
echo     "relation": ["delegate_permission/common.handle_all_urls"], >> .well-known\assetlinks.json
echo     "target": { >> .well-known\assetlinks.json
echo       "namespace": "android_app", >> .well-known\assetlinks.json
echo       "package_name": "com.example.app", >> .well-known\assetlinks.json
echo       "sha256_cert_fingerprints": [ >> .well-known\assetlinks.json
echo         "YOUR:SHA:256:FINGERPRINT" >> .well-known\assetlinks.json
echo       ] >> .well-known\assetlinks.json
echo     } >> .well-known\assetlinks.json
echo   } >> .well-known\assetlinks.json
echo ] >> .well-known\assetlinks.json

echo Generated .well-known\assetlinks.json

:: apple-app-site-association
echo { > .well-known\apple-app-site-association
echo   "applinks": { >> .well-known\apple-app-site-association
echo     "apps": [], >> .well-known\apple-app-site-association
echo     "details": [ >> .well-known\apple-app-site-association
echo       { >> .well-known\apple-app-site-association
echo         "appID": "YOURTEAMID.com.example.app", >> .well-known\apple-app-site-association
echo         "paths": ["/*"] >> .well-known\apple-app-site-association
echo       } >> .well-known\apple-app-site-association
echo     ] >> .well-known\apple-app-site-association
echo   } >> .well-known\apple-app-site-association
echo } >> .well-known\apple-app-site-association

echo Generated .well-known\apple-app-site-association
```

Run with:
```cmd
generate-links.bat
```

---

## 📚 Advanced Features (Planned)

- DSL route builder (`r.path('/join', query: 'group', to: ...)`)
- Subdomain & wildcard matchers
- Redirect logging or analytics
- Navigator 2.0 and go_router integration

---

## 📣 Contributions Welcome

Feel free to contribute via PR or raise an issue for enhancements.

---

## 📄 License

AGPL-3.0 license © 2025 somen das
