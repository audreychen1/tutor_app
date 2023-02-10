import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_profile_picture/flutter_profile_picture.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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
  //TextEditingController replyController = new TextEditingController();
  List<Comment> comments = [];
  List<Comment> replies = [];
  ScrollController controller = new ScrollController();
  var profilePicImages = new Map();
  var questionAuthorProfilePic;
  var questionUUID = new Uuid();
  var questionPic;
  bool replyButtonClicked = false;
  String repliedComment = "";
  var upPressed;
  //
  var uploadedPicFile;
  var questionPicTime;
  bool uploadQuestionPicture = false;
  bool takeQuestionPicture = false;
  var uploadedPicProfileRef;

  _QuestionsPageState() {
    getAuthorInfo().then((value) => getQuestionPic().then((value) => getComments()));
  }

  Future<void> getAuthorInfo() async {
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
                questionAuthorProfilePic = const ProfilePicture(
                  name: 'NAME',
                  radius: 20,
                  fontsize: 20,
                  img: "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png",
                );
              });
            });
          }
          final profileRef = FirebaseStorage.instance.ref().child("profilePics/" + key + ".png");
          if (!profilePicImages.containsValue(key)) {
            String authorName = key;
            await profileRef.getDownloadURL().then((value) {
              setState(() {
                profilePicImages[authorName] = ProfilePicture(
                  name: 'NAME',
                  radius: 20,
                  fontsize: 20,
                  img: value,
                );
              });
            }).catchError((error) {
              setState(() {
                profilePicImages[authorName] = const ProfilePicture(
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
      print("got author info ");
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
            result = value["name"];
          }
        });
      });
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
      //add pics for comments
      if (uploadQuestionPicture || takeQuestionPicture) {
        try {
          await uploadedPicProfileRef.putFile(uploadedPicFile);
          await FirebaseDatabase.instance.ref().child("Questions").child(getUID() + "+" + uuid).child("comments").child(timeStamp.toString() + "+" + getUID()).update({
            "uploadedpic": await uploadedPicProfileRef.getDownloadURL(),
            "uploadedpictime" : questionPicTime,
          }).then((value) {
            print("uploaded comment pic ");
          }).catchError((error) {
            print("not able to upload comment pic " + error.toString());
          });
        } catch (e) {
          print("could not upoload comment pic " + e.toString());
        }
      }
    }).catchError((error) {
      print("could not add comment " + error.toString());
    });
  }

  Future<void> voteComment(Comment c, int rating) async {
    bool alreadyVoted = false;
    bool differentScore = false;
    await FirebaseDatabase.instance.ref().child("Questions").child(question.author + "+" + question.uuid).child("comments").child(c.timeStamp + "+" + c.UID).child("voters").once().
    then((value) {
      var info = value.snapshot.value as Map;
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
    
    await FirebaseDatabase.instance.ref().child("Records").child(c.UID).child("correct answers").update({
      widget.q.uuid : widget.q.uuid,
    }).then((value) {
      print("added correct answer to users records");
    }).catchError((error) {
      print("could not add correct answers to users recordss " + error.toString());
    });
  }

  Future<void> replyToComment(String replyComment, String replyContent) async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    String uuid = questionUUID.v4();
    await FirebaseDatabase.instance.ref().child("Questions").child(question.author + "+" + question.uuid).child("comments").child(replyComment).child("replies").child(timeStamp.toString() + "+" + getUID()).update({
      "author": getUID(),
      "timestamp": timeStamp,
      "content": replyContent,
      "uuid" : uuid,
    }).
    then((value) async {
      await getComments();
      setState(() {
        //replyController.clear();
        print("replied to comment");
      });
    }).catchError((error) {
      print("could not reply to comment " + error.toString());
    });
  }

  Future<void> uploadCommentPic() async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    questionPicTime = timeStamp;
    final storageRef = FirebaseStorage.instance.ref();
    final profileRef = storageRef.child("questionPics/" + getUID() + "+" + timeStamp.toString() + ".png");
    final ImagePicker questionImagePicker = ImagePicker();
    XFile? xFile = await questionImagePicker.pickImage(
      source: ImageSource.gallery,
    );
    File f = File(xFile!.path);
    uploadedPicProfileRef = profileRef;
    uploadedPicFile = f;
    if (uploadedPicFile != null) {
      uploadQuestionPicture = true;
    }
  }

  Future<void> takeCommentPic() async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    questionPicTime = timeStamp;
    final storageRef = FirebaseStorage.instance.ref();
    final profileRef = storageRef.child("questionPics/" + getUID() + "+" + timeStamp.toString() + ".png");
    final ImagePicker questionImagePicker = ImagePicker();
    XFile? xFile = await questionImagePicker.pickImage(
      source: ImageSource.camera,
    );
    File f = File(xFile!.path);
    uploadedPicProfileRef = profileRef;
    uploadedPicFile = f;
    if (uploadedPicFile != null) {
      takeQuestionPicture = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(int.parse(question.time));
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    comments.sort((a, b) => int.parse(a.timeStamp).compareTo(int.parse(b.timeStamp)));

    return Scaffold(
      appBar: AppBar(
        leading: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: (){Navigator.of(context).push(
                MaterialPageRoute(
                        builder: (context) => Questions(),
                      ),
                    );
                },
            ),
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
          ],
        ),
        leadingWidth: 120,
        title: Row(
          children: [
            Expanded(
              flex: 25,
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            ),
            Expanded(
              flex: 75,
              child: Text(
                date,
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        toolbarHeight: 90,
        backgroundColor: Color.fromRGBO(167, 190, 169, 1),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: Container(
                alignment: Alignment.centerLeft,
                child: Text(
                    question.title,
                  style: GoogleFonts.notoSans(
                    textStyle: TextStyle(
                      fontSize: 21,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              alignment: Alignment.centerLeft,
              child: Column(
                children: [
                  Text(
                      question.content,
                    style: GoogleFonts.notoSans(
                      textStyle: TextStyle(
                        fontSize: 18,
                        color: Color.fromRGBO(99, 99, 99, 1),
                      ),
                    ),
                    textAlign: TextAlign.left,
                  ),
                  (questionPic == null) ? Container(child: Divider(thickness: 1,color: Colors.black,),) :
                  Container(
                    width: 150,
                    height: 150,
                    child: questionPic
                  ),
                ],
              ),
            ),
            ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: comments.length,
              shrinkWrap: true,
              controller: controller,
              itemBuilder: (BuildContext context, int index) {
                return Column(
                  children: [
                    _buildComments(index),
                    (index != comments.length - 1) ? Container(child: Divider(thickness: 1,color: Colors.black,),) : Container(),
                  ],
                );
              },
            ),
            Row(
              children: [
                Expanded(
                  flex: 80,
                  child: Padding(
                    padding: EdgeInsets.only(left: 10.0, right: 10.0),
                    child: SizedBox(
                      height: 50,
                      child: TextField(
                        controller: commentsController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "Reply",
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: Padding(
                    padding: EdgeInsets.only(right: 10.0),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Color.fromRGBO(132, 169, 140, 1),
                          borderRadius: BorderRadius.circular(8.0)
                      ),
                      child: TextButton(
                        onPressed: () {
                          addComments().then((value) {
                            controller.jumpTo(controller.position.maxScrollExtent);
                          });
                        },
                        child: Text(
                            "Send",
                          style: GoogleFonts.notoSans(
                            textStyle: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    uploadCommentPic();
                  },
                  icon: Icon(Icons.photo),
                ),
                IconButton(
                  onPressed: () {
                    takeCommentPic();
                  },
                  icon: Icon(Icons.camera_alt_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComments(int index){
    Comment comment = comments[index];
    int time = int.parse(comment.timeStamp);
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(time);
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    String commenterUID = comment.UID;
    var img = profilePicImages[commenterUID];
    TextEditingController replyController = new TextEditingController();

    BoxDecoration normalComment = BoxDecoration(
        border: Border.all(
          color: Colors.transparent,
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextButton(
                  child: Container(
                    height: 30,
                    width: 30,
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
              ),
              Expanded(flex: 3, child: Text(comment.username)),
              Expanded(flex: 5, child: Text(dt.month.toString() + "/" + dt.day.toString() + "/" + dt.year.toString())),
              Expanded(flex: 5, child: Text(dt.hour.toString() + ":" + dt.minute.toString())),
            ],
          ),
          Row(
            children: [
              Expanded(
                flex: 14,
                child: Column(
                  children: [
                    IconButton(
                      color: (upPressed == null) ? Colors.black : upPressed ? Colors.green : Colors.black,
                      // color: upPressed ? Colors.green : Colors.black,
                      onPressed: () {
                        if (comment.UID.compareTo(getUID()) != 0)
                          voteComment(comment, 1);
                        setState(() {
                          upPressed = true;
                        });
                      },
                      icon: Icon(Icons.arrow_circle_up),
                    ),
                    Text(comment.score.toString()),
                    IconButton(
                      color: (upPressed == null) ? Colors.black : upPressed ? Colors.black : Colors.red,
                      // color: upPressed ? Colors.black12 :  Colors.red,
                      onPressed: () {
                        if (comment.UID.compareTo(getUID()) != 0)
                          voteComment(comment, -1);
                        setState(() {
                          upPressed = false;
                        });
                      },
                      icon: Icon(Icons.arrow_circle_down),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 86,
                child: Text(
                    comment.content,
                  style: GoogleFonts.notoSans(
                    textStyle: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
              children: [
                Expanded(
                  flex: 86,
                  child: Padding(
                    padding: EdgeInsets.only(left: 15.0),
                    child: Container(
                      height: 50,
                      child: TextField(
                        controller: replyController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "Reply",
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: IconButton(
                  onPressed: () async {
                    // replyButtonClicked = true;
                    // repliedComment = comment.timeStamp + "+" + comment.UID;
                    await replyToComment(comment.timeStamp + "+" + comment.UID, replyController.text).then((value) => replyController.clear());
                  },
                  icon: Icon(Icons.reply),
                ), flex: 14,),
              ]
          ),
          if (question.author.compareTo(getUID()) == 0 && comment.UID.compareTo(getUID()) != 0)
            IconButton(
              onPressed: () {
                markRightAnswer(comment);
              },
              icon: Icon(Icons.check),
            ),
          (comment.replies.isEmpty) ? Container() : Padding(padding: EdgeInsets.only(top: 5.0), child: Divider(thickness: 0.5,color: Colors.black,),),
          ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: comment.replies.length,
            shrinkWrap: true,
            controller: controller,
            itemBuilder: (BuildContext context, int index) {
              return Column(
                children: [
                  _buildReply(comment.replies.elementAt(index), comment.replies),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReply(Comment reply, List<Comment> replies) {
    int time = int.parse(reply.timeStamp);
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(time);
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    String commenterUID = reply.UID;
    var img = profilePicImages[commenterUID];

    BoxDecoration normalComment = BoxDecoration(
        border: Border.all(
          color: Colors.transparent,
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
      decoration: reply.isCorrect? correctStyle : normalComment,
      padding: EdgeInsets.all(10.0),
      child: Row(
        children: [
          // Column(
          //   children: [
          //     IconButton(
          //       onPressed: () {
          //         if (reply.UID.compareTo(getUID()) != 0)
          //           voteComment(reply, 1);
          //       },
          //       icon: Icon(Icons.arrow_circle_up),
          //     ),
          //     IconButton(
          //       onPressed: () {
          //         if (reply.UID.compareTo(getUID()) != 0)
          //           voteComment(reply, -1);
          //       },
          //       icon: Icon(Icons.arrow_circle_down),
          //     ),
          //   ],
          // ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TextButton(
                    child: Container(
                      height: 30,
                      width: 30,
                      child: img,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PublicProfilePage(uid: reply.UID.toString()),
                        ),
                      );
                    },
                  ),
                  Text(reply.username),
                  Text(date),
                ],
              ),
              Text(reply.content),
              Row(
                children: [
                  if (question.author.compareTo(getUID()) == 0 && reply.UID.compareTo(getUID()) != 0)
                    IconButton(
                      onPressed: () {
                        markRightAnswer(reply);
                      },
                      icon: Icon(Icons.check),
                    ),
                ],
              ),
            ],
          ),
          (replies.indexOf(reply) != replies.length -1) ? Divider() : Container(),
        ],
      ),
    );
  }
}
