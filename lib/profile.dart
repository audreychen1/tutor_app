import 'package:bs_flutter_selectbox/bs_flutter_selectbox.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:multiselect/multiselect.dart';
import 'package:tutor_app/helper.dart';
import 'package:tutor_app/history.dart';
import 'package:tutor_app/questions.dart';

class Profile extends StatefulWidget {
  const Profile({Key? key}) : super(key: key);

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {

  BsSelectBoxController subController = new BsSelectBoxController(options: [
    BsSelectBoxOption(value: "Science", text: Text("Science")),
    BsSelectBoxOption(value: "Math", text: Text("Math")),
  ]);
  TextEditingController titleController = new TextEditingController();
  TextEditingController contentController = new TextEditingController();
  int currentPageIndex = 1;
  String name = "";
  String grade = "";
  List<String> questionSubject = [];
  List<dynamic> subjects = [];

  _ProfileState() {
    getProfileInfo();
  }

  Future<void> getProfileInfo() async {

    await FirebaseDatabase.instance.ref().child("User").child(getUID()).once().
    then((value) {
      var info = value.snapshot.value as Map;
      print(info);

      setState(() {
        name = info["name"];
        grade = info["grade"];
        subjects = info["subjects"];
      });
    }).
    catchError((error) {
      print("Could not grab profile info: " + error.toString());
    });

  }

  Future<void> createQuestion() async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;

    await FirebaseDatabase.instance.ref().child("Questions").child(getUID()).child(timeStamp.toString()).set(
        {
          "title": titleController.text,
          "content": contentController.text,
          "subject": subController.getSelectedAsString(),
        }
    ).then((value) {
      print("Successfully uploaded question");
      setState(() {
        titleController.text = "";
        contentController.text = "";
      });
    }).catchError((onError){
      print("Could not upload question" + onError.toString());
    });
  }

  void showQuestionDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("New Question"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
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
                  maxLines: null,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Content",
                  ),
                ),
                BsSelectBox(
                  hintText: "Subject",
                  controller: subController,
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty && contentController.text.isNotEmpty)
                      createQuestion().then((value) {
                        Navigator.pop(context);
                      });
                  },
                  child: Text("Upload"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text("Cancel"),
              ),
            ],
          );
        }
        );
  }

  Scaffold profileUI() {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
              flex: 25,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                        height: MediaQuery.of(context).size.width * 0.5,
                        width: MediaQuery.of(context).size.width * 0.5,
                        color: Colors.black12
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Grade: " + grade,
                        style: TextStyle(
                          fontSize: 30,
                        ),
                      ),
                    ],
                  )
                ],
              )
          ),
          Expanded(
            flex: 25,
            child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: subjects.length,
                itemBuilder: (BuildContext context, int index) {
                  return Container(
                    child: Center(
                        child: Text(
                          subjects[index].toString(),
                          style: TextStyle(
                            fontSize: 20,
                          ),
                        )
                    ),
                  );
                }
            ),
          ),
          Expanded(
            flex: 50,
            child: Container(),
          ),

        ],
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            showQuestionDialog(context);
          },
          child: Icon(Icons.question_mark_sharp),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold (
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        selectedIndex: currentPageIndex,
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.question_mark),
              label: 'Questions'
          ),
          NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              label: 'Profile'
          ),
          NavigationDestination(
              icon: Icon(Icons.history),
              label: 'History'
          ),
        ],
      ),
      body: <Widget> [
        Questions(),
        profileUI(),
        History(),
      ] [currentPageIndex],
    );
  }
}
