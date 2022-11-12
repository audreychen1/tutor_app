import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tutor_app/helper.dart';
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

  Question(this.time, this.title, this.content, this.author);
}

class _QuestionsState extends State<Questions> {
  List<Question> questions = [];

  _QuestionsState() {
    getQuestions();
  }

  Future<void> getQuestions() async {
    await FirebaseDatabase.instance.ref().child("Questions").once().
    then((result) {
      var info = result.snapshot.value as Map;
      print(info);
      setState(() {
        info.forEach((key, value) {
          Question q;
          q = Question(value["time"].toString(), key, value["content"], value["author"]);
          if (value["author"].toString().compareTo(getUID()) != 0) {
            questions.add(q);
          }
        });
      });
    }).catchError((onError) {
      print("can not load questions " + onError.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Questions"),
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
