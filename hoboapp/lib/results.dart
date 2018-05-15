import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';

class ResultScreen extends StatefulWidget {
  static String token;
  ResultScreen({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _ResultScreenState createState() => new _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Results'),
      ),
      body: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new Text(ResultScreen.token),
          ],
        ),
      ),
    );
  }
}
