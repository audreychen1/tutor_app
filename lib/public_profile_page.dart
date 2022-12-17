import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_profile_picture/flutter_profile_picture.dart';

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({Key? key, required this.uid}) : super(key: key);
  final String uid;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  late String userUID = widget.uid;
  String name = "";
  String grade = "";
  List<dynamic> subjects = [];
  var img;

  _PublicProfilePageState() {
    getUserInfo();
  }

  Future<void> getUserInfo() async {
    var info;
    await FirebaseDatabase.instance.ref().child("User").once().
    then((value) {
      info = value.snapshot.value as Map;
      info.forEach((key, value) {
        setState(() {
          if (key == userUID) {
            name = value["name"];
            grade = value["grade"];
            subjects = value["subjects"];
          }
        });
      });
    }).catchError((error) {
      print("could not get user info " + error.toString());
    });
    try {
      setState(() {
        img = ProfilePicture(
            name: "NAME",
            radius: 31,
            fontsize: 21,
          img: info[userUID]["profilepic"],
        );
      });
    } catch (error) {
      setState(() {
        img = ProfilePicture(
          name: "NAME",
          radius: 31,
          fontsize: 21,
          img: "https://t3.ftcdn.net/jpg/03/46/83/96/360_F_346839683_6nAPzbhpSkIpb8pmAwufkC7c5eD7wYws.jpg",
        );
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile Page"),
      ),
      body: Column(
        children: [
          Row(
            children: [
              Container(
                  height: MediaQuery.of(context).size.width * 0.5,
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: img,
              ),
              Column(
                children: [
                  Text(
                      name,
                    style: TextStyle(
                      fontSize: 45,
                    ),
                  ),
                  Text(
                      grade,
                    style: TextStyle(
                      fontSize: 45,
                    ),
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
