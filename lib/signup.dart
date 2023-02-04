import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:multiselect/multiselect.dart';
import 'package:tutor_app/helper.dart';
import 'package:tutor_app/profile.dart';

import 'ask_question.dart';

class Signup extends StatefulWidget {
  const Signup({Key? key}) : super(key: key);

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  TextEditingController emailController = new TextEditingController();
  TextEditingController passwordController = new TextEditingController();
  TextEditingController nameController = new TextEditingController();
  TextEditingController gradeController = new TextEditingController();
  List<String> subjects = [];

  Future<void> signUpUser() async {
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
    ).then((value) async {
      print("Signed up user");
      await FirebaseDatabase.instance.ref().child("User").child(getUID()).set({
        "name" : nameController.text,
        "grade" : gradeController.text,
        "subjects" : subjects
      }).then((value) {
        print("Set up profile info");
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => Profile()),
        );
        //navigate to dashboard
      }).catchError((error) {
        print("Could not set up profile info" + error.toString());
      });
    }).catchError((onError) {
      print("We couldn't sign you up" + onError.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Sign Up"),
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
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: "Name",
            ),
          ),
          TextField(
            controller: gradeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: "Grade",
            ),
          ),
          DropDownMultiSelect(
              whenEmpty: "Subjects",
              options: ["Math", "Science", "Language", "History", "English"],
              selectedValues: subjects,
              onChanged: (List<String> x) {
                setState(() {
                  subjects  = x;
                  //messaging.subscribeToTopic
                  subjects.forEach((element) {
                    FirebaseMessaging.instance.subscribeToTopic(element);
                  });
                });
              }
          ),
          ElevatedButton(
            onPressed: () {
              signUpUser();
            },
            child: Text("Sign Up"),
          ),
        ],
      ),
    );
  }
}
