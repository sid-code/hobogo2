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
String _url = 'http://35.196.30.233:80/search';
//String _url = 'http://requestbin.fullcontact.com/1401f421';

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
              print(dt);
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
          )),
    );
  }

  void _sendPost(BuildContext context) {
    Submit sub = new Submit();
    /*
    postData.homeLoc = _currentAirportCodes[0];
    print(_currentAirportCodes);
    postData.destList =
        _currentAirportCodes.getRange(1, _currentAirportCodes.length).toList();

    print(postData.googleCantJSONThingsSoIWillDoIt());
    */
    //sub.post(postData.googleCantJSONThingsSoIWillDoIt(), _url).then((Response response) {
    sub
        .post(
            r'{"homeloc":"LAX","destlist":["PRG","BUD","LGW","FCO","DUB"],"starttime":1527145200000,"endtime":1528959600000,"maxstay":6,"minstay":2,"maxprice":1000,"minlength":3,"passengers":1}',
            _url)
        .then((Response response) {
      print(response.statusCode);
      print(response.responseBody);
      if (response.statusCode == 200) {
        Map responseList = JSON.decode(response.responseBody);
        ResultScreen.token = responseList['token'];
        Navigator.push(
          context,
          new MaterialPageRoute(builder: (context) => new ResultScreen()),
        );
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

  List<DropdownMenuItem<String>> dropItemList(int min, int max) {
    List<DropdownMenuItem<String>> dropList = [];
    if (max < 10) {
      for (int i = min; i <= max; i++) {
        DropdownMenuItem item = new DropdownMenuItem<String>(
          child: new Text(i.toString()),
          value: i.toString(),
        );
        dropList.add(item);
      }
    } else if (max >= 10 && max < 100) {
      for (int i = min; i < 10; i++) {
        DropdownMenuItem item = new DropdownMenuItem<String>(
          child: new Text(i.toString() + ' '),
          value: i.toString(),
        );
        dropList.add(item);
      }

      for (int i = 10; i <= max; i++) {
        DropdownMenuItem item = new DropdownMenuItem<String>(
          child: new Text(i.toString()),
          value: i.toString(),
        );
        dropList.add(item);
      }
    } else {
      print('someome had more than 100 destinations...');
    }
    return dropList;
  }

  String minStayVal = '1';
  String maxStayVal = '1';
  String minLengthVal = '1';
  String passVal = '1';

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
        body: new Align(
          alignment: Alignment.topCenter,
          child:
          SizedBox(
            width: 400.0,
            child:
            new Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,

              children: <Widget>[
                new Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    new SizedBox(
                      width: 130.0,
                      child:
                      new Container(
                        margin: const EdgeInsets.fromLTRB(5.0,50.0,5.0,50.0),
                        padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                        decoration: new BoxDecoration(
                          border: new Border.all(color: Colors.black),
                        ),
                        child: new Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: <Widget>[
                            new Expanded(
                              child: new Text('Max Stay:', textAlign: TextAlign.left),
                            ),
                            new Flexible(
                              child: new DropdownButton<String>(
                                  value: maxStayVal,
                                  items: dropItemList(1, 9),
                                  onChanged: (String newVal) {
                                    setState(() {
                                      maxStayVal = newVal;
                                      postData.maxStay = int.parse(newVal);
                                    });
                                  }),
                            ),
                          ],
                        ),
                      ),
                    ),
                    new SizedBox(
                      width: 130.0,
                      child:
                      new Container(
                        margin: const EdgeInsets.fromLTRB(5.0,50.0,5.0,50.0),
                        padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                        decoration: new BoxDecoration(
                          border: new Border.all(color: Colors.black),
                        ),
                        child: new Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: <Widget>[
                            new Expanded(
                              child: new Text('Min Stay:', textAlign: TextAlign.left),
                            ),
                            new Flexible(
                              child: new DropdownButton<String>(
                                  value: minStayVal,
                                  items: dropItemList(1, 9),
                                  onChanged: (String newVal) {
                                    setState(() {
                                      minStayVal = newVal;
                                      postData.minStay = int.parse(newVal);
                                    });
                                  }),
                            ),
                          ],
                        ),
                      ),
                    ),
                    new SizedBox(
                      width: 130.0,
                      child:
                      new Container(
                        margin: const EdgeInsets.fromLTRB(5.0,50.0,5.0,50.0),
                        padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                        decoration: new BoxDecoration(
                          border: new Border.all(color: Colors.black),
                        ),
                        child: new Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: <Widget>[
                            new Expanded(
                              child: new Text('Min length:', textAlign: TextAlign.left),
                            ),
                            new Flexible(
                              child: new DropdownButton<String>(
                                  value: minLengthVal,
                                  hint: Text('1'),
                                  items: dropItemList(1, 9),
                                  onChanged: (String newVal) {
                                    setState(() {
                                      minLengthVal = newVal;
                                      postData.minLength = int.parse(newVal);
                                    });
                                  }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                new Row(
                  children: <Widget>[
                    new SizedBox(
                      width: 200.0,
                      height: 150.0,
                      child:
                        new Container(
                          margin: const EdgeInsets.fromLTRB(5.0,50.0,5.0,50.0),
                          padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                          decoration: new BoxDecoration(
                            border: new Border.all(color: Colors.black),
                          ),
                          child:
                          _genField('Max Price',
                              kt: TextInputType.number, tif: oneLineNumbers),
                        ),
                    ),
                    new SizedBox(
                      width: 200.0,
                      child:
                      new Container(
                        margin: const EdgeInsets.fromLTRB(5.0,50.0,5.0,50.0),
                        padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                        decoration: new BoxDecoration(
                          border: new Border.all(color: Colors.black),
                        ),
                        child:
                        new Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            new Expanded(
                              child: new Text('Passengers:', textAlign: TextAlign.left),
                            ),
                            new Flexible(
                              child:
                              new DropdownButton<String>(
                                  value: passVal,
                                  items: dropItemList(1, 9),
                                  onChanged: (String newVal) {
                                    setState(() {
                                      passVal = newVal;
                                      postData.passengers = int.parse(newVal);
                                    });
                                  }),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                new Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                  new SizedBox(
                    width: 175.0,
                    child:
                    new FlatButton(child: start),
                  ),
                    new SizedBox(
                      width: 175.0,
                      child:
                      new FlatButton(child: end),
                    )
                  ],
                ),
                new Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    new SizedBox(
                      width: 100.0,
                      child:
                      new FlatButton(
                          child: new Text('Back'),
                          onPressed: () {
                            Navigator.pop(
                              context,
                              true,
                            );
                          }),
                    ),
                    new SizedBox(
                      width: 100.0,
                      child:
                      new FlatButton(
                          child: new Text('Submit'),
                          onPressed: () {
                            _sendPost(context);
                            print('Submit');
                          }),
                    )
                  ],
                )
              ],
            ),
        ),
        ),
        /*new Center(
          child: new Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[

              new Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  new Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[


                      new Flexible(
                        child:
                            new Text('Min Length:', textAlign: TextAlign.left),
                      ),
                    ],
                  ),
                  new Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[

                      new Flexible(
                        child: new DropdownButton<String>(
                            value: testVal2,
                            items: dropItemList(1, 9),
                            onChanged: (String newVal) {
                              setState(() {
                                testVal2 = newVal;
                              });
                            }),
                      ),
                      new Flexible(
                        child: new DropdownButton<String>(
                            value: testVal3,
                            items: dropItemList(1, 9),
                            onChanged: (String newVal) {
                              setState(() {
                                testVal3 = newVal;
                              });
                            }),
                      ),
                    ],
                  ),
                ],
              ),
              _genField('Number of Passengers',
                  kt: TextInputType.number, tif: oneLineNumbers),

              ),
              new Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[


                ],
              ),
              new Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[


                ],
              ),
            ],
          ),
        ),*/
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
