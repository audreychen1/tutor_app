import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_profile_picture/flutter_profile_picture.dart';
import 'package:intl/intl.dart';
import 'package:tutor_app/helper.dart';
import 'package:tutor_app/profile.dart';
import 'package:tutor_app/public_profile_page.dart';
import 'package:tutor_app/questions.dart';
import 'package:uuid/uuid.dart';

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
  int score;
  bool isCorrect;
  List<Comment> replies;

  Comment(this.UID, this.content, this.timeStamp, this.username, this.score, this.isCorrect, this.replies);
}

class _QuestionsPageState extends State<QuestionsPage> {
  late Question question = widget.q;
  late String authorUID = widget.q.author;
  late String questionTitle = widget.q.title;
  String name = "";
  TextEditingController commentsController = new TextEditingController();
  List<Comment> comments = [];
  ScrollController controller = new ScrollController();
  var profilePicImagesComments = new Map();
  var questionAuthorProfilePic;
  var questionUUID = new Uuid();
  var questionPic;

  _QuestionsPageState() {
    getAuthorName().then((value) => getQuestionPic().then((value) => getComments()));
  }

  Future<void> getAuthorName() async {
    await FirebaseDatabase.instance.ref().child("User").once().
    then((data) {
      var info = data.snapshot.value as Map;
      setState(() {
        info.forEach((key, value) async {
          if (key.toString().compareTo(authorUID.toString()) == 0) {
            name = value["name"];
            //gets author profile pic
            final profileRef = FirebaseStorage.instance.ref().child("profilePics/" + key + ".png");
            await profileRef.getDownloadURL().then((value) {
              setState(() {
                questionAuthorProfilePic = ProfilePicture(
                  name: 'NAME',
                  radius: 20,
                  fontsize: 20,
                  img: value,
                );
              });
            }).catchError((error) {
              print("Could not load profile pictur:" +error.toString());
              setState(() {
                questionAuthorProfilePic = ProfilePicture(
                  name: 'NAME',
                  radius: 20,
                  fontsize: 20,
                  img: "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png",
                );
              });
            });
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
  
  Future<void> getQuestionPic() async {
    await FirebaseDatabase.instance.ref().child("Questions").child(question.author + "+" + question.uuid).once().
    then((value) async {
      var info = value.snapshot.value as Map;
      final questionRef = FirebaseStorage.instance.ref().child("questionPics/" + info["author"] + "+" + info["uploadedpictime"].toString() + ".png");
        await questionRef.getDownloadURL().
        then((URL) {
          setState(() {
            questionPic = Image.network(URL);
          });
        }).catchError((onError) {
          setState(() {
            questionPic = null;
          });
        });
      print("uploaded question pic");
    }).catchError((error) {
      print("could not upload pic " + error.toString());
    });
  }

  Future<void> getComments() async {
    var correctAnswers;
    await FirebaseDatabase.instance.ref().child("Questions").child(question.author + "+" + question.uuid).child("correctAnswers").once().
    then((value) {
      correctAnswers = value.snapshot.value as Map;
    }).catchError((error) {
      print("couldn not get comments 1 " + error.toString());
    });
    await FirebaseDatabase.instance.ref().child("Questions").child(question.author + "+" + question.uuid).child("comments").once().
    then((value) {
      var info = value.snapshot.value as Map;
      comments.clear();
      info.forEach((commentName, value) async {
        String username = await getUsername(value["author"]);
        print(username);
        Comment c = new Comment(value["author"], value["content"], value["timestamp"].toString(), username, 0, false, []);
        if (correctAnswers != null && correctAnswers.containsKey(c.UID)) {
         c.isCorrect = true;
        }
        if (value.containsKey("voters")) {
          int commentScore = 0;
          var score = value["voters"] as Map;
          score.forEach((key, value) {
            commentScore += int.parse(value.toString());
          });
          c.score = commentScore;
        }
        if (value.containsKey("replies")) {
          var replies = value["replies"] as Map;
          replies.forEach((key, value) {
            c.replies.add(new Comment(value["author"], value["content"], value["timestamp"].toString(), username, 0, false, []));
          });
        }
        setState(() async {
          comments.add(c);
          //answer profile pics
          final profileRef = FirebaseStorage.instance.ref().child("profilePics/" + value["author"] + ".png");
          if (!profilePicImagesComments.containsValue(value["author"])) {
            String authorName = value["author"];
            await profileRef.getDownloadURL().then((value) {
              setState(() {
                profilePicImagesComments[authorName] = ProfilePicture(
                  name: 'NAME',
                  radius: 20,
                  fontsize: 20,
                  img: value,
                );
              });
            }).catchError((error) {
              setState(() {
                profilePicImagesComments[authorName] = const ProfilePicture(
                  name: 'NAME',
                  radius: 20,
                  fontsize: 20,
                  img: "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png",
                );
              });
            });
          }
        });
      });
    }).catchError((error) {
      print("Could not get comments: " + error.toString());
    });
  }

  Future<void> addComments() async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    String uuid = questionUUID.v4();
    await FirebaseDatabase.instance.ref().child("Records").child(getUID()).child("answers").update({
          authorUID + "+" + question.uuid: timeStamp,
    }).then((value) {
      print("successfully added answers to user's records");
    }).catchError((error) {
      print("could not add answers to user's records " + error.toString());
    });
    await FirebaseDatabase.instance.ref().child("Questions").child(question.author + "+" + question.uuid).child("comments").child(timeStamp.toString() + "+" + getUID()).update({
      "author": getUID(),
      "timestamp": timeStamp,
      "content": commentsController.text,
      "uuid" : uuid,
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
    bool alreadyVoted = false;
    bool differentScore = false;
    print(question.author + "+" + question.uuid);
    await FirebaseDatabase.instance.ref().child("Questions").child(question.author + "+" + question.uuid).child("comments").child(c.timeStamp + "+" + c.UID).child("voters").once().
    then((value) {
      print("HELLOOOO");
      var info = value.snapshot.value as Map;
      print("INFO GET UID");
      print(info[getUID()]);
      if (info.containsKey(getUID())) {
        if (info[getUID()] == rating) {
          print("Same rating as before");
          alreadyVoted = true;
        }
        if (info[getUID()] != rating) {
          print("differnet rating than before");
          differentScore = true;
        }
      }
    }).catchError((error) {
      print("could not vote " + error.toString());
    });
    if (!alreadyVoted) {
      await FirebaseDatabase.instance.ref().child("Questions").child(question.author + "+" + question.uuid).child("comments").child(c.timeStamp + "+" + c.UID).child("voters").update({
        getUID() : rating,
      }).then((value) {
        setState(() {
          if (differentScore)
            c.score += rating * 2;
          else {
            c.score += rating;
          }
        });
        print("liked comment");
      }).catchError((error) {
        print("could not like comment " + error.toString());
      });
    }
  }
  
  Future<void> markRightAnswer(Comment c) async {
    await FirebaseDatabase.instance.ref().child("Questions").child(questionTitle).child("correctAnswers").set({
      c.UID: c.timeStamp
    }).then((value) {
      setState(() {
        c.isCorrect = true;
      });
    }).catchError((onError) {
      print(onError.toString());
    });
  }

  Future<void> replyToComment(String replyComment) async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    String uuid = questionUUID.v4();
    await FirebaseDatabase.instance.ref().child("Questions").child(question.author + "+" + question.uuid).child("comments").child(replyComment).child("replies").child(timeStamp.toString() + "+" + getUID()).update({
      "author": getUID(),
      "timestamp": timeStamp,
      "content": commentsController.text,
      "uuid" : uuid,
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

  @override
  Widget build(BuildContext context) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(int.parse(question.time));
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    comments.sort((a, b) => int.parse(a.timeStamp).compareTo(int.parse(b.timeStamp)));
    print("QUESTION PIC");
    print(questionPic);

    return Scaffold(
      appBar: AppBar(
        title: Text(question.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PublicProfilePage(uid: authorUID),
                        ),
                      );
                    },
                    child: Container(
                      child: questionAuthorProfilePic,
                      height: 50,
                      width: 50,
                    )
                  ),
                  Text(
                      name,
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),
                  Text("             "),
                  Text(
                      date,
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            Container(
              alignment: Alignment.centerLeft,
              child: Column(
                children: [
                  Text(
                      question.content,
                    textAlign: TextAlign.left,
                  ),
                  Container(
                    width: 150,
                    height: 150,
                    child: questionPic
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.red,
                child: Divider()
            ),
            ListView.builder(
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
            TextField(
              controller: commentsController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Reply",
              ),
            ),
            ElevatedButton(
              onPressed: () {
                addComments().then((value) {
                  controller.jumpTo(controller.position.maxScrollExtent);
                });
              },
              child: Text("Send"),
            ),
          ],
        ),
      ),
    );
  }

  //widget for comments
  Widget _buildRow(int index){
    Comment comment = comments[index];
    print(comment.timeStamp);
    int time = int.parse(comment.timeStamp);
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(time);
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    String commenterUID = comment.UID;
    var img = profilePicImagesComments[commenterUID];
    print("IMAGE");
    print(img);

    BoxDecoration normalComment = BoxDecoration(
      border: Border.all(
        color: Colors.grey,
        width: 2,
      )
    );

    BoxDecoration correctStyle = BoxDecoration(
      border: Border.all(
        color: Colors.green,
        width: 2,
      )
    );

    return Container(
      decoration: comment.isCorrect? correctStyle : normalComment,
      padding: EdgeInsets.all(10.0),
      child: Row(
        children: [
          Column(
            children: [
              IconButton(
                onPressed: () {
                  if (comment.UID.compareTo(getUID()) != 0)
                    voteComment(comment, 1);
                },
                icon: Icon(Icons.arrow_circle_up),
              ),
              IconButton(
                onPressed: () {
                  if (comment.UID.compareTo(getUID()) != 0)
                    voteComment(comment, -1);
                },
                icon: Icon(Icons.arrow_circle_down),
              ),
            ],
          ),
          TextButton(
            child: Container(
              height: 50,
              width: 50,
              child: img,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PublicProfilePage(uid: comment.UID.toString()),
                ),
              );
            },
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(comment.content),
                ],
              ),
              Row(
                children: [
                  Text(comment.username),
                  Text(" "),
                  Text(date),
                  Text(" "),
                  Text(comment.score.toString()),
                  if (question.author.compareTo(getUID()) == 0)
                    IconButton(
                      onPressed: () {
                        markRightAnswer(comment);
                      },
                      icon: Icon(Icons.check),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReply(int index, int replyIndex) {
    Comment comment = comments[index].replies[replyIndex];
    print(comment.timeStamp);
    int time = int.parse(comment.timeStamp);
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(time);
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    String commenterUID = comment.UID;
    var img = profilePicImagesComments[commenterUID];
    print("IMAGE");
    print(img);

    BoxDecoration normalComment = BoxDecoration(
        border: Border.all(
          color: Colors.grey,
          width: 2,
        )
    );

    BoxDecoration correctStyle = BoxDecoration(
        border: Border.all(
          color: Colors.green,
          width: 2,
        )
    );

    return Container(
      decoration: comment.isCorrect? correctStyle : normalComment,
      padding: EdgeInsets.all(10.0),
      child: Row(
        children: [
          Column(
            children: [
              IconButton(
                onPressed: () {
                  if (comment.UID.compareTo(getUID()) != 0)
                    voteComment(comment, 1);
                },
                icon: Icon(Icons.arrow_circle_up),
              ),
              IconButton(
                onPressed: () {
                  if (comment.UID.compareTo(getUID()) != 0)
                    voteComment(comment, -1);
                },
                icon: Icon(Icons.arrow_circle_down),
              ),
            ],
          ),
          TextButton(
            child: Container(
              height: 50,
              width: 50,
              child: img,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PublicProfilePage(uid: comment.UID.toString()),
                ),
              );
            },
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(comment.content),
                ],
              ),
              Row(
                children: [
                  Text(comment.username),
                  Text(" "),
                  Text(date),
                  Text(" "),
                  Text(comment.score.toString()),
                  if (question.author.compareTo(getUID()) == 0)
                    IconButton(
                      onPressed: () {
                        markRightAnswer(comment);
                      },
                      icon: Icon(Icons.check),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
