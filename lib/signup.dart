import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:multiselect/multiselect.dart';
import 'package:tutor_app/helper.dart';
import 'package:tutor_app/profile.dart';

import 'ask_question.dart';
import 'login.dart';

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
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: EdgeInsets.only(top: 100),
        child: Column(
          children: [
            Padding(padding: EdgeInsets.only(bottom: 15.0), child: Text("Signup", style: GoogleFonts.notoSans(textStyle: TextStyle(fontSize: 30,)),)),
            Padding(
              padding: EdgeInsets.only(left: 15.0, right: 15.0, bottom: 10.0),
              child: Container(
                decoration: BoxDecoration(
                  //borderRadius: BorderRadius.circular(10.0),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Color.fromRGBO(167, 190, 169, 1), blurRadius: 20.0, offset: Offset(10, 10)),
                  ],
                ),
                child: TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Email",
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 15.0, right: 15.0, bottom: 10.0),
              child: Container(
                decoration: BoxDecoration(
                  //borderRadius: BorderRadius.circular(10.0),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Color.fromRGBO(167, 190, 169, 1), blurRadius: 20.0, offset: Offset(10, 10)),
                  ],
                ),
                child: TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Password",
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 15.0, right: 15.0, bottom: 10.0),
              child: Container(
                decoration: BoxDecoration(
                  //borderRadius: BorderRadius.circular(10.0),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Color.fromRGBO(167, 190, 169, 1), blurRadius: 20.0, offset: Offset(10, 10)),
                  ],
                ),
                child: TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Name",
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 15.0, right: 15.0, bottom: 10.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Color.fromRGBO(167, 190, 169, 1), blurRadius: 20.0, offset: Offset(10, 10)),
                  ],
                ),
                child: TextField(
                  controller: gradeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Grade",
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 15.0, right: 15.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Color.fromRGBO(167, 190, 169, 1), blurRadius: 20.0, offset: Offset(10, 10)),
                  ],
                ),
                child: DropDownMultiSelect(
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
              ),
            ),
            Stack(
              children: [
                Positioned(
                  child: Container(
                    height: 300,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/signup_banner.png'),
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 20.0, left: 15.0, right: 15.0),
                      child: GestureDetector(
                        onTap: () {
                          signUpUser();
                        },
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            gradient: LinearGradient(
                              colors: [
                                Color.fromRGBO(132, 169, 140, 1),
                                Color.fromRGBO(202, 210, 197, 1),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text("Signup"),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 10.0, left: 15.0, right: 15.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => Login()),
                          );
                        },
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            gradient: LinearGradient(
                              colors: [
                                Color.fromRGBO(132, 169, 140, 1),
                                Color.fromRGBO(202, 210, 197, 1),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text("Login"),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
