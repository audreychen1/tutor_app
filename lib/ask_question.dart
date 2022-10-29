import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:tutor_app/helper.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  TextEditingController titleController = new TextEditingController();
  TextEditingController contentController = new TextEditingController();

  Future<void> createQuestion() async {
    await FirebaseDatabase.instance.ref().child("Questions").child(getUID()).set(
      {
        "title": titleController.text,
        "content": contentController.text,
      }
    ).then((value) {
      print("Successfully uploaded question");
    }).catchError((onError){
      print("Could not upload question" + onError.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),
      ),
      body: Column(
        children: [
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: "Title",
            ),
          ),
          TextField(
            controller: contentController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: "Content",
            ),
          ),

          ElevatedButton(
              onPressed: () {
                createQuestion();
              },
              child: Text("Upload"),
          ),
        ],
      ),
    );
  }
}
