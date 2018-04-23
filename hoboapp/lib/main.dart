import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'fuzzy.dart';
import 'levenshtein.dart';

List<List<dynamic>> _airportList;
Fuzzy _fuzz;

void main() async {
  _init();
  runApp(new MyApp());
}

void _init() async {
  final csvCodec = new CsvCodec();
  String temp = await rootBundle.loadString('data/airport-codes.csv');
  _airportList = const CsvToListConverter().convert(temp);
  _fuzz = new Fuzzy();
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
      home: new MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Widget> _resultList = [];
  int _counter = 0;

  void _search(String value) {
    List<dynamic> _results = [];
    if (value.length > 2) {
      for (int i = 0; i < _airportList.length; i++) {
        //For now just search name
        String curName = _airportList[i][2];
        //String curCode = _airportList[i][10];
        int index = _fuzz.bitapSearch(curName, value, 2);
        if (index == 0) {
          _results.add(curName);
          //Weight results maybe?
          //print(levenshtein(curName, value, caseSensitive: false));
        }
      }
      //Redraw UI with updated list
      setState(() {
        _resultList = _buildList(_results);
      });
    }
  }

  List<Widget> _buildList(List<dynamic> list) {
    //Build our widgets to display results
    //ListTile to display more info later
    List<Widget> retVal = [];
    retVal.add(new Text(''));
    for (int i = 0; i < list.length; i++) {
      Text text = new Text(list[i]);
      retVal.add(text);
    }
    return retVal;
  }

  @override
  Widget build(BuildContext context) {
    _resultList.add(new Text(''));
    return new Scaffold(
      appBar: new AppBar(
        actions: <Widget>[
          new IconButton(
            icon: new Icon(Icons.lightbulb_outline),
          ),
          new IconButton(
            icon: new Icon(Icons.search),
          ),
          new IconButton(
            icon: new Icon(Icons.card_travel),
          ),
        ],
      ),
      body: new Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: new Column(
          // Column is also layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug paint" (press "p" in the console where you ran
          // "flutter run", or select "Toggle Debug Paint" from the Flutter tool
          // window in IntelliJ) to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new TextField(
              decoration: new InputDecoration(
                hintText: 'Home City',
              ),
              onChanged: _search,
            ),
            new Flexible(
              child: new ListView(
                padding: const EdgeInsets.all(20.0),
                children: _resultList,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
