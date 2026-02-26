import 'dart:async';

import 'package:chitchat/appstate/storyPrefs.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/comments.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/admin.dart';
import 'package:chitchat/screens/createStory.dart';
import 'package:chitchat/services/fcm.dart';
import 'package:chitchat/services/notification.dart';
import 'package:chitchat/services/userOnline.dart';
import 'package:flutter/material.dart';
import 'package:chitchat/services/user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:page_transition/page_transition.dart';
import 'firebase_options.dart';
import 'screens/groupPublic.dart';
import 'screens/home.dart';
import 'screens/register.dart';
import 'package:oktoast/oktoast.dart';
import 'package:deep_link_router/deep_link_router.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/chat.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FCMHandler.initialize();
  await StoryPrefs.init();
  runApp(OKToast(
      child: MaterialApp(navigatorKey: navigatorKey, home: LoginScreen())));
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
    super.initState();
    DeepLinkRouter.instance.configure(routes: [
      DeepLinkRoute(
        matcher: (uri) =>
            uri.path == '/join' && uri.queryParameters.containsKey('group'),
        handler: (context, uri) async {
          try {
            final groupId = uri.queryParameters['group']!;
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
    try {
      DeepLinkRouter.instance.initialize(context);
    } catch (e) {
      print("DeepLinkRouter initialization error: $e");
    }

    AppVariables.update('baseurl', 'https://5xlxdw5g-3000.inc1.devtunnels.ms');

    UserService.isLoggedIn().then((value) async {
      if (value) {
        await UserService.refreshFCMToken();
        Map<String, dynamic> result = await UserService.fetchMyProfile();
        if (result['success']) {
          if (result['group'] != null && mounted) {
            FriendCircleGroup myGroup = result['group'] as FriendCircleGroup;
            await NotificationService.getGroupJoinRequests(
                context, myGroup.groupId,
                showLoaders: false, showMessage: false);
          }
          await PresenceManager().init();
        } else {
          await UserService.signOut((x) => {});
          setState(() { showSplashScreen = false; });
          return;
        }
        Uri? pendingLink = await DeepLinkRouter.getPendingDeepLink();
        if (pendingLink != null) {
          await DeepLinkRouter.completePendingNavigation(context);
        } else {
          Navigator.pushReplacement(context,
              PageTransition(isIos: true, type: PageTransitionType.leftToRight, child: HomePage()));
        }
      } else {
        setState(() { showSplashScreen = false; });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return showSplashScreen
        ? Scaffold(
            backgroundColor: const Color(0xFF01021D),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', width: 200, height: 200),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ],
              ),
            ),
          )
        : Scaffold(
            backgroundColor: const Color(0xFF01021D),
            body: SafeArea(
              child: Stack(
                children: [
                  OnboardingScreen(
                    onGoogleLogin: isLoading
                        ? null
                        : () {
                            UserService.signInWithGoogle(setLoading).then((_) {
                              UserService.isLoggedIn().then((value) {
                                if (value) {
                                  setState(() => showSplashScreen = true);
                                  Future.delayed(Duration(seconds: 1), () {
                                    Navigator.pushReplacement(context,
                                        PageTransition(isIos: true, type: PageTransitionType.leftToRight, child: HomePage()));
                                  });
                                } else {
                                  setState(() => showSplashScreen = false);
                                  Navigator.pushReplacement(context,
                                      PageTransition(isIos: true, type: PageTransitionType.leftToRight, child: RegistrationScreen()));
                                }
                              });
                            }).catchError((error) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Sign-In Error'),
                                  content: Text('Failed to sign in with Google: $error'),
                                  actions: [
                                    TextButton(child: Text('OK'), onPressed: () => Navigator.of(context).pop()),
                                  ],
                                ),
                              );
                            });
                          },
                    onAdminLogin: () {
                      Navigator.push(context,
                          PageTransition(isIos: true, type: PageTransitionType.leftToRight, child: AdminLoginPage()));
                    },
                  ),
                  if (isLoading)
                    Container(
                      color: Colors.white,
                      child: Center(
                        child: Image.asset("assets/images/loginAni.gif",
                            fit: BoxFit.contain, filterQuality: FilterQuality.high),
                      ),
                    ),
                ],
              ),
            ),
          );
  }
}

// ─────────────────────────────────────────────
//  ONBOARDING SCREEN
// ─────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onGoogleLogin;
  final VoidCallback onAdminLogin;

  const OnboardingScreen({Key? key, required this.onGoogleLogin, required this.onAdminLogin}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: const [_Slide1(), _Slide2(), _Slide3(), _Slide4(), _Slide5()],
          ),
        ),
        const SizedBox(height: 12),
        _DotIndicator(count: 5, current: _currentPage),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50.0),
          child: ElevatedButton(
            onPressed: widget.onGoogleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E90FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              minimumSize: const Size(double.infinity, 54),
              elevation: 5,
            ),
            child: const Text('login with google',
                style: TextStyle(color: Colors.white, fontSize: 22, fontFamily: 'PassionOne', letterSpacing: 0.5)),
          ),
        ),
        TextButton(
          onPressed: widget.onAdminLogin,
          child: const Text('Admin Login',
              style: TextStyle(color: Colors.white54, fontSize: 14, fontFamily: 'Poppins')),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  DOT INDICATOR
// ─────────────────────────────────────────────
class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  const _DotIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        bool active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white38,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
//  LOGO HEADER
// ─────────────────────────────────────────────
class _LogoHeader extends StatelessWidget {
  const _LogoHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 38, height: 38),
          const SizedBox(width: 10),
          const Text('chitchat',
              style: TextStyle(
                  color: Colors.white, fontSize: 26, fontFamily: 'PassionOne', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SLIDE 1
// ─────────────────────────────────────────────
class _Slide1 extends StatelessWidget {
  const _Slide1();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF01021D),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _LogoHeader(),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text('" Ur college\'s virtual hangout "',
                style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('make college life ', style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Poppins')),
                Text('⚡', style: TextStyle(fontSize: 15)),
                Text(' more interesting', style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Poppins')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/images/onboarding1.png', fit: BoxFit.cover, width: double.infinity),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SLIDE 2 — Full image (already has bg + content)
// ─────────────────────────────────────────────
class _Slide2 extends StatelessWidget {
  const _Slide2();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset('assets/images/onboarding2.png', fit: BoxFit.cover),
    );
  }
}

// ─────────────────────────────────────────────
//  SLIDE 3 — Full image (already has bg + content)
// ─────────────────────────────────────────────
class _Slide3 extends StatelessWidget {
  const _Slide3();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset('assets/images/onboarding3.png', fit: BoxFit.cover),
    );
  }
}

// ─────────────────────────────────────────────
//  SLIDE 4
// ─────────────────────────────────────────────
class _Slide4 extends StatelessWidget {
  const _Slide4();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF01021D),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LogoHeader(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: const [
              Text('Ur College ', style: TextStyle(color: Colors.white, fontSize: 22, fontFamily: 'PassionOne', fontWeight: FontWeight.bold)),
              Text('⚡', style: TextStyle(fontSize: 22)),
              Text(' Ur Domain', style: TextStyle(color: Colors.white, fontSize: 22, fontFamily: 'PassionOne', fontWeight: FontWeight.bold)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('explore other networks in ur college',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Poppins')),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Image.asset('assets/images/onboarding4.png', fit: BoxFit.contain, width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SLIDE 5 — chitz
// ─────────────────────────────────────────────
class _Slide5 extends StatelessWidget {
  const _Slide5();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF01021D),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LogoHeader(),
          const SizedBox(height: 28),
          const Text('chitz',
              style: TextStyle(color: Colors.white, fontSize: 42, fontFamily: 'PassionOne', fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _BorderedAvatar(imagePath: 'assets/images/onboarding5_1.png', name: 'dhruv', borderColor: Color(0xFFFF4444)),
              _BorderedAvatar(imagePath: 'assets/images/onboarding5_2.png', name: 'riya', borderColor: Color(0xFF44DD44)),
              _BorderedAvatar(imagePath: 'assets/images/onboarding5_3.png', name: 'shruti', borderColor: Color(0xFFFFD700)),
              _BorderedAvatar(imagePath: 'assets/images/onboarding5_4.png', name: 'ayan', borderColor: Color(0xFF44DD44)),
            ],
          ),
          const SizedBox(height: 36),
          const _BulletPoint(dotColor: Color(0xFF44DD44), text: 'Send to specific friends with a green border indicator'),
          const SizedBox(height: 18),
          const _BulletPoint(dotColor: Color(0xFFFFD700), text: 'Share with multiple friends with a yellow border'),
          const SizedBox(height: 18),
          const _BulletPoint(dotColor: Color(0xFFFF4444), text: 'Send to everyone in your college with a red border'),
          const Spacer(),
        ],
      ),
    );
  }
}

class _BorderedAvatar extends StatelessWidget {
  final String imagePath;
  final String name;
  final Color borderColor;

  const _BorderedAvatar({required this.imagePath, required this.name, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: 3)),
          child: ClipOval(
            child: Image.asset(imagePath, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1a1a4e),
                    child: const Icon(Icons.person, color: Colors.white54, size: 34))),
          ),
        ),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Poppins')),
      ],
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final Color dotColor;
  final String text;
  const _BulletPoint({required this.dotColor, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            margin: const EdgeInsets.only(top: 5),
            width: 10, height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Poppins', height: 1.4)),
        ),
      ],
    );
  }
}
