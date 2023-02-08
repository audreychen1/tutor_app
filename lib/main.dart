import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tutor_app/login.dart';
import 'firebase_options.dart';

Future<void> messageHandler(RemoteMessage message) async {
  print("background message ${message.notification!.body}");
}

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(messageHandler);
  //["Math", "Science", "Language", "History", "English"]

  FirebaseMessaging.instance.getToken().then((value) {
    print(value);
  });

  FirebaseMessaging.onMessage.listen((event) {
    print(event.notification!.body);
  });
  FirebaseMessaging.onMessageOpenedApp.listen((event) {
    print("on message");
  });

  //FirebaseMessaging.instance.subscribeToTopic("Science");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Login()
    );
  }
}
