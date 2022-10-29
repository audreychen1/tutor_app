import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:tutor_app/ask_question.dart';
import 'package:tutor_app/profile.dart';
import 'package:tutor_app/signup.dart';
class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  TextEditingController emailController = new TextEditingController();
  TextEditingController passwordController = new TextEditingController();

  Future<void> login() async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text
    ).then((value) {
      print("Logged in user");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Profile()),
      );
      //transition to dashboard
    }).catchError((error) {
      print("Could not sign the user in: " + error.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Login"),
      ),
      body: Column(
        children: [
          TextField(
            controller: emailController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: "Email",
            ),
          ),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: "Password",
            ),
          ),
          ElevatedButton(
              onPressed: () {
                login();
              },
              child: Text("Login"),
          ),
          ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Signup()),
                );
              },
              child: Text("Signup"),
          ),
        ],
      ),
    );
  }
}
