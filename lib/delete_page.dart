import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutor_app/login.dart';

class DeleteAccount extends StatefulWidget {
  const DeleteAccount({Key? key}) : super(key: key);

  @override
  State<DeleteAccount> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends State<DeleteAccount> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            "Delete Account",
          style: GoogleFonts.notoSans(
            fontSize: 26,
          ),
        ),
        backgroundColor: Color.fromRGBO(82, 121, 111, 1),
      ),
      body: Center(
        child: Column(
          children: [
            Text(
                "Delete Account?",
              style: GoogleFonts.notoSans(
                fontSize: 30,
              ),
            ),
            ElevatedButton(
                onPressed: () {
                  FirebaseAuth.instance.currentUser?.delete().then((value) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => Login(),
                      ),
                    );
                  }).catchError((error) {
                    print("could not delete account " + error.toString());
                  });
                },
                child: Text("Delete")),
          ],
        ),
      ),
    );
  }
}
