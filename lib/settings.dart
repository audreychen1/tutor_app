import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'helper.dart';
import 'login.dart';

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  Future<void> uploadProfilePic() async {
    final storageRef = FirebaseStorage.instance.ref();
    final profileRef = storageRef.child("profilePics/" + getUID() + ".png");
    final ImagePicker picker = ImagePicker();
    XFile? xFile = await picker.pickImage(
        source: ImageSource.gallery
    );
    File file = File(xFile!.path);
    try {
      await profileRef.putFile(file);
      //await mountainsRef.getDownloadURL();
      await FirebaseDatabase.instance.ref().child("User").child(getUID()).update({
        "profilepic":await profileRef.getDownloadURL(),
      }).then((value) {
        print("uploaded profile pic");
      }).catchError((onError) {
        print("could not upload profile pic");
      });
    } catch (e) {
      print("couldn't upload pciutre" + e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
      ),
      body: Column(
        children: [
          ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut().then((value) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Login(),
                    ),
                  );
                });
              },
              child: Text("Logout"),
          ),
          ElevatedButton(
            onPressed: () async {
              await uploadProfilePic();
            },
              child: Text("Upload Profile Picture"),
          ),
        ],
      ),
    );
  }
}
