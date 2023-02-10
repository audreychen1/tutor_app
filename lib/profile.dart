import 'dart:convert';
import 'dart:io';
import 'package:bs_flutter_selectbox/bs_flutter_selectbox.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_profile_picture/flutter_profile_picture.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multiselect/multiselect.dart';
import 'package:tutor_app/helper.dart';
import 'package:tutor_app/history.dart';
import 'package:tutor_app/questions.dart';
import 'package:tutor_app/settings.dart';
import 'package:tutor_app/support_page.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

import 'login.dart';

class Profile extends StatefulWidget {
  const Profile({Key? key}) : super(key: key);

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  BsSelectBoxController subController = new BsSelectBoxController(options: [
    BsSelectBoxOption(value: "Science", text: Text("Science")),
    BsSelectBoxOption(value: "Math", text: Text("Math")),
  ]);
  TextEditingController titleController = new TextEditingController();
  TextEditingController contentController = new TextEditingController();
  int currentPageIndex = 1;
  String name = "";
  String grade = "";
  int numQuestionsAsked = 0;
  int numQuestionsAnswered = 0;
  int numQuestionsAnsweredCorrectly = 0;
  //List<String> questionSubject = [];
  List<dynamic> subjects = [];
  List<String> comments = [];
  int userScore = 0;
  var questionUUID = new Uuid();
  var img;
  bool uploadQuestionPicture = false;
  bool takeQuestionPicture = false;
  var uploadedPicProfileRef;
  var uploadedPicFile;
  var questionPicTime;
  String questionSubject = "";
  String displaySubjects = "";
  late FirebaseMessaging messaging;

