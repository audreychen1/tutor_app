import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_profile_picture/flutter_profile_picture.dart';
import 'package:google_fonts/google_fonts.dart';

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({Key? key, required this.uid}) : super(key: key);
  final String uid;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  late String userUID = widget.uid;
  String name = "";
  String grade = "";
  List<dynamic> subjects = [];
  String displaySubjects = "";
  var img;
  int numQuestionsAsked = 0;
  int numQuestionsAnswered = 0;
  int numQuestionsAnsweredCorrectly = 0;

  _PublicProfilePageState() {
    getUserInfo();
    getNumQuestionsAndAnswers();
  }

  Future<void> getUserInfo() async {
    var info;
    await FirebaseDatabase.instance.ref().child("User").once().
    then((value) {
      info = value.snapshot.value as Map;
      info.forEach((key, value) {
        setState(() {
          if (key == userUID) {
            name = value["name"];
            grade = value["grade"];
            subjects = value["subjects"];
          }
        });
      });
    }).catchError((error) {
      print("could not get user info " + error.toString());
    });
    try {
      setState(() {
        img = ProfilePicture(
            name: "NAME",
            radius: 31,
            fontsize: 21,
          img: info[userUID]["profilepic"],
        );
      });
    } catch (error) {
      setState(() {
        img = ProfilePicture(
          name: "NAME",
          radius: 31,
          fontsize: 21,
          img: "https://t3.ftcdn.net/jpg/03/46/83/96/360_F_346839683_6nAPzbhpSkIpb8pmAwufkC7c5eD7wYws.jpg",
        );
      });
    }
  }

  //client doesnt have permission to records
  Future<void> getNumQuestionsAndAnswers() async {
    await FirebaseDatabase.instance.ref().child("Records").once().
    then((value) {
      var info = value.snapshot.value as Map;
      info.forEach((key, value) {
        if (key == userUID) {
          setState(() {
            numQuestionsAsked = value["questions asked"].length;
            numQuestionsAnswered = value["answers"].length;
            numQuestionsAnsweredCorrectly = value["correct answers"].length;
          });
        }
      });
    }).catchError((error) {
      print("could not get this info " + error.toString());
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (subjects.isNotEmpty) {
      displaySubjects = subjects[0];
      for (var i = 1; i < subjects.length; i++) {
        displaySubjects = displaySubjects + ", " + subjects[i];
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            name,
          style: GoogleFonts.notoSans(
            textStyle: TextStyle(
              fontSize: 29,
            ),
          ),
        ),
        backgroundColor: Color.fromRGBO(167, 190, 169, 1),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 25,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Container(
                    height: MediaQuery.of(context).size.width * 0.25,
                    width: MediaQuery.of(context).size.width * 0.25,
                    child: img,
                  ),
                ),
                Placeholder(
                  fallbackWidth: 20,
                  color: Colors.transparent,
                ),
                Column(
                  children: [
                    Placeholder(
                      fallbackHeight: 45,
                      fallbackWidth: 20,
                      color: Colors.transparent,
                    ),
                    Row(
                      children: [
                        Column(
                          children: [
                            Text(
                              grade,
                              style: GoogleFonts.notoSans(
                                textStyle:TextStyle(
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            Text(
                              "Grade",
                              style: GoogleFonts.notoSans(
                                textStyle:TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Placeholder(
                          fallbackWidth: 20,
                          fallbackHeight: 20,
                          color: Colors.transparent,
                        ),
                        Column(
                          children: [
                            Text(
                              "1/2/23",
                              style: GoogleFonts.notoSans(
                                textStyle:TextStyle(
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            Text(
                              "Joined",
                              style: GoogleFonts.notoSans(
                                textStyle:TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(flex: 15, child: Container()),
                    Expanded(
                      flex: 85,
                      child: ListTile(
                        title: const Text(
                          "Volunteer Hours",
                          style: TextStyle(
                            fontSize: 15,
                            color: Color.fromRGBO(163, 163, 163, 1),
                          ),
                        ),
                        subtitle: Text(
                          "5",
                          style: TextStyle(
                            fontSize: 21,
                            color: Colors.black,
                          ),
                        ),
                        leading: IconButton(
                          icon: const Icon(Icons.volunteer_activism),
                          onPressed: (){},
                          color: Color.fromRGBO(224, 224, 221, 1),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Container(), flex: 15),
                    Expanded(
                      flex: 85,
                      child: ListTile(
                        title: const Text(
                          "Interests",
                          style: TextStyle(
                            fontSize: 15,
                            color: Color.fromRGBO(163, 163, 163, 1),
                          ),
                        ),
                        subtitle: Text(
                          displaySubjects,
                          style: TextStyle(
                            fontSize: 21,
                            color: Colors.black,
                          ),
                        ),
                        leading: IconButton(
                          icon: const Icon(Icons.menu_book_sharp),
                          onPressed: (){},
                          color: Color.fromRGBO(167, 190, 169, 1),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Container(), flex: 15),
                    Expanded(
                      flex: 85,
                      child: ListTile(
                        title: const Text(
                          "Questions Asked",
                          style: TextStyle(
                            fontSize: 15,
                            color: Color.fromRGBO(163, 163, 163, 1),
                          ),
                        ),
                        subtitle: Text(
                          numQuestionsAsked.toString(),
                          style: TextStyle(
                            fontSize: 21,
                            color: Colors.black,
                          ),
                        ),
                        leading: IconButton(
                          icon: const Icon(Icons.question_mark_sharp),
                          onPressed: (){},
                          color: Color.fromRGBO(132, 169, 140, 1),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Container(), flex: 15),
                    Expanded(
                      flex: 85,
                      child: ListTile(
                        title: const Text(
                          "Questions Answered",
                          style: TextStyle(
                            fontSize: 15,
                            color: Color.fromRGBO(163, 163, 163, 1),
                          ),
                        ),
                        subtitle: Text(
                          numQuestionsAnswered.toString(),
                          style: TextStyle(
                            fontSize: 21,
                            color: Colors.black,
                          ),
                        ),
                        leading: IconButton(
                          icon: const Icon(Icons.question_answer),
                          onPressed: (){},
                          color: Color.fromRGBO(82, 121, 111, 1),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Container(), flex: 15),
                    Expanded(
                      flex: 85,
                      child: ListTile(
                        title: const Text(
                          "Correct Answers",
                          style: TextStyle(
                            fontSize: 15,
                            color: Color.fromRGBO(163, 163, 163, 1),
                          ),
                        ),
                        subtitle: Text(
                          numQuestionsAnsweredCorrectly.toString(),
                          style: TextStyle(
                            fontSize: 21,
                            color: Colors.black,
                          ),
                        ),
                        leading: IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: (){},
                          color: Color.fromRGBO(53, 79, 82, 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
