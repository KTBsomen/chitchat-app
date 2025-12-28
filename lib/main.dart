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
    try {
      DeepLinkRouter.instance.initialize(context);
    } catch (e) {
      print("DeepLinkRouter initialization error: $e");
    }
    AppVariables.update('baseurl', 'https://chitzchat.com/api/v1');
    // AppVariables.update('baseurl', 'https://5xlxdw5g-3000.inc1.devtunnels.ms');

    ///https://chitzchat.com/api/v1
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
          setState(() {
            showSplashScreen = false;
          });
          return;
        }
        Uri? pendingLink = await DeepLinkRouter.getPendingDeepLink();
        print("Pending Link: $pendingLink");
        if (pendingLink != null) {
          await DeepLinkRouter.completePendingNavigation(context);
        } else {
          Navigator.pushReplacement(
              context,
              PageTransition(
                  isIos: true,
                  type: PageTransitionType.leftToRight,
                  child: HomePage()));
        }
      } else {
        setState(() {
          showSplashScreen = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return showSplashScreen
        ? Scaffold(
            backgroundColor: const Color.fromARGB(255, 12, 12, 38),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/all.png',
                    width: 200,
                    height: 200,
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ],
              ),
            ),
          )
        : Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Chitchat with your friend circle',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(236, 255, 255, 255),
                            fontFamily: 'PassionOne',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Image.asset(
                        'assets/images/all.png',
                        height: 300,
                        colorBlendMode: BlendMode.color,
                        width: MediaQuery.of(context).size.width + 20,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                          'Become a hero',
                          style: TextStyle(
                              fontSize: 25,
                              fontFamily: "PassionOne",
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 255, 255, 255)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                          'Be the center of attention, create your own story, connect with your closest ones, and share your experiences with the world.',
                          style: TextStyle(
                            color: Color.fromARGB(255, 174, 174, 183),
                            fontSize: 15,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      ),
                      Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 50.0),
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      UserService.signInWithGoogle(setLoading)
                                          .then((_) {
                                        UserService.isLoggedIn().then((value) {
                                          if (value) {
                                            setState(() {
                                              showSplashScreen = true;
                                            });
                                            Future.delayed(Duration(seconds: 1),
                                                () {
                                              Navigator.pushReplacement(
                                                  context,
                                                  PageTransition(
                                                      isIos: true,
                                                      type: PageTransitionType
                                                          .leftToRight,
                                                      child: HomePage()));
                                            });
                                          } else {
                                            setState(() {
                                              showSplashScreen = false;
                                            });
                                            Navigator.pushReplacement(
                                              context,
                                              PageTransition(
                                                  isIos: true,
                                                  type: PageTransitionType
                                                      .leftToRight,
                                                  child: RegistrationScreen()),
                                            );
                                          }
                                        });
                                      }).catchError((error) {
                                        // Handle sign-in errors
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('Sign-In Error'),
                                            content: Text(
                                                'Failed to sign in with Google: $error'),
                                            actions: <Widget>[
                                              TextButton(
                                                child: Text('OK'),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      });
                                    },
                              style: ButtonStyle(
                                padding:
                                    WidgetStateProperty.all(EdgeInsets.zero),
                                shape: WidgetStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                shadowColor: WidgetStateProperty.all(
                                    Color.fromARGB(38, 0, 0, 0)),
                                elevation: WidgetStateProperty.all(5),
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  // gradient: const LinearGradient(
                                  //   colors: [
                                  //     Color(0xFFFF671F),
                                  //     Colors.white,
                                  //     Color(0xFF046A38)
                                  //   ],
                                  //   transform: GradientRotation(760 * 180 / 3.14),
                                  // ),
                                  borderRadius: BorderRadius.circular(35),
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  constraints: const BoxConstraints(
                                    minWidth: 100,
                                    minHeight: 50,
                                  ),
                                  child: Text(
                                    'Login with Google',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFFFFFFF),
                                      fontSize: 30,
                                      fontFamily: 'PassionOne',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 30,
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                PageTransition(
                                  isIos: true,
                                  type: PageTransitionType.leftToRight,
                                  child: AdminLoginPage(),
                                ),
                              );
                            },
                            child: Text(
                              'Admin Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (isLoading)
                    Container(
                      color: Colors.white,
                      child: Center(
                        child: Image.asset(
                          "assets/images/loginAni.gif",
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
  }
}
