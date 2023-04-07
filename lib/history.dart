import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
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
  var questionViews = new Map();
  var questionNumReplies = new Map();
  int? segmentValue = 0;
  bool onQuestions = true;
  bool showSearchBar = false;
  var scrollController = new ScrollController();
  TextEditingController searchController = TextEditingController();
  String filter = "";

  _HistoryState() {
    getComments();
    getQuestions();
  }

  Future<void> getQuestions() async {
    questions.clear();
    await FirebaseDatabase.instance.ref().child("Records").child(getUID()).child("questions asked").once().
    then((value) {
      var info = value.snapshot.value as Map;
      info.forEach((uuid, timestamp) async {
        await lookUpQuestionsUserCreated(getUID()+"+"+uuid);
      });
    }).catchError((onError) {
      print("couldn't get questions" + onError.toString());
    });
  }

  //get the questions that the user made
  Future<void> lookUpQuestionsUserCreated(String title) async {
    await FirebaseDatabase.instance.ref().child("Questions").child(title).once().
    then((value) {
      var info = value.snapshot.value as Map;
      if (mounted) {
        setState(() {
          Question q = Question(info["time"].toString(), info["title"], info["content"], info["author"], info["uuid"], info["subject"]);
          if (info["title"].toString().contains(filter)) {
            setState(() {
              questions.add(q);
            });
          }
          if (!questionProfilePics.containsKey(info["author"])) {
            getProfilePics(questionProfilePics, info["author"]);
          }
          if (info.containsKey("views")) {
            setState(() {
              questionViews[info["author"] + "+" + info["uuid"]] = info["views"];
            });
          }
          if (info.containsKey("comments")) {
            setState(() {
              questionNumReplies[info["author"] + "+" + info["uuid"]] = info["comments"].length;
            });
          }
        });
      }
    }).catchError((onError) {
      print("couldn't look up question" + onError.toString());
    });
  }

  Future<void> getProfilePics(Map<dynamic, dynamic> profilePictureMap, String author) async {
    final picRef = await FirebaseStorage.instance.ref().child("profilePics/" + author + ".png");
      picRef.getDownloadURL().then((value) {
        if (mounted) {
          setState(() {
            profilePictureMap[author] = ProfilePicture(
              name: '',
              radius: 21,
              fontsize: 20,
              img: value,
            );
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            profilePictureMap[author] = const ProfilePicture(
              name: '',
              radius: 21,
              fontsize: 20,
              img: "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png",
            );
          });
        }
      });
  }

  //get questions the user answered
  Future<void> lookUpQuestionsUserAnswered(String title) async {
    await FirebaseDatabase.instance.ref().child("Questions").child(title).once().
    then((value) {
      var info = value.snapshot.value as Map;
      print(info);
      if (mounted) {
        setState(() {
          Question q = Question(info["time"].toString(), info["title"], info["content"], info["author"], info["uuid"], info["subject"]);
          if (info["title"].toString().contains(filter)) {
            setState(() {
              answeredQuestions.add(q);
            });
          }
          if (!answerProfilePics.containsKey(info["author"])) {
            getProfilePics(answerProfilePics, info["author"]);
          }
          if (info.containsKey("views")) {
            setState(() {
              questionViews[info["author"] + "+" + info["uuid"]] = info["views"];
            });
          }
          if (info.containsKey("comments")) {
            setState(() {
              questionNumReplies[info["author"] + "+" + info["uuid"]] = info["comments"].length;
            });
          }
        });
      }
    }).catchError((onError) {
      print("couldn't look up question 1 " + onError.toString());
    });
  }

  Future<void> getComments() async {
    answeredQuestions.clear();
    await FirebaseDatabase.instance.ref().child("Records").child(getUID()).child("answers").once().
    then((value) {
      var info = value.snapshot.value as Map;
      info.forEach((key, value){
        lookUpQuestionsUserAnswered(key);
      });
    }).catchError((error) {
      print("could not get comments" + error.toString());
    });
  }

  Future<void> viewQuestion(String questionUUID) async {
    int views = 0;
    await FirebaseDatabase.instance.ref().child("Questions").child(questionUUID).once().
    then((value) {
      var info = value.snapshot.value as Map;
      views = info["views"];
    }).catchError((error) {
      print("could not get num views " + error.toString());
    });
    await FirebaseDatabase.instance.ref().child("Questions").child(questionUUID).update({
      "views" : views + 1,
    }
    ).then((value) {
      print("updated num views");
    }).catchError((error) {
      print("could not update num views " + error.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Text(
                "History",
                style: GoogleFonts.poppins(
                  fontSize: 32,
                ),
              ),
            ),
          ),
          trailing: Material(
            child: IconButton(
              icon: Icon(Icons.search),
              onPressed: (){
                setState(() {
                  showSearchBar = !showSearchBar;
                });
              },
            ),
          ),
          border: null,
          automaticallyImplyLeading: false,
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (showSearchBar)
                Expanded(
                  flex: 10,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 18.0, right: 18.0, top: 15.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                          color: Color.fromRGBO(225, 225, 225, 0.5),
                        border: Border.all(
                          color: Color.fromRGBO(120, 119, 128, 0.75),
                        )
                      ),
                      child: CupertinoSearchTextField(
                        controller: searchController,
                        placeholder: "Search",
                        suffixIcon: Icon(Icons.clear),
                        onSuffixTap: () {
                          searchController.clear();
                          filter = "";
                          if (onQuestions) {
                            getQuestions();
                          }
                          if (!onQuestions) {
                            getComments();
                          }
                        },
                        onSubmitted: (value) {
                          filter = value.toString();
                          if (onQuestions) {
                            getQuestions();
                          }
                          if (!onQuestions) {
                            getComments();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              Expanded(
                flex: 10,
                child: Row(
                  children: [
                    if (onQuestions)
                      Expanded(
                        flex: 50,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 18.0, right: 6.0, top: 5.0),
                          child: GestureDetector(
                            onTap: (){
                              setState(() {
                                onQuestions = true;
                              });
                            },
                            child: Container(
                              height: 55,
                              width: 105,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Color.fromRGBO(0, 0, 0, 1),
                                  width: 2.0,
                                ),
                                color: Color.fromRGBO(110, 156, 144, 1),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: ListTile(
                                onTap: (){
                                  setState(() {
                                    onQuestions = true;
                                  });
                                },
                                leading: Icon(Icons.question_mark),
                                title: Text(
                                  "Questions",
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!onQuestions)
                      Expanded(
                        flex: 50,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 18.0, right: 6.0, top: 5.0),
                          child: GestureDetector(
                            onTap: (){
                              setState(() {
                                onQuestions = true;
                              });
                            },
                            child: Container(
                              height: 55,
                              width: 105,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Color.fromRGBO(110, 156, 144, 1),
                                ),
                                color: Color.fromRGBO(110, 156, 144, 1),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: ListTile(
                                onTap: (){
                                  setState(() {
                                    onQuestions = true;
                                  });
                                },
                                leading: Icon(Icons.question_mark),
                                title: Text(
                                    "Questions",
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (onQuestions)
                      Expanded(
                        flex: 50,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6.0, right: 18.0, top: 5.0),
                          child: GestureDetector(
                            onTap: (){
                              setState(() {
                                onQuestions = false;
                              });
                            },
                            child: Container(
                              height: 55,
                              width: 105,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Color.fromRGBO(110, 156, 144, 1),
                                ),
                                color: Color.fromRGBO(110, 156, 144, 1),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: ListTile(
                                onTap: (){
                                  setState(() {
                                    onQuestions = false;
                                  });
                                },
                                leading: Icon(Icons.reply),
                                title: Text(
                                  "Answers",
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!onQuestions)
                      Expanded(
                        flex: 50,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6.0, right: 18.0, top: 5.0),
                          child: GestureDetector(
                            onTap: (){
                              setState(() {
                                onQuestions = false;
                              });
                            },
                            child: Container(
                              height: 55,
                              width: 105,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Color.fromRGBO(0, 0, 0, 1),
                                  width: 2.0,
                                ),
                                color: Color.fromRGBO(110, 156, 144, 1),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: ListTile(
                                onTap: (){
                                  setState(() {
                                    onQuestions = false;
                                  });
                                },
                                leading: Icon(Icons.reply),
                                title: Text(
                                  "Answers",
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onQuestions)
                if (questions.isEmpty)
                  Expanded(
                    flex: 80,
                    child: Center(
                      child: Text(
                        "No Questions Asked",
                        style: TextStyle(
                          fontSize: 20,
                          fontFamily: "Times New Roman",
                        ),
                      ),
                    ),
                  ),
              if (onQuestions)
                if (questions.isNotEmpty)
                  Expanded(
                    flex: 80,
                    child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: questions.length,
                        controller: scrollController,
                        itemBuilder: (BuildContext context, int index) {
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 6.9),
                                child: _buildQuestions(index, questions),
                              ),
                            ],
                          );
                        }
                    ),
                  ),
              if (!onQuestions)
                if (answeredQuestions.isEmpty)
                  Expanded(
                    flex: 80,
                    child: Center(
                      child: Text(
                        "No Questions Answered",
                        style: TextStyle(
                          fontSize: 20,
                          fontFamily: "Times New Roman",
                        ),
                      ),
                    ),
                  ),
              if (!onQuestions)
                if (answeredQuestions.isNotEmpty)
                  Expanded(
                    flex: 80,
                    child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: answeredQuestions.length,
                        itemBuilder: (BuildContext context, int index) {
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 6.9),
                                child: _buildAnsweredQuestions(index, answeredQuestions),
                              ),
                            ],
                          );
                        }
                    ),
                  ),
            ],
          ),
        ),
      ),
    );

    // late TabController _tabController = new TabController(length: 2, vsync: this);
    // return Scaffold(
    //   appBar: AppBar(
    //     backgroundColor: Color.fromRGBO(255, 255, 255, 0.5),
    //     //backgroundColor: Color.fromRGBO(82, 121, 111, 1),
    //     elevation: 0,
    //     automaticallyImplyLeading: false,
    //     title: Center(
    //       child: Container(
    //         child: Text(
    //           "History",
    //           style: GoogleFonts.poppins(
    //             textStyle: TextStyle(
    //               fontSize: 32,
    //               color: Colors.black,
    //             ),
    //           ),
    //         ),
    //       ),
    //     ),
    //     bottom: TabBar(
    //       isScrollable: true,
    //       controller: _tabController,
    //       indicatorColor: Colors.black,
    //       indicatorWeight: 3.0,
    //       tabs: <Widget> [
    //         Tab(
    //           child: Text(
    //             "Questions",
    //             style: GoogleFonts.notoSans(
    //               textStyle: TextStyle(
    //                 fontSize: 20,
    //                 color: Colors.black,
    //               ),
    //             ),
    //           ),
    //         ),
    //         Tab(
    //           child: Text(
    //             "Answers",
    //             style: GoogleFonts.notoSans(
    //               textStyle: TextStyle(
    //                 fontSize: 20,
    //                 color: Colors.black,
    //               ),
    //             ),
    //           ),
    //         )
    //       ],
    //     ),
    //   ),
    //   body: TabBarView(
    //     controller: _tabController,
    //     children: [
    //       if (questions.length == 0)
    //         Center(
    //             child: Text(
    //               "No Questions Asked",
    //               style: TextStyle(
    //                 fontSize: 20,
    //                 fontFamily: "Times New Roman",
    //               ),
    //             ),
    //         ),
    //       if (questions.length != 0)
    //       ListView.builder(
    //           shrinkWrap: true,
    //           padding: const EdgeInsets.all(8),
    //           itemCount: questions.length,
    //           itemBuilder: (BuildContext context, int index) {
    //             return Column(
    //               children: [
    //                 Padding(
    //                   padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 6.9),
    //                   child: _buildQuestions(index, questions),
    //                 ),
    //                 //Divider(),
    //               ],
    //             );
    //           }
    //       ),
    //       if (answeredQuestions.length == 0)
    //         Center(
    //           child: Text(
    //             "No Questions Answered",
    //             style: TextStyle(
    //               fontSize: 20,
    //               fontFamily: "Times New Roman",
    //             ),
    //           ),
    //         ),
    //       if (answeredQuestions.length != 0)
    //       ListView.builder(
    //           shrinkWrap: true,
    //           padding: const EdgeInsets.all(8),
    //           itemCount: answeredQuestions.length,
    //           itemBuilder: (BuildContext context, int index) {
    //             return Column(
    //               children: [
    //                 Padding(
    //                   padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 6.9),
    //                   child: _buildAnsweredQuestions(index, answeredQuestions),
    //                 ),
    //               ],
    //             );
    //           }
    //           ),
    //     ],
    //   ),
    //  );
  }

  Widget _buildQuestions(int index, List<Question> list) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(int.parse(list[index].time));
    String date = DateFormat('y/M/d   kk:mm').format(dt);
    String questionAuthorUID = list[index].author;
    var img = questionProfilePics[questionAuthorUID];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Color.fromRGBO(225, 225, 225, 1),
        ),
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(225, 225, 225, 1),
            blurRadius: 12.0,
          ),
        ],
      ),
      height: 170,
      child: Center(
        child: ListTile(
          title: Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Text(
              questions[index].title,
              style: GoogleFonts.notoSans(
                textStyle: TextStyle(
                  fontSize: 17,
                ),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          subtitle: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 5.0, bottom: 5.0),
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
              ),
              Row(
                children: [
                  if (questions[index].subject.compareTo("Math") == 0)
                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(96, 189, 219, 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                        child: Text(
                            questions[index].subject
                        ),
                      ),
                    ),
                  if (questions[index].subject.compareTo("Science") == 0)
                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(117, 209, 152, 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                        child: Text(
                            questions[index].subject
                        ),
                      ),
                    ),
                  if (questions[index].subject.compareTo("Language") == 0)
                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(182, 144, 212, 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                        child: Text(
                            questions[index].subject
                        ),
                      ),
                    ),
                  if (questions[index].subject.compareTo("History") == 0)
                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(227, 127, 127, 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                        child: Text(
                            questions[index].subject
                        ),
                      ),
                    ),
                  if (questions[index].subject.compareTo("English") == 0)
                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(255, 255, 145, 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                        child: Text(
                            questions[index].subject
                        ),
                      ),
                    ),
                  Container(
                    width: 10,
                  ),
                  questionViews.containsKey(questions[index].author + "+" + questions[index].uuid) ?
                  Container(
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(207, 207, 207, 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                      child: Padding(
                        padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                        child: Text(
                            questionViews[questions[index].author + "+" + questions[index].uuid].toString() + " views"
                        ),
                      ),
                  ) :
                  Container(
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(207, 207, 207, 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                      child: Text(
                          "0 views"
                      ),
                    ),
                  ),
                  Container(
                    width: 10,
                  ),
                  questionNumReplies.containsKey(questions[index].author + "+" + questions[index].uuid) ?
                  Container(
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(167, 190, 169, 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                      child: Text(
                        questionNumReplies[questions[index].author + "+" + questions[index].uuid].toString() + " replies"
                      ),
                    ),
                  ) : Container(
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(167, 190, 169, 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                      child: Text(
                          "0 replies"
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [//60 40 40
                  Expanded(flex: 42, child: Container()),
                  Expanded(flex: 25, child: TextButton(
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
                  Expanded(flex: 25, child: Text(dt.month.toString() + "/" + dt.day.toString() + "/" + dt.year.toString())),
                  Expanded(flex: 15, child: Text(dt.hour.toString() + ":" + dt.minute.toString())),
                ],
              ),
            ],
          ),
          onTap: () {
            viewQuestion(questions[index].author + "+" + questions[index].uuid);
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
    var img = answerProfilePics[questionAuthorUID];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Color.fromRGBO(225, 225, 225, 1),
        ),
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(225, 225, 225, 1),
            blurRadius: 12.0,
          ),
        ],
      ),
      height: 170,
      child: Center(
        child: ListTile(
          title: Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Text(
              answeredQuestions[index].title,
              style: GoogleFonts.notoSans(
                textStyle: TextStyle(
                  fontSize: 17,
                ),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          subtitle: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 5.0, bottom: 5.0),
                  child: Text(
                    answeredQuestions[index].content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSans(
                      textStyle: TextStyle(
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  if (questions[index].subject.compareTo("Math") == 0)
                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(96, 189, 219, 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                        child: Text(
                            questions[index].subject
                        ),
                      ),
                    ),
                  if (questions[index].subject.compareTo("Science") == 0)
                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(117, 209, 152, 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                        child: Text(
                            questions[index].subject
                        ),
                      ),
                    ),
                  if (questions[index].subject.compareTo("Language") == 0)
                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(182, 144, 212, 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                        child: Text(
                            questions[index].subject
                        ),
                      ),
                    ),
                  if (questions[index].subject.compareTo("History") == 0)
                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(227, 127, 127, 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                        child: Text(
                            questions[index].subject
                        ),
                      ),
                    ),
                  if (questions[index].subject.compareTo("English") == 0)
                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(255, 255, 145, 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                        child: Text(
                            questions[index].subject
                        ),
                      ),
                    ),
                  Container(
                    width: 10,
                  ),
                  questionViews.containsKey(questions[index].author + "+" + questions[index].uuid) ?
                  Container(
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(207, 207, 207, 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                      child: Text(
                          questionViews[questions[index].author + "+" + questions[index].uuid].toString() + " views"
                      ),
                    ),
                  ) :
                  Container(
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(207, 207, 207, 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                      child: Text(
                          "0 views"
                      ),
                    ),
                  ),
                  Container(
                    width: 10,
                  ),
                  questionNumReplies.containsKey(questions[index].author + "+" + questions[index].uuid) ?
                  Container(
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(167, 190, 169, 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                      child: Text(
                          questionNumReplies[questions[index].author + "+" + questions[index].uuid].toString() + " replies"
                      ),
                    ),
                  ) : Container(
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(167, 190, 169, 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
                      child: Text(
                          "0 replies"
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [//60 40 40
                  Expanded(flex: 42, child: Container()),
                  Expanded(flex: 25, child: TextButton(
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
                  Expanded(flex: 25, child: Text(dt.month.toString() + "/" + dt.day.toString() + "/" + dt.year.toString())),
                  Expanded(flex: 15, child: Text(dt.hour.toString() + ":" + dt.minute.toString())),
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