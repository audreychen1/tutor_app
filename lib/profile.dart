import 'dart:io';
import 'package:bs_flutter_selectbox/bs_flutter_selectbox.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
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
  List<String> questionSubject = [];
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
  
  _ProfileState() {
    getProfileInfo();
    getComments();
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
          radius: 31,
          fontsize: 21,
          img: info["profilepic"],
        );
      });
    } catch (error) {
      setState(() {
        img = ProfilePicture(
          name: 'NAME',
          radius: 31,
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

  void showQuestionDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("New Question"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Title",
                    ),
                  ),
                  TextField(
                    controller: contentController,
                    minLines: 3,
                    maxLines: null,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Content",
                    ),
                  ),
                  if (uploadQuestionPicture || takeQuestionPicture)
                    Text(uploadedPicFile.path),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty && contentController.text.isNotEmpty)
                      createQuestion().then((value) {
                        Navigator.pop(context);
                      });
                  },
                  child: Text("Upload"),
              ),
              FloatingActionButton(
                onPressed: () {
                  takeQuestionPic();
                },
                child: Icon(Icons.camera_alt_outlined),
                tooltip: "Take Picture",
              ),
              FloatingActionButton(
                onPressed: () {
                  uploadQuestionPic();
                },
                child: Icon(Icons.photo),
                tooltip: "Upload Picture",
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text("Cancel"),
              ),
            ],
          );
        }
        );
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
  
  Future<void> uploadQuestionPic() async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    questionPicTime = timeStamp;
    final storageRef = FirebaseStorage.instance.ref();
    final profileRef = storageRef.child("questionPics/" + getUID() + "+" + timeStamp.toString() + ".png");
    final ImagePicker questionImagePicker = ImagePicker();
    XFile? xFile = await questionImagePicker.pickImage(
        source: ImageSource.gallery,
    );
    File f = File(xFile!.path);
    uploadedPicProfileRef = profileRef;
    uploadedPicFile = f;
    if (uploadedPicFile != null) {
      uploadQuestionPicture = true;
    }
  }

  Future<void> takeQuestionPic() async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    questionPicTime = timeStamp;
    final storageRef = FirebaseStorage.instance.ref();
    final profileRef = storageRef.child("questionPics/" + getUID() + "+" + timeStamp.toString() + ".png");
    final ImagePicker questionImagePicker = ImagePicker();
    XFile? xFile = await questionImagePicker.pickImage(
      source: ImageSource.camera,
    );
    File f = File(xFile!.path);
    uploadedPicProfileRef = profileRef;
    uploadedPicFile = f;
    if (uploadedPicFile != null) {
      takeQuestionPicture = true;
    }
  }

  Scaffold profileUI() {
    //getProfileInfo();

    return Scaffold(
      appBar: AppBar(
        title: Text("Profile Page"),
        //leading: Icon(Icons.settings),
      ),
      body: Column(
        children: [
          Expanded(
              flex: 25,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                        height: MediaQuery.of(context).size.width * 0.5,
                        width: MediaQuery.of(context).size.width * 0.5,
                        child: img,
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Grade: " + grade,
                        style: TextStyle(
                          fontSize: 30,
                        ),
                      ),
                      Text(
                        "Score: " + userScore.toString(),
                        style: TextStyle(
                          fontSize: 30,
                        ),
                      ),
                    ],
                  )
                ],
              )
          ),
          Expanded(
            flex: 25,
            child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: subjects.length,
                itemBuilder: (BuildContext context, int index) {
                  return Container(
                    child: Center(
                        child: Text(
                          subjects[index].toString(),
                          style: TextStyle(
                            fontSize: 20,
                          ),
                        )
                    ),
                  );
                }
            ),

          ),
          Expanded(
            flex: 50,
            child: Container(),
          ),

        ],
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            showQuestionDialog(context);
          },
          child: Icon(
              Icons.add,
          ),
        tooltip: "New Question",
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.all(8),
          children: [
            DrawerHeader(
                child: Text("Settings"),
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
            ),
            ListTile(
              title: Text("Upload Profile Picture"),
              onTap: () async {
                await uploadProfilePic();
              },
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
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        selectedIndex: currentPageIndex,
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.question_mark),
              label: 'Questions'
          ),
          // NavigationDestination(
          //     icon: Icon(Icons.settings),
          //     label: 'Settings'
          // ),
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