import 'package:chitchat/screens/personal_chat_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

class PersonalChatButton extends StatelessWidget {
  final double iconSize;
  final Color iconColor;
  final double rightPadding;

  const PersonalChatButton({
    Key? key,
    this.iconSize = 26,
    this.iconColor = Colors.white,
    this.rightPadding = 8,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.messenger_outline_rounded),
      iconSize: iconSize,
      color: iconColor,
      padding: EdgeInsets.only(right: rightPadding),
      tooltip: 'Personal Chats',
      onPressed: () {
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.rightToLeft,
            child: const PersonalChatListScreen(),
          ),
        );
      },
    );
  }
}
