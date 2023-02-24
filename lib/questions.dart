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
  TextEditingController searchController = TextEditingController();
  String filter = "";
  var questionProfilePics = Map();
  List<String> interestedSubjects = [];
  String mostRecentlyUploadedQuestion = "";

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
    getQuestions().then((value) => getAllProfilePics());
    getUserSubjects();
  }

  ///Adds data from a specific question to a Question object and adds it to the question list.
  void addQuestionToList(dynamic questionData) {
    Question q = Question(questionData["time"].toString(), questionData["title"], questionData["content"], questionData["author"], questionData["uuid"], questionData["subject"]);
    if (questionData["author"].toString().compareTo(getUID()) != 0) {
      questions.add(q);
    }
  }

  ///Adds all questions given a dictionary representing a query.
  void addAllQuestions(dynamic questionQuery) {
    setState(() {
      questionQuery.forEach((questionUUID, questionData) {
        addQuestionToList(questionData);
      });
    });
  }

  ///Queries all questions and adds them to the question list.
  Future<void> queryAllQuestions() async {
    await FirebaseDatabase.instance.ref().child("Questions").once().
    then((result) {
      var info = result.snapshot.value as Map;
      addAllQuestions(info);
    }).catchError((error) {
      print("could not get question info $error");
    });
  }

  ///Gets all questions with a similarity score to the filter over zero. Occurs only when a filter is nonempty.
  Future<void> queryWithFilter() async {
    String url = "https://Tutor-AI-Server.bigphan.repl.co/recommend/$filter";
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

  ///Updates the questions list by referencing the Firebase Realtime Database.
  Future<void> getQuestions() async {
    questions = [];
    if (filter.isEmpty) {
      // await queryAllQuestions();
      await queryWithRecommendation();
    } else {
      await queryWithFilter();
    }
  }

  ///Determines if a given question's author has a profile picture.
  ///If it does, locate it in storage and add it to a profile picture list.
  ///Otherwise, use a placeholder.
  Future<void> downloadProfilePic(dynamic questionData) async {
    if (!questionData.containsKey("author")) {
      return;
    }
    final profileRef = FirebaseStorage.instance.ref().child("profilePics/" + questionData["author"] + ".png");
    await profileRef.getDownloadURL().then((value2) async {
      String url = await profileRef.getDownloadURL();
      setState(() {
        questionProfilePics[questionData["author"]] = ProfilePicture(
          name: 'NAME',
          radius: 20,
          fontsize: 20,
          img: url,
        );
      });
    }).catchError((error) {
      if (mounted) {
        setState(() {
          questionProfilePics[questionData["author"]] = const ProfilePicture(
            name: 'NAME',
            radius: 20,
            fontsize: 20,
            img: "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png",
          );
        });
      }
    });
  }

  ///Grabs the profile picture for all questions in a given [query]
  Future<void> getProfilePicForQuestions(dynamic query) async {
    setState(() {
      query.forEach((questionUUID, questionData) async {
        await downloadProfilePic(questionData);
      });
    });
  }

  ///Queries all questions in a search result for profile pictures.
  Future<void> getAllProfilePics() async {
    await FirebaseDatabase.instance.ref().child("Questions").once().
    then((value) async {
      var info = value.snapshot.value as Map;
      await getProfilePicForQuestions(info);
    }).catchError((error) {
      print("could not get question profile pics $error");
    });
  }

  ///Appends the names of all subjects the user is interested in to the interestedSubjects list.
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
      print("could not get interested subjects $error");
    });
  }

  ///Given a [questionUUID], return an object of type Question containing all relevant information.
  Future<Question> getQuestionInfo(String questionUUID) async {
    var q;
    await FirebaseDatabase.instance.ref().child("Questions").child(questionUUID).once().
    then((value) {
      var info = value.snapshot.value as Map;
      q = Question(info["time"].toString(), info["title"], info["content"], info["author"], info["uuid"], info["subject"]);
    });
    return q;
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

  ///Makes a request to the server with the [questionTitle] and [questionDescription] of a recently made post.
  Future<String> getQuestionSubject(String questionTitle, String questionDescription) async {
    String combined = questionTitle + " " + questionDescription;
    String url = "https://Tutor-AI-Server.bigphan.repl.co/subject/" + combined;
    final uri = Uri.parse(url);
    final response = await http.get(uri);
    var responseData = json.decode(response.body);
    print(responseData);
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
    if (uploadQuestionPicture || takeQuestionPicture) {
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

  ///Gets the title & content of the most recent question the user has asked
  Future<void> getMostRecentlyUploadedQuestion() async {
    int largestTimeStamp = 0;
    await FirebaseDatabase.instance.ref().child("Records").child(getUID()).child("questions asked").once().
    then((value) {
      var info = value.snapshot.value as Map;
      info.forEach((qUUID, sameAsKey) async {
        await FirebaseDatabase.instance.ref().child("Questions").child(getUID() + "+" + qUUID).once().
        then((value) {
          var info2 = value.snapshot.value as Map; //error
          int timeStamp = info2["time"];
          if (timeStamp > largestTimeStamp) {
            largestTimeStamp = timeStamp;
            setState(() {
              mostRecentlyUploadedQuestion = info2["title"] + " " + info2["content"];
              print(mostRecentlyUploadedQuestion);
            });
          }
        }).catchError((error){
          print("could not get time stamp " + error.toString());
        });
      });
    }).catchError((error) {
      print("could not get most recent time stamp " + error.toString());
    });
  }

  Future<List<dynamic>> getUUIDsForRecentlyCommentedOnQuestions() async {
    var value = await FirebaseDatabase.instance.ref().child("Records").child(getUID()).child("answers").once();
    try {
      var info = value.snapshot.value as Map;
      var mapEntries = info.entries.toList();
      mapEntries.sort((a, b) => a.value.compareTo(b.value));
      info.clear();
      info.addEntries(mapEntries);
      return info.keys.toList();
    } catch (e) {
      return [];
    }
  }
  
  Future<String> getContents(int count, List<dynamic> uuids) async {
    if (uuids.isEmpty) {
      return "";
    } else {
      String output = "";
      for (int i = 0; i < count; i++) {
        if (i >= uuids.length) {
          break;
        } else {
          output += await getContentOfQuestion(uuids[i]);
        }
      }
      return output;
    }
  }
  
  Future<String> getContentOfQuestion(String uuid) async {
    if (uuid.isEmpty) {
      return "";
    } else {
      var value = await FirebaseDatabase.instance.ref().child("Questions").child(uuid).once();
      var info = value.snapshot.value as Map;
      return info["title"] + " " + info["content"];
    }
  }

  ///Makes a query for the user based on their most recently asked question or comment.
  Future<void> queryWithRecommendation() async {
    var uuidList = await getUUIDsForRecentlyCommentedOnQuestions();
    String mostRecentlyCommentedQuestions = await getContents(3, uuidList);
    String url = "https://Tutor-AI-Server.bigphan.repl.co/recommend/$mostRecentlyCommentedQuestions";
    final uri = Uri.parse(url);
    final response = await http.get(uri);
    try {
      var responseData = json.decode(response.body);

      print("RESPONSE DATA: " + responseData.toString());
      for (int i = 0; i < responseData.length; i++) {
        Question questionToAdd = await getQuestionInfo(responseData[i].toString());

        if (questionToAdd.author == getUID() || uuidList.contains(responseData[i].toString())) {
          continue;
        }

        setState(() {
          questions.add(questionToAdd);
        });
      }
    }catch (error){
      print("Could not find any questions to recommend");
    }
  }

  ///Displays a pop up showing the form data for creating a new question.
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

  ///Brings up the user's photo gallery for them to select a picture to use for a question.
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

  ///Brings up the user's camera for them to use for a question.
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
          if (questions.isEmpty)
            Center(
              child: Column(
                children: [
                  Center(
                    child: Lottie.asset("assets/animations/hUiEYf0LGw.json"),
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
          if (questions.isNotEmpty)
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
                  Expanded(flex: 50, child: Container()),
                  Expanded(flex: 11, child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PublicProfilePage(uid: questionAuthorUID),
                        ),
                      );
                    },
                    child: Container(
                      child: img,
                      height: 20,
                      width: 20,
                    ),
                  ),),
                  Expanded(flex: 20, child: Text(dt.month.toString() + "/" + dt.day.toString() + "/" + dt.year.toString())),
                  Expanded(flex: 10, child: Text(dt.hour.toString() + ":" + dt.minute.toString())),
                ],
              ),
            ],
          ),
          onTap: () {
            //viewQuestion(questions[index].author + "+" + questions[index].uuid);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => QuestionsPage(q: questions[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}
