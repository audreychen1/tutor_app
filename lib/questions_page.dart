import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tutor_app/helper.dart';
import 'package:tutor_app/questions.dart';

class QuestionsPage extends StatefulWidget {
  const QuestionsPage({Key? key, required this.q}) : super(key: key);
  final Question q;

  @override
  State<QuestionsPage> createState() => _QuestionsPageState();
}

class Comment {
  String UID;
  String content;
  String timeStamp;
  String username;

  Comment(this.UID, this.content, this.timeStamp, this.username);
}

class _QuestionsPageState extends State<QuestionsPage> {
  late Question question = widget.q;
  late String authorUID = widget.q.author;
  late String questionTitle = widget.q.title;
  String name = "";
  TextEditingController commentsController = new TextEditingController();
  List<Comment> comments = [];
  ScrollController controller = new ScrollController();

  _QuestionsPageState() {
    getAuthorName().then((value) => getComments());
  }

  Future<void> getAuthorName() async {
    await FirebaseDatabase.instance.ref().child("User").once().
    then((data) {
      var info = data.snapshot.value as Map;
      setState(() {
        info.forEach((key, value) {
          if (key.toString().compareTo(authorUID.toString()) == 0) {
            name = value["name"];
          }
        });
      });
      print(info);
    }).catchError((onError) {
      print("was not able to get name " + onError.toString());
    });
  }

  Future<String> getUsername(String UID) async {
    String result = "";
    await FirebaseDatabase.instance.ref().child("User").once().
    then((data) {
      var info = data.snapshot.value as Map;
      setState(() {
        info.forEach((key, value) {
          if (key.toString().compareTo(UID) == 0) {
            print(value["name"]);
            result = value["name"];
          }
        });
      });
      print(info);
    }).catchError((onError) {
      print("was not able to get name " + onError.toString());
    });
    return result;
  }

  Future<void> getComments() async {
    await FirebaseDatabase.instance.ref().child("Questions").child(questionTitle).child("comments").once().
    then((value) {
      var info = value.snapshot.value as Map;
      comments.clear();
      info.forEach((timeStamp, value) async {
        String username = await getUsername(value["author"]);
        print(username);
        Comment c = new Comment(value["author"], value["content"], timeStamp, username);
        setState(() {
          comments.add(c);
        });
      });
    }).catchError((error) {
      print("Could not get comments: " + error.toString());
    });
  }

  Future<void> addComments() async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    await FirebaseDatabase.instance.ref().child("Questions").child(questionTitle).child("comments").child(timeStamp.toString()).update({
      "author": getUID(),
      "content": commentsController.text,
    }).
    then((value) async {
      await getComments();
      setState(() {
        commentsController.clear();
      });
    }).catchError((error) {
      print("could not add comment " + error.toString());
    });
  }

  Future<void> voteComment(Comment c, int rating) async {
    await FirebaseDatabase.instance.ref().child("Questions").child(questionTitle).child("comments").child(c.timeStamp).child("voters").update({
      getUID(): rating,
    }).then((value) {
      print("liked comment");
    }).catchError((error) {
      print("could not like comment " + error.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(int.parse(question.time));
    String date = DateFormat('y/M/d   kk:mm').format(dt);

    comments.sort((a, b) => int.parse(a.timeStamp).compareTo(int.parse(b.timeStamp)));

    return Scaffold(
      appBar: AppBar(
        title: Text(question.title),
      ),
      body: Column(
        children: [
            Expanded(
              flex: 10,
              child: Row(
                children: [
                  Text(
                      name,
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),
                  Text("                                                 "),
                  Text(
                      date,
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            flex: 15,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Text(
                  question.content,
                textAlign: TextAlign.left,
              ),
            ),
          ),
          Expanded(
            flex: 5,
              child: Divider(),
          ),
          Expanded(
            flex: 55,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: comments.length,
                shrinkWrap: true,
                controller: controller,
                itemBuilder: (BuildContext context, int index) {
                  return Column(
                    children: [
                      _buildRow(index),
                      Divider(),
                    ],
                  );
                },
              ),
          ),
          Expanded(
            flex: 10,
            child: TextField(
              controller: commentsController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Reply",
              ),
            ),
          ),
          Expanded(
            flex: 5,
              child: ElevatedButton(
                onPressed: () {
                  addComments().then((value) {
                    controller.jumpTo(controller.position.maxScrollExtent);
                  });
                },
                child: Text("Send"),
              ),
          ),
        ],
      ),
    );
  }

  //widget for comments
  Widget _buildRow(int index){
    Comment comment = comments[index];
    int time = int.parse(comment.timeStamp);
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(time);
    String date = DateFormat('y/M/d   kk:mm').format(dt);

    return ListTile(
      title: Text(comment.content),
      subtitle: Row(
        children: [
          Text(comment.username),
          Text("            "),
          Text(date),
          if (comment.UID.compareTo(getUID()) != 0)
          Row(
            children: [
              IconButton(
                onPressed: () {
                  voteComment(comment, 1);
                },
                icon: Icon(Icons.arrow_circle_up),
              ),
              IconButton(
                onPressed: () {
                  voteComment(comment, -1);
                },
                icon: Icon(Icons.arrow_circle_down),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