  @override
  void initState() {
    super.initState();
    messaging = FirebaseMessaging.instance;
    messaging.getToken().then((value) {
      print(value);
    });

    FirebaseMessaging.onMessage.listen((event) {
      print(event.notification!.body);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((event) {
      print("on message");
    });
  }

  _ProfileState() {
    getProfileInfo();
    getComments();
    getNumQuestionsAndAnswers();
  }

  Future<void> getProfileInfo() async {
    var info;
    await FirebaseDatabase.instance.ref().child("User").child(getUID()).once().
    then((value) async {
      info = value.snapshot.value as Map;
      print("information:");
      print(info);

      setState(() {
        name = info["name"];
        grade = info["grade"];
        subjects = info["subjects"];
      });
    }).
    catchError((error) {
      print("Could not grab profile info: " + error.toString());
    });
    try {
      setState(() {
        img = ProfilePicture(
          name: 'NAME',
          radius: 25,
          fontsize: 21,
          img: info["profilepic"],
        );
      });
    } catch (error) {
      setState(() {
        img = ProfilePicture(
          name: 'NAME',
          radius: 25,
          fontsize: 21,
          img: "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png",
        );
      });
    }
  }

  Future<void> getComments() async {
    await FirebaseDatabase.instance.ref().child("Records").child(getUID()).child("answers").once().
    then((value) {
      print("Grabbed comment records");
      var info = value.snapshot.value as Map;
      info.forEach((questionTitle, timeStamp) async {
        //look up question
        await FirebaseDatabase.instance.ref().child("Questions").child(questionTitle).child("comments").child(timeStamp.toString()).once().
        then((value) {
          var info = value.snapshot.value as Map;
          if (info["voters"] != null) {
            int commentScore = 0;
            var score = info["voters"] as Map;
            score.forEach((key, value) {
              commentScore += int.parse(value.toString());
              print(value.toString());
            });
            setState(() {
              print(commentScore);
              userScore += commentScore;
            });
          }
        }).catchError((error) {
          print("could not look up comment" + error.toString());
        });
        //look up timestamp comment
        //access to comment's contents
      });
    }).catchError((error) {
      print("could not get comments" + error.toString());
    });
  }

  Future<String> getQuestionSubject(String questionTitle, String questionDescription) async {
    String combined = questionTitle + " " + questionDescription;
    String url = "https://Tutor-AI-Server.bigphan.repl.co/subject/" + combined;
    final uri = Uri.parse(url);
    final response = await http.get(uri);
    var responseData = json.decode(response.body);
    print(responseData);
    return responseData;
  }

  Future<void> createQuestion() async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    String uuid = questionUUID.v4();
    await FirebaseDatabase.instance.ref().child("Questions").child(getUID() + "+" + uuid).set(
        {
          "time": timeStamp,
          "content": contentController.text,
          "author": getUID(),
          "comments": comments,
          "title": titleController.text,
          "uuid": uuid,
          "subject": await getQuestionSubject(titleController.text, contentController.text),
        }
    ).then((value) async {
      print("Successfully uploaded question");
      await FirebaseDatabase.instance.ref().child("Records").child(getUID()).child("questions asked").update({
        uuid: uuid,
      }).
      then((value) {
        print("Set up records");
      }).catchError((onError) {
        print("Failed to set up records" + onError.toString());
      });

      setState(() {
        titleController.text = "";
        contentController.text = "";
      });
    }).catchError((onError){
      print("Could not upload question" + onError.toString());
    });
    //upload picture into firebase
    if (uploadQuestionPicture || takeQuestionPicture) {
      try {
        await uploadedPicProfileRef.putFile(uploadedPicFile);
        await FirebaseDatabase.instance.ref().child("Questions").child(getUID() + "+" + uuid).update({
          "uploadedpic": await uploadedPicProfileRef.getDownloadURL(),
          "uploadedpictime" : questionPicTime,
        }).then((value) {
          print("uploaded question pic ");
        }).catchError((error) {
          print("not able to upload question pic " + error.toString());
        });
      } catch (e) {
        print("could not upoload question pic " + e.toString());
      }
    }
  }
  
  Future<void> getNumQuestionsAndAnswers() async {
    await FirebaseDatabase.instance.ref().child("Records").child(getUID()).once().
    then((value) {
      var info = value.snapshot.value as Map;
      setState(() {
        numQuestionsAsked = info["questions asked"].length;
        numQuestionsAnswered = info["answers"].length;
        numQuestionsAnsweredCorrectly = info["correct answers"].length;
      });
    }).catchError((error) {
      print("could not get this info " + error.toString());
    });
  }

  Future<void> uploadProfilePic() async {
    final storageRef = FirebaseStorage.instance.ref();
    final profileRef = storageRef.child("profilePics/" + getUID() + ".png");
    final ImagePicker picker = ImagePicker();
    XFile? xFile = await picker.pickImage(
        source: ImageSource.gallery
    );
    File file = File(xFile!.path);
    try {
      await profileRef.putFile(file);
      await FirebaseDatabase.instance.ref().child("User").child(getUID()).update({
        "profilepic":await profileRef.getDownloadURL(),
      }).then((value) {
        print("uploaded profile pic");
      }).catchError((onError) {
        print("could not upload profile pic");
      });
    } catch (e) {
      print("couldn't upload pciutre" + e.toString());
    }
  }

  Scaffold profileUI() {
    if (subjects.isNotEmpty) {
      displaySubjects = subjects[0];
      for (var i = 1; i < subjects.length; i++) {
        displaySubjects = displaySubjects + ", " + subjects[i];
      }
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 6,
        leading: Builder(builder: (context) =>
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              color: Colors.black,
            ),
        ),
        backgroundColor: Color.fromRGBO(82, 121, 111, 1),
        title: Text(
            name,
          style: GoogleFonts.workSans(
            textStyle: TextStyle(
              fontSize: 33,
              color: Colors.black,
            ),
          ),
        ),
        //leading: Icon(Icons.settings),
      ),
      body: Column(
        children: [
          Expanded(
              flex: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  Column(
                    children: [
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
                          Column(
                            children: [
                              Text(
                                userScore.toString(),
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
              )
          ),
          Expanded(
            flex: 75,
            child: Column(
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.all(8),
          children: [
            const SizedBox(
              height: 100,
              child: DrawerHeader(
                child: Text("Settings"),
              ),
            ),
            ListTile(
              title: Text("Logout"),
              onTap: () async{
                await FirebaseAuth.instance.signOut().then((value) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Login(),
                    ),
                  );
                });
              },
              leading: Icon(Icons.logout),
            ),
            ListTile(
              title: Text("Upload Profile Picture"),
              onTap: () async {
                await uploadProfilePic();
              },
              leading: Icon(Icons.person),
            ),
            ListTile(
              title: Text("Help"),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SupportPage(),
                  ),
                );
              },
              leading: Icon(Icons.question_mark),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold (
      bottomNavigationBar: NavigationBar(
        height: 65,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        selectedIndex: currentPageIndex,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.question_mark),
              label: 'Questions'
          ),
          NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              label: 'Profile'
          ),
          NavigationDestination(
              icon: Icon(Icons.history),
              label: 'History'
          ),
        ],
      ),
      body: <Widget> [
        Questions(),
        // Settings(),
        profileUI(),
        History(),
      ] [currentPageIndex],
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   PageController _pageController = PageController(initialPage: 0);
  //   return Scaffold(
  //     body: PageView(
  //       controller: _pageController,
  //       onPageChanged: (newIndex) {
  //         setState(() {
  //           currentPageIndex = newIndex;
  //         });
  //       },
  //       children: [
  //         Questions(),
  //         profileUI(),
  //         History(),
  //       ],
  //     ),
  //     bottomNavigationBar: BottomNavigationBar(
  //       currentIndex: currentPageIndex,
  //       onTap: (index) {
  //         setState(() {
  //           _pageController.animateToPage(index, duration: Duration(milliseconds: 500), curve: Curves.ease);
  //         });
  //       },
  //       showUnselectedLabels: false,
  //       iconSize: 24,
  //       backgroundColor: Colors.white60,
  //       items: const [
  //         BottomNavigationBarItem(
  //           icon: Icon(Icons.question_mark_sharp),
  //           label: "Questions",
  //         ),
  //         BottomNavigationBarItem(
  //           icon: Icon(Icons.person),
  //           label: "Profile",
  //         ),
  //         BottomNavigationBarItem(
  //           icon: Icon(Icons.history),
  //           label: "History",
  //         ),
  //       ],
  //     ),
  //   );
  // }
}