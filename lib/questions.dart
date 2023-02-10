import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_profile_picture/flutter_profile_picture.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:outline_search_bar/outline_search_bar.dart';
import 'package:tutor_app/helper.dart';
import 'package:tutor_app/profile.dart';
import 'package:tutor_app/public_profile_page.dart';
import 'package:tutor_app/questions_page.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class Questions extends StatefulWidget {
  const Questions({Key? key}) : super(key: key);

  @override
  State<Questions> createState() => _QuestionsState();
}

class Question {
  String time;
  String title;
  String content;
  String author;
  String uuid;
  String subject;

  Question(this.time, this.title, this.content, this.author, this.uuid, this.subject);
}

class _QuestionsState extends State<Questions> {
  List<Question> questions = [];
  TextEditingController searchController = new TextEditingController();
  String filter = "";
  var questionProfilePics = new Map();
  List<String> interestedSubjects = [];

  TextEditingController titleController = new TextEditingController();
  TextEditingController contentController = new TextEditingController();
  bool uploadQuestionPicture = false;
  bool takeQuestionPicture = false;
  var uploadedPicProfileRef;
  var uploadedPicFile;
  var questionPicTime;
  var questionUUID = new Uuid();
  List<String> comments = [];
  var questionViews = new Map();

  _QuestionsState() {
    getQuestions().then((value) => getQuestionProfilePics());
  }

  Future<void> getQuestions() async {
    questions = [];
    if (filter.isEmpty) {
      await FirebaseDatabase.instance.ref().child("Questions").once().
      then((result) {
        var info = result.snapshot.value as Map;
        setState(() {
          info.forEach((key, value) async {
            Question q;
            q = Question(value["time"].toString(), value["title"], value["content"], value["author"], value["uuid"], value["subject"]);
            if (value["author"].toString().compareTo(getUID()) != 0) {
              //if (filter.isEmpty) {
              questions.add(q);
              // } else if (q.title.contains(filter)){
              //   questions.add(q);
              // }
            }
          });
        });
      }).catchError((error) {
        print("could not get question info " + error.toString());
      });
    } else {
      String url = "https://Tutor-AI-Server.bigphan.repl.co/recommend/" + filter;
      final uri = Uri.parse(url);
      final response = await http.get(uri);
      var responseData = json.decode(response.body);
      print(responseData);
      for (int i = 0; i < responseData.length; i++) {
        Question questionToAdd = await getQuestionInfo(responseData[i].toString());
        setState(() {
          questions.add(questionToAdd);
        });
      }
    }
  }
  
  Future<void> getQuestionProfilePics() async {
    await FirebaseDatabase.instance.ref().child("Questions").once().
    then((value) {
      var info = value.snapshot.value as Map;
      setState(() {
        info.forEach((key, value) async {
          final profileRef = FirebaseStorage.instance.ref().child("profilePics/" + value["author"] + ".png");
          await profileRef.getDownloadURL().then((value2) async {
            String url = await profileRef.getDownloadURL();
            setState(() {
              questionProfilePics[value["author"]] = ProfilePicture(
                name: 'NAME',
                radius: 20,
                fontsize: 20,
                img: url,
              );
            });
          }).catchError((error) {
            setState(() {
              questionProfilePics[value["author"]] = ProfilePicture(
                name: 'NAME',
                radius: 20,
                fontsize: 20,
                img: "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png",
              );
            });
          });
        });
      });
    }).catchError((error) {
      print("could not get question profile pics " + error.toString());
    });
  }

  Future<void> getUserSubjects() async {
    await FirebaseDatabase.instance.ref().child("User").child(getUID()).once().
    then((value2) {
      var info = value2.snapshot.value as Map;
      info.forEach((key, value) {
        if (key.compareTo("subjects") == 0) {
          for (var i = 0; i < value.length; i++) {
            if (!interestedSubjects.contains(value[i].toLowerCase().toString())) {
              interestedSubjects.add(value[i].toLowerCase().toString());
            }
          }
        }
      });
    }).catchError((error) {
      print("could not get interested subjects " + error.toString());
    });
  }

