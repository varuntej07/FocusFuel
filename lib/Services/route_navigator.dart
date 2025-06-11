import 'package:flutter/material.dart';
import 'package:focus_fuel/Views/Auth/login_page.dart';
import 'package:focus_fuel/Views/screens/chat_screen.dart';
import 'package:focus_fuel/Views/screens/main_scaffold.dart';

class RouteNavigator{
  static Route<dynamic> routeGenerator(RouteSettings settings){
    switch(settings.name){
      case '/':
        return MaterialPageRoute(builder: (context) => const HomePage());
      case '/login':
        return MaterialPageRoute(builder: (context) => const Login());
      case '/chat':
        return MaterialPageRoute(builder: (context) => ChatScreen());
      default:
        return _errorRoute();
    }
}

static Route<dynamic> _errorRoute() {
  return MaterialPageRoute(builder: (context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Err420 No page found, chill",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.deepOrange),
          ),
          Center(
            child: Text(
              "No chats found as of now yet, hold on!!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          )
        ],
      ),
    );
  });
  }
}