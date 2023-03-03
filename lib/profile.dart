import 'dart:convert';
import 'dart:io';
import 'package:bs_flutter_selectbox/bs_flutter_selectbox.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_profile_picture/flutter_profile_picture.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tutor_app/delete_page.dart';
import 'package:tutor_app/helper.dart';
import 'package:tutor_app/history.dart';
import 'package:tutor_app/questions.dart';
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

  static const DEFAULT_PROFILE_PICTURE = ProfilePicture(
    name: 'NAME',
    radius: 25,
    fontsize: 21,
    img: "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png",
  );
  
  BsSelectBoxController subController = BsSelectBoxController(options: [
    const BsSelectBoxOption(value: "Science", text: Text("Science")),
    const BsSelectBoxOption(value: "Math", text: Text("Math")),
    const BsSelectBoxOption(value: "English", text: Text("English")),
    const BsSelectBoxOption(value: "Language", text: Text("Language")),
    const BsSelectBoxOption(value: "History", text: Text("History")),
  ]);

  TextEditingController titleController = TextEditingController();
  TextEditingController contentController = TextEditingController();
  int currentPageIndex = 1;
  String name = "";
  String grade = "";
  int numQuestionsAsked = 0;
  int numQuestionsAnswered = 0;
  int numQuestionsAnsweredCorrectly = 0;
  int numVolunteerHours = 0;
  List<dynamic> subjects = [];
  List<String> comments = [];
  int userScore = 0;
  var questionUUID = new Uuid();
  var img;
  bool uploadedQuestionPicture = false;
  bool tookQuestionPicture = false;
  var uploadedPicProfileRef;
  var uploadedPicFile;
  var questionPicTime;
  String questionSubject = "";
  String displaySubjects = "";

  _ProfileState() {
    getProfileInfo();
    getScore();
    getNumQuestionsAndAnswers();
  }

  ///Unsubscribes from all possible topics and resubscribes based on the
  ///newly updated subject list.
  void updateTopicSubscriptions() {
    FirebaseMessaging.instance.unsubscribeFromTopic("Math");
    FirebaseMessaging.instance.unsubscribeFromTopic("Science");
    FirebaseMessaging.instance.unsubscribeFromTopic("Language");
    FirebaseMessaging.instance.unsubscribeFromTopic("History");
    FirebaseMessaging.instance.unsubscribeFromTopic("English");

    for (String s in subjects) {
      FirebaseMessaging.instance.subscribeToTopic(s);
    }
  }
  
  ///Updates all present state variables by
  ///making a call to the Realtime Database.
  ///This includes the name, grade, subjects, and profile picture.
  Future<void> getProfileInfo() async {
    
    var info;
    await FirebaseDatabase.instance.ref().child("User").child(getUID()).once().
    then((value) async {
      info = value.snapshot.value as Map;

      setState(() {
        name = info["name"];
        grade = info["grade"];
        subjects = info["subjects"];
      });

      updateTopicSubscriptions();
    }).
    catchError((error) {
      print("Could not grab profile info: $error");
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
        img = DEFAULT_PROFILE_PICTURE;
      });
    }
  }

  ///Gets the score for a comment by looking through all votes.
  void tallyUpCommentScore(dynamic comment) {
    if (comment["voters"] != null) {
      int commentScore = 0;
      var score = comment["voters"] as Map;
      score.forEach((key, value) {
        commentScore += int.parse(value.toString());
      });
      setState(() {
        userScore += commentScore;
      });
    }
  }
  
  ///Gets the score for a collection of comments.
  Future<void> tallyUpAnswers(dynamic answers) async {
    answers.forEach((questionTitle, timeStamp) async {
      print(questionTitle);
      print(timeStamp.toString());
      await FirebaseDatabase.instance.ref().child("Questions").child(questionTitle).child("comments").child(timeStamp.toString()+"+"+getUID()).once().
      then((value) {
        var comment = value.snapshot.value as Map;
        tallyUpCommentScore(comment);
      }).catchError((error) {
        print("could not look up comment $error");
      });
    });
  }
  
  ///Looks up the user's comments on record, and tallies up all the scores together.
  Future<void> getScore() async {
    await FirebaseDatabase.instance.ref().child("Records").child(getUID()).child("answers").once().
    then((value) async {
      var answers = value.snapshot.value as Map;
      await tallyUpAnswers(answers);
    }).catchError((error) {
      print("could not get comments $error");
    });
  }

  ///Brings up the user's photo gallery for them to select a picture to use for a profile picture.
  Future<void> uploadProfilePic() async {
    final storageRef = FirebaseStorage.instance.ref();
    final profileRef = storageRef.child("profilePics/${getUID()}.png");
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
        getProfileInfo();
      }).catchError((onError) {
        print("could not upload profile pic");
      });
    } catch (e) {
      print("couldn't upload picture$e");
    }
  }

  Future<void> getNumQuestionsAndAnswers() async {
    await FirebaseDatabase.instance.ref().child("Records").child(getUID()).once().
    then((value) async {
      var info = value.snapshot.value as Map;
      print("PROFILE DATA: " + info.toString());
      setState(() {
        if (info.containsKey("questions asked")) {
          numQuestionsAsked = info["questions asked"].length;
        }

        if (info.containsKey("answers")) {
          numQuestionsAnswered = info["answers"].length;
        }

        if (info.containsKey("correct answers")) {
          numQuestionsAnsweredCorrectly = info["correct answers"].length;
        }
      });
      String url = "https://Tutor-AI-Server.bigphan.repl.co/community_hour/$numQuestionsAnsweredCorrectly";
      final uri = Uri.parse(url);
      final response = await http.get(uri);
      var responseData = json.decode(response.body);
      setState(() {
        numVolunteerHours = double.parse(responseData.toString()).toInt();
      });
      print("RESPONSE DATA: " + responseData.toString());
    }).catchError((error) {
      print("could not get this info " + error.toString());
    });
  }

  void showDeleteAccountPopUp() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Delete Account?"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Delete Account?",
                    style: GoogleFonts.notoSans(
                      fontSize: 30,
                    ),
                  ),
                  ElevatedButton(
                      onPressed: () {
                        FirebaseAuth.instance.currentUser?.delete().then((value) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => Login(),
                            ),
                          );
                        }).catchError((error) {
                          print("could not delete account " + error.toString());
                        });
                      },
                      child: Text("Delete")
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                  onPressed: (){
                    Navigator.pop(context);
                    },
                  child: Text("Cancel")),
            ],
          );
        }
    );
  }

  Drawer drawerCode() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.all(8.0),
        children: [
          SizedBox(
            height: 100,
            child: DrawerHeader(
              child: Text("Settings"),
            ),
          ),
          ListTile(
            title: Text("Logout"),
            onTap: () async {
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
            onTap: ()  {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SupportPage(),
                ),
              );
            },
            leading: Icon(Icons.question_mark),
          ),
          ListTile(
            title: Text("Delete Account"),
            onTap: ()  {
              showDeleteAccountPopUp();
            },
            leading: Icon(Icons.restore_from_trash_rounded),
          ),
        ],
      ),
    );
  }

  Padding createTopRow() {
    return Padding(
      padding: EdgeInsets.only(top: 15.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 47,
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Container(
                height: MediaQuery.of(context).size.width * 0.25,
                width: MediaQuery.of(context).size.width * 0.25,
                child: img,
              ),
            ),
          ),
          Expanded(
            flex: 53,
            child: Padding(
              padding: EdgeInsets.only(top: 20.0, right: 10.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(right: 20.0),
                        child: Column(
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
                            "Points",
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
            ),
          ),
        ],
      ),
    );
  }

  Column createMiddleColumn() {
    return Column(
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
                  numVolunteerHours.toString(),
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
            )
          ],
        ),
        Row(
          children: [
            Expanded(flex: 15, child: Container()),
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
            )
          ],
        ),
        Row(
          children: [
            Expanded(flex: 15, child: Container()),
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
            )
          ],
        ),
        Row(
          children: [
            Expanded(flex: 15, child: Container()),
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
            )
          ],
        ),
        Row(
          children: [
            Expanded(flex: 15, child: Container()),
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
                  icon: const Icon(Icons.check_box_rounded),
                  onPressed: (){},
                  color: Color.fromRGBO(53, 79, 82, 1),
                ),
              ),
            )
          ],
        ),
      ],
    );
  }

  Scaffold profileUI() {
    if (subjects.isNotEmpty) {
      displaySubjects = subjects[0];
      for (var i = 1; i < subjects.length; i++) {
        displaySubjects = "$displaySubjects, " + subjects[i];
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
            //leading: Icon(Icons.settings),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
              children: [
                createTopRow(),
                createMiddleColumn(),
              ]
          ),
        ),
      drawer: drawerCode()
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
}