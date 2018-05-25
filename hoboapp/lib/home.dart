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
import 'paramscreen.dart';

List<List<dynamic>> _airportList;
Map<String, String> _nameToCode = new Map<String, String>();
List<String> _currentAirportCodes = [];
Fuzzy _fuzz;

void _init() async {
  final csvCodec = new CsvCodec();
  String temp = await rootBundle.loadString('data/airport-codes.csv');
  _airportList = const CsvToListConverter().convert(temp);
  for (int i = 0; i < _airportList.length; i++) {
    _nameToCode[_airportList[i][2]] = _airportList[i][10].toString();
  }
  _fuzz = new Fuzzy();
}

class HomeScreen extends StatefulWidget {
  HomeScreen({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _HomeScreenState createState() => new _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin<HomeScreen> {
  @override
  bool get wantKeepAlive => true;
  bool firstRun = true;
  // List of all strings matching search
  List<String> _resultList = [];
  // List of all airport codes matching search
  List<String> _codeList = [];
  // List of text to be put into TextFields
  List<String> _selectedList = [];
  int _curInputIndex = 0;
  int _textFieldCount = 1;

  void _search(String value, int index) {
    List<String> results = [];
    List<String> codes = [];
    if (value.length > 2) {
      for (int i = 0; i < _airportList.length; i++) {
        //For now just search name
        String curName = _airportList[i][2];
        String curCode = _airportList[i][10].toString();
        _fuzz.bitapSearch(curCode, value, 2).then((index) {
          if (index == 0) {
            results.add(curName);
            codes.add(curCode);
            //Weight results maybe?
            //print(levenshtein(curName, value, caseSensitive: false));
          }
        });
      }
      setState(() {
        _resultList = results;
        _codeList = codes;
        _curInputIndex = index;
      });
    }
  }

  TextField _buildTextField(int index) {
    // Hint Text
    String contents = '';
    // Active Text
    String data = '';
    // If we user has selected something
    if (index >= _selectedList.length) {
      _selectedList.length = index + 1;
    }
    data = _selectedList[index];
    if (index == 0) {
      contents = 'Home City';
    } else {
      contents = 'Destination City ' + index.toString();
    }
    TextEditingController cont = new TextEditingController(text: data);
    if (data != null) {
      cont.selection =
          new TextSelection(baseOffset: data.length, extentOffset: data.length);
    }
    TextField field = new TextField(
      decoration: new InputDecoration(
        hintText: contents,
      ),
      controller: cont,
      onChanged: (String str) {
        _search(str, index);
        _selectedList[index] = str;
        print(_selectedList[index]);
      },
    );
    KeepAlive retVal = new KeepAlive(child: field, keepAlive: true);
    return field;
  }

  FlatButton _buildResultButtons(int index) {
    //index = index - _textFieldCount;
    FlatButton retVal = new FlatButton(
        child: new Text(_resultList[index]),
        onPressed: () {
          _selectedList.length = _textFieldCount;
          setState(() {
            _selectedList[_curInputIndex] = _resultList[index];
            _resultList = [];
            _textFieldCount++;
          });
        });

    return retVal;
  }

  @override
  Widget build(BuildContext context) {
    if (firstRun) {
      _init();
      firstRun = !firstRun;
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
        body: new Column(children: <Widget>[
          new Flexible(
            child: new ListView.builder(
                itemCount: _textFieldCount,
                itemBuilder: (BuildContext context, int index) {
                  return _buildTextField(index);
                }),
          ),
          new Expanded(
              child: new ListView.builder(
            itemCount: _resultList.length,
            itemBuilder: (BuildContext context, int index) {
              return _buildResultButtons(index);
            },
          )),
        ]),
        floatingActionButton: new FloatingActionButton(
            child: new Icon(IconData(0xe409,
                fontFamily: 'MaterialIcons', matchTextDirection: true)),
            onPressed: () {
              _currentAirportCodes = [];
              for (int i = 0; i < _selectedList.length; i++) {
                _currentAirportCodes.add(_nameToCode[_selectedList[i]]);
                if (_currentAirportCodes[i] == null) {
                  _currentAirportCodes.removeAt(i);
                }
              }
              print(_currentAirportCodes);
              Navigator.push(
                context,
                new MaterialPageRoute(builder: ((context) {
                  ParameterScreen.currentAirportCodes = _currentAirportCodes;
                  return new ParameterScreen();
                })),
              );
            }));
  }
}
