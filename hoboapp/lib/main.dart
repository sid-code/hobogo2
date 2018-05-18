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

List<List<dynamic>> _airportList;
Map<String, String> _nameToCode = new Map<String, String>();
List<String> _currentAirportCodes = [];
PostData postData = new PostData();
Fuzzy _fuzz;
String _url = 'http://142.4.213.30:8080/search';
//String _url = 'http://requestbin.fullcontact.com/1401f421';

void main() async {
  _init();
  runApp(new MyApp());
}

void _init() async {
  final csvCodec = new CsvCodec();
  String temp = await rootBundle.loadString('data/airport-codes.csv');
  _airportList = const CsvToListConverter().convert(temp);
  for (int i = 0; i < _airportList.length; i++) {
    _nameToCode[_airportList[i][2]] = _airportList[i][10].toString();
  }
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

class _MyHomePageState extends State<MyHomePage>
    with AutomaticKeepAliveClientMixin<MyHomePage> {
  @override
  bool get wantKeepAlive => true;
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
        int index = _fuzz.bitapSearch(curCode, value, 2);
        if (index == 0) {
          results.add(curName);
          codes.add(curCode);
          //Weight results maybe?
          //print(levenshtein(curName, value, caseSensitive: false));
        }
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
                new MaterialPageRoute(
                    builder: (context) => new ParameterScreen()),
              );
            }));
  }
}

class ParameterScreen extends StatefulWidget {
  ParameterScreen({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _ParameterScreenState createState() => new _ParameterScreenState();
}

class _ParameterScreenState extends State<ParameterScreen> {
  GestureDetector start, end;
  Map<String, String> keys = {
    'Max Stay': 'maxstay',
    'Min Stay': 'minstay',
    'Max Price': 'maxprice',
    'Minimum Length': 'minlength',
    'Number of Passengers': 'passengers'
  };
  TextField _genField(String hint,
      {TextInputType kt = TextInputType.text, List<TextInputFormatter> tif}) {
    return new TextField(
        keyboardType: kt,
        decoration: new InputDecoration(
          hintText: hint,
        ),
        inputFormatters: tif,
        onChanged: (String newVal) {
          if (tif == oneLineNumbers) {
            int val = int.tryParse(newVal);
            switch (hint) {
              case 'Max Stay':
                postData.maxStay = val;
                break;
              case 'Min Stay':
                postData.minStay = val;
                break;
              case 'Max Price':
                postData.maxPrice = val;
                break;
              case 'Minimum Length':
                postData.minLength = val;
                break;
              case 'Number of Passengers':
                postData.passengers = val;
                break;
              default:
                print('default');
            }
          }
        });
  }

  //TODO: Check if end > start, give warning
  GestureDetector _buildClickableDateField(
      String text, BuildContext context, int index) {
    // index == 0 : start
    // index == 1 : end
    return new GestureDetector(
      onTap: () {
        showDatePicker(
                context: context,
                initialDate: new DateTime.now().add(new Duration(days: 1)),
                firstDate: new DateTime.now(),
                lastDate: DateTime.now().add(new Duration(days: 365)))
            .then((DateTime dt) {
          setState(() {
            if (index == 0) {
              postData.startTime = dt.millisecondsSinceEpoch;
              start = _buildClickableDateField(dt.toString(), context, index);
            } else if (index == 1) {
              postData.endTime = dt.millisecondsSinceEpoch;
              end = _buildClickableDateField(dt.toString(), context, index);
            }
          });
        });
      },
      child: new Text(text,
      textAlign: TextAlign.center,
        style: new TextStyle(
          color: Colors.black,
        )
      ),
    );
  }

  void _sendPost() {
    Submit sub = new Submit();
    postData.homeLoc = _currentAirportCodes[0];
    print(_currentAirportCodes);
    postData.destList =
        _currentAirportCodes.getRange(1, _currentAirportCodes.length).toList();

    print(postData.googleCantJSONThingsSoIWillDoIt());
    sub.post(postData.googleCantJSONThingsSoIWillDoIt(), _url).then((Response response) {
      print(response.statusCode);
      print(response.responseBody);
      if (response.statusCode == 200) {
        ResultScreen.token = response.responseBody;
      } else {
        //SHOW ERROR
        ResultScreen.token = 'hi';
      }
    });
    //HttpClientResponse = await sub.post2(googleCantJSONThingsSoIWillDoIt(), _url, '8080', '/search');
  }

  List<TextInputFormatter> oneLineNumbers = [
    WhitelistingTextInputFormatter.digitsOnly,
    BlacklistingTextInputFormatter.singleLineFormatter
  ];

  bool firstRun = false;
  @override
  Widget build(BuildContext context) {
    if (!firstRun) {
      start = _buildClickableDateField('Tap to select start date', context, 0);
      end = _buildClickableDateField('Tap to select end date', context, 1);
      firstRun = !firstRun;
    }
    return new Scaffold(
        appBar: new AppBar(
          title: new Text('Param Screen'),
        ),
        body: new Center(
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              new Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  new Expanded(
                    child: _genField('Max Stay',
                      kt: TextInputType.number, tif: oneLineNumbers),
                  ),
                  new Flexible(
                      child: _genField('Min Stay',
                      kt: TextInputType.number, tif: oneLineNumbers)
                  ),
                  new Flexible(
                    child:_genField('Minimum Length',
                        kt: TextInputType.number, tif: oneLineNumbers),
                  ),
                ],
              ),
              _genField('Max Price',
                  kt: TextInputType.number, tif: oneLineNumbers),
              _genField('Number of Passengers',
                  kt: TextInputType.number, tif: oneLineNumbers),
              new Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  new FlatButton(
                      child: start
                  ),
                  new FlatButton(
                      child: end
                  ),
                ],
              ),
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
        floatingActionButton: new FloatingActionButton(
            child: new Icon(IconData(0xe409,
                fontFamily: 'MaterialIcons', matchTextDirection: true)),
            onPressed: () {
              Navigator.push(
                context,
                new MaterialPageRoute(builder: (context) => new ResultScreen()),
              );
            }));
  }
}
