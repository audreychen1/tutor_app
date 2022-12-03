import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tutor_app/helper.dart';
import 'package:tutor_app/questions.dart';
import 'package:tutor_app/questions_page.dart';

class History extends StatefulWidget {
  const History({Key? key}) : super(key: key);

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  List<Question> questions = [];
  List<Question> answeredQuestions = [];
  bool showQuestions = true;
  bool showAnswers = true;

  _HistoryState() {
    getQuestions();
    getComments();
  }

  Future<void> getQuestions() async {
    await FirebaseDatabase.instance.ref().child("Records").child(getUID()).child("questions asked").once().
    then((value) {
      var info = value.snapshot.value as Map;
      info.forEach((key, value) async {
        await lookUpQuestion(key);
      });
    }).catchError((onError) {
      print("couldn't get questions" + onError.toString());
    });
  }

  Future<void> lookUpQuestion(String title) async {
    await FirebaseDatabase.instance.ref().child("Questions").child(title).once().
    then((value) {
      var info = value.snapshot.value as Map;
      print(info);
      setState(() {
        Question q = Question(info["time"].toString(), title, info["content"], info["author"]);
        questions.add(q);
      });
    }).catchError((onError) {
      print("couldn't look up question" + onError.toString());
    });
  }

  Future<void> lookUpQuestion2(String title) async {
    await FirebaseDatabase.instance.ref().child("Questions").child(title).once().
    then((value) {
      var info = value.snapshot.value as Map;
      print(info);
      setState(() {
        Question q = Question(info["time"].toString(), title, info["content"], info["author"]);
        answeredQuestions.add(q);
      });
    }).catchError((onError) {
      print("couldn't look up question" + onError.toString());
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

  // Future<void> lookUpCommnents(String questionTitle) async {
  //   await FirebaseDatabase.instance.ref().child("Questions").child(questionTitle).child("comments").once().
  //   then((value) {
  //     var info = value.snapshot.value as Map;
  //     print(info);
  //     setState(() {
  //       Comment c = new Comment(getUID(), info["content"], info["timeStamp"], info["username"], info["score"], info["isCorrect"]);
  //     });
  //   }).catchError((error) {
  //     print("could not look up comment" + error.toString());
  //   });
  // }

  // Future<void> lookUpComments(String questionTitle) async {
  //   await FirebaseDatabase.instance.ref().child("Questions").child(questionTitle).once().
  //   then((value) {
  //     var info = value.snapshot.value as Map;
  //     print(info);
  //     setState(() {
  //       Question q = Question(info["time"].toString(), questionTitle, info["content"], info["author"]);
  //       answeredQuestions.add(q);
  //       print(answeredQuestions);
  //     });
  //   }).catchError((error) {
  //     print("could not look up comment" + error.toString());
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    void showQuestion() {
      setState(() {
        showQuestions = !showQuestions;
      });
    }
    void showAnswer() {
      setState(() {
        showAnswers = !showAnswers;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("History"),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
              child: ElevatedButton(
                onPressed: () {
                  showQuestion();
                },
                child: Text("Questions"),
              )
          ),
          Expanded(
            flex: 45,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Visibility(
                  visible: showQuestions,
                  child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: questions.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Column(
                          children: [
                            _buildRow(index, questions),
                            Divider(),
                          ],
                        );
                      }
                  ),
                ),
              ],
            ),
          ),
          Expanded(
              flex: 5,
              child: ElevatedButton(
                onPressed: () {
                  showAnswer();
                },
                child: Text("Answers"),
              )
          ),
          Expanded(
            flex: 45,
              child:Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Visibility(
                    visible: showAnswers,
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: answeredQuestions.length,
                        itemBuilder: (BuildContext context, int index) {
                          return Column(
                            children: [
                              _buildRow(index, answeredQuestions),
                              Divider(),
                            ],
                          );
                        }
                    ),
                  ),
                ],
              ),
          )
        ],
      )
    );
  }

  Widget _buildRow(int index, List<Question> list) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(int.parse(list[index].time));
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    return Container(
      height: 80,
      child: Center(
        child: ListTile(
          leading: Icon(Icons.bed),
          title: Text(list[index].title),
          subtitle: Text(date),
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
