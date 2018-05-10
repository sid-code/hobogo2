import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'fuzzy.dart';
import 'levenshtein.dart';
import 'submit.dart';

List<List<dynamic>> _airportList;
Fuzzy _fuzz;
String _url = 'http://requestbin.fullcontact.com/1bnkxwj1';

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
  List<Widget> _inputList = [];
  int _curInputIndex = 0;

  void _search(String value, int index) {
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
      //Redraw UI with updated elements
      setState(() {
        _resultList = _buildList(_results);
        _curInputIndex = index;
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
      FlatButton but = new FlatButton(
        child: text,
        onPressed: () {
          print(text.data);
          print(_curInputIndex);
          setState(() {
            _inputList[_curInputIndex] =
                _buildTextField(_curInputIndex, data: text.data);
            print(_inputList[_curInputIndex].toString());
          });
        },
      );
      retVal.add(but);
    }
    return retVal;
  }

  TextField _buildTextField(int index, {String data: ''}) {
    String contents = '';
    if (index == 0) {
      contents = 'Home City';
    } else {
      contents = 'Destination City ' + index.toString();
    }
    TextEditingController cont = new TextEditingController(text: data);
    TextField _homeCity = new TextField(
      decoration: new InputDecoration(
        hintText: contents,
      ),
      controller: cont,
      onChanged: (String str) => _search(str, index),
      onSubmitted: (String str) {
        setState(() {
          _curInputIndex++;
          _inputList.add(_buildTextField(_curInputIndex));
          _resultList = [];
        });
      },
    );
    return _homeCity;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> _buttons = [];
    FlatButton nextPage = new FlatButton(
        child: new Text('Next'),
        onPressed: () {
          Navigator.push(
            context,
            new MaterialPageRoute(builder: (context) => new _ParameterScreen()),
          );
        });
    _buttons.add(nextPage);
    // Initialization of elements
    if (_resultList.length == 0) {
      _resultList.add(new Text(''));
    }
    if (_inputList.length == 0) {
      _inputList.add(_buildTextField(0));
    }
    // Top 'appBar' bar
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
      // Main Body
      body: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new Flexible(
              child: new ListView(
                children: _inputList + _resultList + _buttons,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParameterScreen extends StatelessWidget {
  GestureDetector start, end;
  Map<String, String> keys = {
    'Max Stay': 'maxstay',
    'Min Stay': 'minstay',
    'Max Price': 'maxprice',
    'Minimum Length': 'minlength',
    'Number of Passengers': 'passengers'
  };
  Map<String, String> postData = new Map<String, String>();
  TextField _genField(String hint,
      {TextInputType kt = TextInputType.text, List<TextInputFormatter> tif}) {
    return new TextField(
        keyboardType: kt,
        decoration: new InputDecoration(
          hintText: hint,
        ),
        inputFormatters: tif,
        onChanged: (String newVal) {
          postData[keys[hint]] = newVal;
        });
  }

  GestureDetector _buildClickableDateField(String text, BuildContext context) {
    return new GestureDetector(
      onTap: () {
        DateTime time;
        showDatePicker(
            context: context,
            initialDate: new DateTime.now().add(new Duration(days: 1)),
            firstDate: new DateTime.now(),
            lastDate: DateTime.now().add(new Duration(days: 365))).then((dt) {
          time = dt;
          //setState(() {print('hi');});
        });
      },
      child: new Text(text),
    );
  }

  void _sendPost() {
    Submit sub = new Submit();
    print(postData);
    sub.post(JSON.encode(postData), _url);
  }

  List<TextInputFormatter> oneLineNumbers = [
    WhitelistingTextInputFormatter.digitsOnly,
    BlacklistingTextInputFormatter.singleLineFormatter
  ];

  @override
  Widget build(BuildContext context) {
    start =_buildClickableDateField('Tap to select start date', context);
    end =_buildClickableDateField('Tap to select end date', context);
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Param Screen'),
      ),
      body: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            _genField('Max Stay',
                kt: TextInputType.number, tif: oneLineNumbers),
            _genField('Min Stay',
                kt: TextInputType.number, tif: oneLineNumbers),
            _genField('Max Price',
                kt: TextInputType.number, tif: oneLineNumbers),
            _genField('Minimum Length',
                kt: TextInputType.number, tif: oneLineNumbers),
            _genField('Number of Passengers',
                kt: TextInputType.number, tif: oneLineNumbers),
            start,
            end,
            new FlatButton(
                child: new Text('datepl'),
                onPressed: () {
                  showDatePicker(
                      context: context,
                      initialDate:
                          new DateTime.now().add(new Duration(days: 1)),
                      firstDate: new DateTime.now(),
                      lastDate: DateTime.now().add(new Duration(days: 365)));
                }),
            new FlatButton(
                child: new Text('Back'),
                onPressed: () {
                  Navigator.pop(
                    context,
                    true,
                  );
                }),
            new FlatButton(
                child: new Text('Submit'),
                onPressed: () {
                  _sendPost();
                  print('Submit');
                }),
          ],
        ),
      ),
    );
  }
}
