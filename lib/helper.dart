import 'package:firebase_auth/firebase_auth.dart';

String getUID(){
  return FirebaseAuth.instance.currentUser!.uid;
}