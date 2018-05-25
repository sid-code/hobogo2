import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'fuzzy.dart';
import 'levenshtein.dart';
import 'submit.dart';
import 'results.dart';
import 'postdata.dart';
import 'home.dart';

void main() {
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Flutter Demo',
      theme: new ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or press Run > Flutter Hot Reload in IntelliJ). Notice that the
        // counter didn't reset back to zero; the application is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: new HomeScreen(title: 'Odysearch'),
    );
  }
}

class MyIntroPage extends StatefulWidget {
  MyIntroPage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  //_MyIntroPageState createState() => new _MyIntroPageState();
  _MyIntroPageStateFake createState() => new _MyIntroPageStateFake();
}

class _MyIntroPageState extends State<MyIntroPage> {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        body: new Center(
      child: new Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        new Padding(
          padding: new EdgeInsets.all(10.0),
          child: new Text(
              'Odysearch can help you explore the world with the cheapest flights possible.',
              textAlign: TextAlign.center,
              style: new TextStyle(fontSize: 18.0,),
              ),
        )
      ]),
    ));
  }
}

class _MyIntroPageStateFake extends State<MyIntroPage> {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(title: new Text('hi')),
      body: new Align(
        child: new FlatButton(
            child: new Text('Click me'),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                new MaterialPageRoute(builder: (context) => new HomeScreen()),
              );
            }),
      ),
    );
  }
}
