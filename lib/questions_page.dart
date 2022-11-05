import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tutor_app/questions.dart';

class QuestionsPage extends StatefulWidget {
  const QuestionsPage({Key? key, required this.q}) : super(key: key);
  final Question q;

  @override
  State<QuestionsPage> createState() => _QuestionsPageState();
}

class _QuestionsPageState extends State<QuestionsPage> {
  late Question question = widget.q;
  @override
  Widget build(BuildContext context) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(int.parse(question.time));
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    return Scaffold(
      appBar: AppBar(
        title: Text(question.title),
      ),
      body: Column(
        children: [
          Text(date),
          Text(question.author),
          Text(question.content),
        ],
      ),
    );
  }
}
