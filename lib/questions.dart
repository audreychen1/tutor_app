import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_profile_picture/flutter_profile_picture.dart';
import 'package:intl/intl.dart';
import 'package:outline_search_bar/outline_search_bar.dart';
import 'package:tutor_app/helper.dart';
import 'package:tutor_app/profile.dart';
import 'package:tutor_app/public_profile_page.dart';
import 'package:tutor_app/questions_page.dart';
import 'package:http/http.dart' as http;

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
      await queryAllQuestions();
      //await queryWithRecommendation();
    } else {
      await queryWithFilter();
    }
  }

  ///Determines if a given question's author has a profile picture.
  ///If it does, locate it in storage and add it to a profile picture list.
  ///Otherwise, use a placeholder.
  Future<void> downloadProfilePic(dynamic questionData) async {
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

  ///Gets the title & content of the most recently commented on question of the user
  Future<String> getMostRecentlyCommentedOnQuestion() async {
    String mostRecentQuestionCommentContent = "";
    int mostRecentTimeStamp = 0;
    await FirebaseDatabase.instance.ref().child("Records").child(getUID()).child("answers").once().
    then((value) {
      var info = value.snapshot.value as Map;
      info.forEach((key, value) async { 
        if (value > mostRecentTimeStamp) {
          mostRecentTimeStamp = value;
          await FirebaseDatabase.instance.ref().child("Questions").child(key).once().
          then((value) {
            var info2 = value.snapshot.value as Map;
            mostRecentQuestionCommentContent = info2["title"] + " " + info2["content"];
          }).catchError((error) {
            print("could not get most recent question info " + error.toString());
          });
        }
      });
    }).catchError((error) {
      print("could not get most recently commented on question " + error.toString());
    });
    return mostRecentQuestionCommentContent;
  }

  ///Makes a query for the user based on their most recently asked question or comment.
  Future<void> queryWithRecommendation() async {
    await getMostRecentlyUploadedQuestion();
    String mostRecentQuestionAndAnswer = mostRecentlyUploadedQuestion + " " + await getMostRecentlyCommentedOnQuestion();
    String url = "https://Tutor-AI-Server.bigphan.repl.co/recommend/$mostRecentQuestionAndAnswer";
    final uri = Uri.parse(url);
    final response = await http.get(uri);
    var responseData = json.decode(response.body);
    print("RESPONSE DATA: " + responseData.toString());
    for (int i = 0; i < responseData.length; i++) {
      Question questionToAdd = await getQuestionInfo(responseData[i].toString());
      setState(() {
        questions.add(questionToAdd);
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Questions"),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlineSearchBar(
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
          ),
          if (questions.isEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.all(100.0),
                padding: const EdgeInsets.all(5.0),
                child: const Text(
                  "No Questions",
                  style: TextStyle(
                    fontFamily: "Times New Roman",
                    fontSize: 25,
                  ),
                ),
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
                      const Divider(),
                    ],
                  );
                }
              ),
          ),
        ],
      ),
      );
  }

  Widget _buildRow(int index) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(int.parse(questions[index].time));
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    String questionAuthorUID = questions[index].author;
    var img = questionProfilePics[questionAuthorUID];
    String questionSubject = questions[index].subject.toString();

    //if (interestedSubjects.contains(questionSubject.toString().toLowerCase())) {
      return SizedBox(
        height: 80,
        child: Center(
          child: ListTile(
            leading: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PublicProfilePage(uid: questionAuthorUID),
                  ),
                );
              },
              child: SizedBox(
                child: img,
                height: 50,
                width: 50,
              ),
            ),
            title: Text(questions[index].title),
            subtitle: Row(
              children: [
                Text(date),
                Text(questions[index].subject),
              ],
            ),
            onTap: () {
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