  Future<Question> getQuestionInfo(String questionUUID) async {
    var q;
    await FirebaseDatabase.instance.ref().child("Questions").child(questionUUID).once().
    then((value) {
      var info = value.snapshot.value as Map;
      q = new Question(info["time"].toString(), info["title"], info["content"], info["author"], info["uuid"], info["subject"]);
    });
    return q;
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
          "views": 0,
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
            title: Row(
              children: [
                Expanded(flex: 60, child: Text("New Question", style: GoogleFonts.prompt(textStyle: TextStyle(fontSize: 18)),)),
                Expanded(
                  flex: 20,
                  child: IconButton(
                    onPressed: () {
                      takeQuestionPic();
                    },
                    icon: Icon(Icons.camera_alt_outlined),
                    tooltip: "Take Picture",
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: IconButton(
                    onPressed: () {
                      uploadQuestionPic();
                    },
                    icon: Icon(Icons.photo),
                    tooltip: "Upload Picture",
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 10.0),
                    child: TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Title",
                      ),
                    ),
                  ),
                  TextField(
                    controller: contentController,
                    minLines: 10,
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
              Container(
                decoration: BoxDecoration(
                  color: Color.fromRGBO(132, 169, 140, 1),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: TextButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                      createQuestion().then((value) {
                        Navigator.pop(context);
                      });
                    }
                  },
                  child: Text("Post", style: TextStyle(color: Colors.white),),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Color.fromRGBO(132, 169, 140, 1),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text("Cancel", style: TextStyle(color: Colors.white),),
                ),
              ),
            ],
          );
        }
    );
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

  //doesnt work
  Future<void> viewQuestion(String questionUUID) async {
    int views = 0;
    await FirebaseDatabase.instance.ref().child("Questions").child(questionUUID).once().
    then((value) {
      var info = value.snapshot.value as Map;
      views = info["views"];
    }).catchError((error) {
      print("could not get num views " + error.toString());
    });
    await FirebaseDatabase.instance.ref().child("Questions").child(questionUUID).once(
    ).then((value) {
      var info = value.snapshot.value as Map;
      setState(() {
        info["views"] = info["views"] + 1;
      });
      print("updated num views");
    }).catchError((error) {
      print("could not update num views " + error.toString());
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Container(
          child: Align(
            alignment: Alignment.center,
            child: Text(
              "Questions",
              style: GoogleFonts.oswald(
                textStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 32,
                ),
              ),
            ),
          ),
        ),
        automaticallyImplyLeading: false,
        elevation: 6,
        backgroundColor: Color.fromRGBO(82, 121, 111, 1),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          //Expanded(child: Container(), flex: 3,),
          Padding(
            padding: EdgeInsets.all(11.0),
            child: OutlineSearchBar(
              textEditingController: searchController,
              hintText: "Search",
              onClearButtonPressed: (value) {
                searchController.clear();
              },
              onSearchButtonPressed: (value) {
                setState(() {
                  filter = value.toString();
                  getQuestions();
                });
              },
              borderColor: Color.fromRGBO(120, 119, 128, 1),
              searchButtonIconColor: Color.fromRGBO(120, 119, 128, 1),
            ),
          ),
          if (questions.length == 0)
            Center(
              child: Column(
                children: [
                  Center(
                    child: Lottie.asset("animations/hUiEYf0LGw.json"),
                  ),
                  Container(
                    margin: EdgeInsets.all(100.0),
                    padding: EdgeInsets.all(5.0),
                    child: Text(
                      "No Questions",
                      style: GoogleFonts.notoSans(
                        textStyle: TextStyle(
                          fontSize: 25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (questions.length != 0)
          Expanded(
            flex: 90,
            child: ListView.builder(
              shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: questions.length,
                itemBuilder: (BuildContext context, int index) {
                  return Column(
                    children: [
                      _buildRow(index),
                      Divider(),
                    ],
                  );
                }
              ),
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
        backgroundColor: Color.fromRGBO(132, 169, 140, 1),
      ),
      );
  }

  Widget _buildRow(int index) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(int.parse(questions[index].time));
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    String questionAuthorUID = questions[index].author;
    var img = questionProfilePics[questionAuthorUID];
    getUserSubjects();
    String questionSubject = questions[index].subject.toString();

    //if (interestedSubjects.contains(questionSubject.toString().toLowerCase())) {
      return Container(
        height: 132,
        child: Center(
          child: ListTile(
            title: Text(
                questions[index].title,
              style: GoogleFonts.notoSans(
                textStyle: TextStyle(
                  fontSize: 17,
                ),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    questions[index].content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSans(
                      textStyle: TextStyle(
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(questions[index].subject),
                  ],
                ),
                Row(
                  children: [//60 40 40
                    Expanded(flex: 40, child: Container()),
                    Expanded(flex: 20, child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PublicProfilePage(uid: questionAuthorUID),
                          ),
                        );
                      },
                      child: Container(
                        child: img,
                        height: 25,
                        width: 25,
                      ),
                    ),),
                    Expanded(flex: 20, child: Text(dt.month.toString() + "/" + dt.day.toString() + "/" + dt.year.toString())),
                    Expanded(flex: 20, child: Text(dt.hour.toString() + ":" + dt.minute.toString())),
                  ],
                ),
              ],
            ),
            onTap: () {
              viewQuestion(questions[index].author + "+" + questions[index].uuid);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => QuestionsPage(q: questions[index]),
                ),
              );
            },
          ),
        ),
      );
    // } else {
    //   return Container();
    // }
  }
}
