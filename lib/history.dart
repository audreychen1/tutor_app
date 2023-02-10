import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_profile_picture/flutter_profile_picture.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tutor_app/helper.dart';
import 'package:tutor_app/public_profile_page.dart';
import 'package:tutor_app/questions.dart';
import 'package:tutor_app/questions_page.dart';

class History extends StatefulWidget {
  const History({Key? key}) : super(key: key);

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> with TickerProviderStateMixin{
  List<Question> questions = [];
  List<Question> answeredQuestions = [];
  var questionProfilePics = new Map();
  var answerProfilePics = new Map();

  _HistoryState() {
    getComments();
    getQuestions();
  }

  Future<void> getQuestions() async {
    await FirebaseDatabase.instance.ref().child("Records").child(getUID()).child("questions asked").once().
    then((value) {
      var info = value.snapshot.value as Map;
      info.forEach((key, uuid) async {
        await lookUpQuestion(getUID()+"+"+uuid);
      });
    }).catchError((onError) {
      print("couldn't get questions" + onError.toString());
    });
  }

  //get the questions that the user made
  Future<void> lookUpQuestion(String title) async {
    await FirebaseDatabase.instance.ref().child("Questions").child(title).once().
    then((value) async {
      var info = value.snapshot.value as Map;
      setState(() {
        Question q = Question(info["time"].toString(), info["title"], info["content"], info["author"], info["uuid"], info["subject"]);
        questions.add(q);
      });
      final profileRef = FirebaseStorage.instance.ref().child("profilePics/" + info["author"] + ".png");
      await profileRef.getDownloadURL().then((value2) async {
        String url = await profileRef.getDownloadURL();
        setState(() {
          questionProfilePics[info["author"]] = ProfilePicture(
            name: 'NAME',
            radius: 20,
            fontsize: 20,
            img: url,
          );
        });
      }).catchError((error) {
        setState(() {
          questionProfilePics[info["author"]] = ProfilePicture(
            name: 'NAME',
            radius: 20,
            fontsize: 20,
            img: "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png",
          );
        });
      });
    }).catchError((onError) {
      print("couldn't look up question" + onError.toString());
    });
  }

  //get questions the user answered
  Future<void> lookUpQuestion2(String title) async {
    await FirebaseDatabase.instance.ref().child("Questions").child(title).once().
    then((value) async {
      var info = value.snapshot.value as Map;
      print(info);
      setState(() {
        Question q = Question(info["time"].toString(), info["title"], info["content"], info["author"], info["uuid"], info["subject"]);
        answeredQuestions.add(q);
      });
      final profileRef = FirebaseStorage.instance.ref().child("profilePics/" + info["author"] + ".png");
      await profileRef.getDownloadURL().then((value2) async {
        String url = await profileRef.getDownloadURL();
        setState(() {
          answerProfilePics[info["author"]] = ProfilePicture(
            name: 'NAME',
            radius: 20,
            fontsize: 20,
            img: url,
          );
        });
      }).catchError((error) {
        setState(() {
          answerProfilePics[info["author"]] = ProfilePicture(
            name: 'NAME',
            radius: 20,
            fontsize: 20,
            img: "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png",
          );
        });
      });
    }).catchError((onError) {
      print("couldn't look up question 1 " + onError.toString());
    });
  }

  Future<void> getComments() async {
    await FirebaseDatabase.instance.ref().child("Records").child(getUID()).child("answers").once().
    then((value) {
      var info = value.snapshot.value as Map;
      info.forEach((key, value){
        lookUpQuestion2(key);
      });
    }).catchError((error) {
      print("could not get comments" + error.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    late TabController _tabController = new TabController(length: 2, vsync: this);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(82, 121, 111, 1),
        elevation: 3,
        automaticallyImplyLeading: false,
        title: Center(
          child: Container(
            child: Text(
                "History",
              style: GoogleFonts.oswald(
                textStyle: TextStyle(
                  fontSize: 32,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
        bottom: TabBar(
          indicatorColor: Colors.grey,
          controller: _tabController,
          tabs: <Widget> [
            Tab(
              child: Text(
                  "Questions",
                style: GoogleFonts.notoSans(
                  textStyle: TextStyle(
                    fontSize: 20,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            Tab(
              child: Text(
                "Answers",
                style: GoogleFonts.notoSans(
                  textStyle: TextStyle(
                    fontSize: 20,
                    color: Colors.black,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          if (questions.length == 0)
            Center(
                child: Text(
                  "No Questions Asked",
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: "Times New Roman",
                  ),
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
                    _buildQuestions(index, questions),
                    Divider(),
                  ],
                );
              }
          ),
          if (answeredQuestions.length == 0)
            Center(
              child: Text(
                "No Questions Answered",
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: "Times New Roman",
                ),
              ),
            ),
          if (answeredQuestions.length != 0)
          ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              itemCount: answeredQuestions.length,
              itemBuilder: (BuildContext context, int index) {
                return Column(
                  children: [
                    _buildAnsweredQuestions(index, answeredQuestions),
                    Divider(),
                  ],
                );
              }
              ),
        ],
      ),
    );
  }

  Widget _buildQuestions(int index, List<Question> list) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(int.parse(list[index].time));
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    String questionAuthorUID = list[index].author;
    var img = questionProfilePics[questionAuthorUID];

    return Container(
      height: 132,
      child: Center(
        child: ListTile(
          // leading: TextButton(
          //   onPressed: () {
          //     Navigator.of(context).push(
          //       MaterialPageRoute(
          //         builder: (context) => PublicProfilePage(uid: questionAuthorUID),
          //       ),
          //     );
          //   },
          //   child: Container(
          //     child: img,
          //     height: 60,
          //     width: 50,
          //   ),
          // ),
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
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => QuestionsPage(q: list[index]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnsweredQuestions(int index, List<Question> list) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(int.parse(list[index].time));
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    String questionAuthorUID = list[index].author;
    var img = questionProfilePics[questionAuthorUID];
    return Container(
      height: 132,
      child: Center(
        child: ListTile(
          // leading: TextButton(
          //   onPressed: () {
          //     Navigator.of(context).push(
          //       MaterialPageRoute(
          //         builder: (context) => PublicProfilePage(uid: questionAuthorUID),
          //       ),
          //     );
          //   },
          //   child: Container(
          //     child: img,
          //     height: 60,
          //     width: 50,
          //   ),
          // ),
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
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => QuestionsPage(q: list[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}