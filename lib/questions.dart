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
  TextEditingController searchController = new TextEditingController();
  String filter = "";
  var questionProfilePics = new Map();
  List<String> interestedSubjects = [];

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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Questions"),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            flex:10,
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
            ),
          ),
          if (questions.length == 0)
            Center(
              child: Container(
                child: Text(
                  "No Questions",
                  style: TextStyle(
                    fontFamily: "Times New Roman",
                    fontSize: 25,
                  ),
                ),
                margin: EdgeInsets.all(100.0),
                padding: EdgeInsets.all(5.0),
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
              child: Container(
                child: img,
                height: 50,
                width: 50,
              ),
            ),
            title: Text(questions[index].title),
            subtitle: Row(
              children: [
                Text(date),
                Text(" "),
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
    // } else {
    //   return Container();
    // }
  }
}
