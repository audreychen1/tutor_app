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

  _HistoryState() {
    getQuestions();
  }

  Future<void> getQuestions() async {
    await FirebaseDatabase.instance.ref().child("Records").child(getUID()).once().
    then((value) {
      var info = value.snapshot.value as Map;
      info.forEach((key, value) async {
        await lookUpQuestion(key);
      });
    }).catchError((onError) {
      print(onError);
    });
  }

  Future<void> lookUpQuestion(String title) async {
    await FirebaseDatabase.instance.ref().child("Questions").child(title).once().
    then((value) {
      var info = value.snapshot.value as Map;
      setState(() {
        Question q = Question(info["time"].toString(), title, info["content"], info["author"]);
        questions.add(q);
      });
    }).catchError((onError) {
      print(onError);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("History"),
      ),
      body: ListView.builder(
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
    );
  }

  Widget _buildRow(int index) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(int.parse(questions[index].time));
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    return Container(
      height: 80,
      child: Center(
        child: ListTile(
          leading: Icon(Icons.bed),
          title: Text(questions[index].title),
          subtitle: Text(date),
          onTap: () {
            //Navigator.of(context).push(
              //MaterialPageRoute(
                //builder: (context) => const QuestionsPage(q: questions[index]),
              //),
            //);
          },
        ),
      ),
    );
  }
}
