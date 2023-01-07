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

  Question(this.time, this.title, this.content, this.author, this.uuid);
}

class _QuestionsState extends State<Questions> {
  List<Question> questions = [];
  TextEditingController searchController = new TextEditingController();
  String filter = "";
  var questionProfilePics = new Map();

  _QuestionsState() {
    getQuestions();
        //.then((value) => getQuestionProfilePics());
    //getQuestionProfilePics();
  }

  Future<void> getQuestions() async {
    questions = [];
    await FirebaseDatabase.instance.ref().child("Questions").once().
    then((result) {
      var info = result.snapshot.value as Map;
      print(info);
      setState(() {
        info.forEach((key, value) {
          Question q;
          q = Question(value["time"].toString(), value["title"], value["content"], value["author"], value["uuid"]);
          if (value["author"].toString().compareTo(getUID()) != 0) {
            if (filter.isEmpty) {
              questions.add(q);
            } else if (q.title.contains(filter)){
              questions.add(q);
            }
          }
          final profileRef = FirebaseStorage.instance.ref().child("profilePics/" + value["author"] + ".png");
          try {
            setState(() async {
              questionProfilePics[value["author"]] = ProfilePicture(
                name: 'NAME',
                radius: 20,
                fontsize: 20,
                img: await profileRef.getDownloadURL(),
              );
            });
          } catch (error) {
            setState(() {
              questionProfilePics[value["author"]] = ProfilePicture(
                name: 'NAME',
                radius: 20,
                fontsize: 20,
                img: "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png",
              );
            });
          }
        });
      });
    });
  }
  
  // Future<void> getQuestionProfilePics() async {
  //   await FirebaseDatabase.instance.ref().child("User").once().
  //   then((value) {
  //     var info = value.snapshot.value as Map;
  //     info.forEach((key, value) {
  //       final profileRef = FirebaseStorage.instance.ref().child("profilePics/" + key + ".png");
  //       try {
  //         setState(() async {
  //           questionProfilePics[key] = ProfilePicture(
  //             name: 'NAME',
  //             radius: 20,
  //             fontsize: 20,
  //             img: await profileRef.getDownloadURL(),
  //           );
  //           print("HaLLOOOO");
  //           print(questionProfilePics);
  //         });
  //       } catch (error) {
  //         setState(() {
  //           questionProfilePics[key] = ProfilePicture(
  //             name: 'NAME',
  //             radius: 20,
  //             fontsize: 20,
  //             img: "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png",
  //           );
  //         });
  //       }
  //     });
  //   }).catchError((error) {
  //     print("could not get profile pictures " + error);
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Questions"),
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
          ListView.builder(
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
        ],
      ),
      );
  }

  Widget _buildRow(int index) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(int.parse(questions[index].time));
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    String questionAuthorUID = questions[index].author;
    var img = questionProfilePics[questionAuthorUID];

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
          subtitle: Text(date),
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
