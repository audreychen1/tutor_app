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
      await FirebaseDatabase.instance.ref().child("Questions").child(questionTitle).child("comments").child(timeStamp.toString()).once().
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

  ///Makes a request to the server with the [questionTitle] and [questionDescription] of a recently made post.
  Future<String> getQuestionSubject(String questionTitle, String questionDescription) async {
    String combined = "$questionTitle $questionDescription";
    String url = "https://Tutor-AI-Server.bigphan.repl.co/subject/$combined";
    final uri = Uri.parse(url);
    final response = await http.get(uri);
    var responseData = json.decode(response.body);
    return responseData;
  }

  ///Makes a request to the server with the [questionTitle] and [questionDescription] of a recently made post
  ///with a given [topic].
  Future<void> sendNotification(String questionTitle, String questionDescription, String topic) async {
    String url = "https://Tutor-AI-Server.bigphan.repl.co/notify/$questionTitle/$questionDescription/$topic";
    final uri = Uri.parse(url);
    await http.get(uri);
  }

  ///Adds the [uuid] of a recently made question to the user's records.
  Future<void> updateRecordsWithQuestion(String uuid) async {
    await FirebaseDatabase.instance.ref().child("Records").child(getUID()).child("questions asked").update({
      uuid: uuid,
    }).
    then((value) {
      print("Set up records");
    }).catchError((onError) {
      print("Failed to set up records$onError");
    });
  }
  
  void clearTextControllers() {
    setState(() {
      titleController.text = "";
      contentController.text = "";
    });
  }

  ///Uploads a picture, if the user chose to.
  Future<void> uploadPictureForQuestion(String uuid) async {
    if (uploadedQuestionPicture || tookQuestionPicture) {
      try {
        await uploadedPicProfileRef.putFile(uploadedPicFile);
        await FirebaseDatabase.instance.ref().child("Questions").child("${getUID()}+$uuid").update({
          "uploadedpic": await uploadedPicProfileRef.getDownloadURL(),
          "uploadedpictime" : questionPicTime,
        }).then((value) {
          print("uploaded question pic ");
        }).catchError((error) {
          print("not able to upload question pic $error");
        });
      } catch (e) {
        print("could not upload question pic $e");
      }
    }
  }

  ///Occurs when a user taps on the create question button.
  Future<void> createQuestion() async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    String uuid = questionUUID.v4();
    
    await FirebaseDatabase.instance.ref().child("Questions").child("${getUID()}+$uuid").set(
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
      
      await updateRecordsWithQuestion(uuid);
      clearTextControllers();
    }).catchError((onError){
      print("Could not upload question$onError");
    });
    
    //upload picture into firebase
    await uploadPictureForQuestion(uuid);
  }

  ///Displays a pop up showing the form data for creating a new question.
  void showQuestionDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("New Question"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Title",
                    ),
                  ),
                  TextField(
                    controller: contentController,
                    minLines: 3,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Content",
                    ),
                  ),
                  if (uploadedQuestionPicture || tookQuestionPicture)
                    Text(uploadedPicFile.path),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                      createQuestion().then((value) {
                        Navigator.pop(context);
                      });
                    }
                    setState(() {
                      numQuestionsAsked = numQuestionsAsked + 1;
                    });
                  },
                  child: Text("Upload"),
              ),
              FloatingActionButton(
                onPressed: () {
                  takeQuestionPic();
                },
                tooltip: "Take Picture",
                child: const Icon(Icons.camera_alt_outlined),
              ),
              FloatingActionButton(
                onPressed: () {
                  uploadQuestionPic();
                },
                tooltip: "Upload Picture",
                child: const Icon(Icons.photo),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Cancel"),
              ),
            ],
          );
        }
      );
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
      }).catchError((onError) {
        print("could not upload profile pic");
      });
    } catch (e) {
      print("couldn't upload picture$e");
    }
  }

  ///Brings up the user's photo gallery for them to select a picture to use for a question.
  Future<void> uploadQuestionPic() async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    questionPicTime = timeStamp;
    final storageRef = FirebaseStorage.instance.ref();
    final profileRef = storageRef.child("questionPics/${getUID()}+$timeStamp.png");
    final ImagePicker questionImagePicker = ImagePicker();
    XFile? xFile = await questionImagePicker.pickImage(
        source: ImageSource.gallery,
    );
    File f = File(xFile!.path);
    uploadedPicProfileRef = profileRef;
    uploadedPicFile = f;
    if (uploadedPicFile != null) {
      uploadedQuestionPicture = true;
    }
  }

  ///Brings up the user's camera for them to use for a question.
  Future<void> takeQuestionPic() async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    questionPicTime = timeStamp;
    final storageRef = FirebaseStorage.instance.ref();
    final profileRef = storageRef.child("questionPics/${getUID()}+$timeStamp.png");
    final ImagePicker questionImagePicker = ImagePicker();
    XFile? xFile = await questionImagePicker.pickImage(
      source: ImageSource.camera,
    );
    File f = File(xFile!.path);
    uploadedPicProfileRef = profileRef;
    uploadedPicFile = f;
    if (uploadedPicFile != null) {
      tookQuestionPicture = true;
    }
  }

  Drawer drawerCode() {
    return Drawer(
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          const SizedBox(
            height: 100,
            child: DrawerHeader(
              child: Text("Settings"),
            ),
          ),
          ListTile(
            title: const Text("Logout"),
            onTap: () async{
              await FirebaseAuth.instance.signOut().then((value) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const Login(),
                  ),
                );
              });
            },
            leading: const Icon(Icons.logout),
          ),
          ListTile(
            title: const Text("Upload Profile Picture"),
            onTap: () async {
              await uploadProfilePic();
            },
            leading: const Icon(Icons.person),
          ),
          ListTile(
            title: const Text("Help"),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SupportPage(),
                ),
              );
            },
            leading: const Icon(Icons.question_mark),
          ),
        ],
      ),
    );
  }

  Row createTopRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(6.0),
          child: SizedBox(
            height: MediaQuery.of(context).size.width * 0.2,
            width: MediaQuery.of(context).size.width * 0.2,
            child: img,
          ),
        ),
        Row(
          children: [
            Column(
              children: [
                Text(
                  grade,
                  style: GoogleFonts.notoSans(
                    textStyle:const TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ),
                Text(
                  "Grade",
                  style: GoogleFonts.notoSans(
                    textStyle:const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Placeholder(
              fallbackWidth: 20,
              fallbackHeight: 20,
              color: Colors.transparent,
            ),
            Column(
              children: [
                Text(
                  userScore.toString(),
                  style: GoogleFonts.notoSans(
                    textStyle:const TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ),
                Text(
                  "Joined",
                  style: GoogleFonts.notoSans(
                    textStyle:const TextStyle(
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
    );
  }

  Column createMiddleColumn() {
    return Column(
      children: [
        const ListTile(
          title: Text(
            "Volunteer Hours",
            style: TextStyle(
              fontSize: 20,
            ),
          ),
          subtitle: Text(
            "5",
            style: TextStyle(
              fontSize: 30,
            ),
          ),
          leading: Icon(Icons.volunteer_activism),
        ),
        ListTile(
          title: const Text(
            "Subjects",
            style: TextStyle(
              fontSize: 20,
            ),
          ),
          subtitle: Text(
            displaySubjects,
            style: const TextStyle(
              fontSize: 30,
            ),
          ),
          leading: const Icon(Icons.menu_book_sharp),
        ),
        const ListTile(
          title: Text(
            "Questions Asked",
            style: TextStyle(
              fontSize: 20,
            ),
          ),
          subtitle: Text(
            "0",
            style: TextStyle(
              fontSize: 30,
            ),
          ),
          leading: Icon(Icons.question_mark_sharp),
        ),
        const ListTile(
          title: Text(
            "Questions Answered",
            style: TextStyle(
              fontSize: 20,
            ),
          ),
          subtitle: Text(
            "0",
            style: TextStyle(
              fontSize: 30,
            ),
          ),
          leading: Icon(Icons.question_answer_outlined),
        ),
        const ListTile(
          title: Text(
            "Questions Answered Correctly",
            style: TextStyle(
              fontSize: 20,
            ),
          ),
          subtitle: Text(
            "0",
            style: TextStyle(
              fontSize: 30,
            ),
          ),
          leading: Icon(Icons.check),
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
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Builder(builder: (context) =>
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              color: Colors.grey,
            ),
        ),
        //backgroundColor: Colors.transparent,
        title: Text(
            name,
          style: GoogleFonts.workSans(
            textStyle: const TextStyle(
              fontSize: 33,
              color: Colors.black,
            ),
          ),
        ),
        //leading: Icon(Icons.settings),
      ),
      body: Column(
        children: [
          const Placeholder(
            fallbackHeight: 20,
            color: Colors.transparent,
          ),
          Expanded(
              flex: 20,
              child: createTopRow()
          ),
          Expanded(
            flex: 75,
            child: SingleChildScrollView(child: createMiddleColumn())
          ),

        ],
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            showQuestionDialog(context);
          },
        tooltip: "New Question",
          child: const Icon(
              Icons.add,
          ),
      ),
      drawer: drawerCode()
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold (
      bottomNavigationBar: NavigationBar(
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
        const Questions(),
        profileUI(),
        const History(),
      ] [currentPageIndex],
    );
  }
}