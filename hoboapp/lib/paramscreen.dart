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
import 'util.dart';
import 'package:intl/intl.dart';

class ParameterScreen extends StatefulWidget {
  ParameterScreen({Key key, this.title}) : super(key: key);
  final String title;
  static List<String> currentAirportCodes;

  @override
  _ParameterScreenState createState() => new _ParameterScreenState();
}

//global sendPost variables
int maxStayVal;
int minStayVal;
int minLengthVal;
int passVal;
int priceVal;

class _ParameterScreenState extends State<ParameterScreen> {
  PostData postData = new PostData();
  List<String> _currentAirportCodes = ParameterScreen.currentAirportCodes;
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
              start = _buildClickableDateField(
                  new DateFormat.yMMMMd().format(dt).toString(), context, index);
            } else if (index == 1) {
              postData.endTime = dt.millisecondsSinceEpoch;
              end = _buildClickableDateField(
                  new DateFormat.yMMMMd().format(dt).toString(), context, index);
            }
          });
        });
      },
      child: new Text(text,
          textAlign: TextAlign.center,
          style: new TextStyle(
            color: Colors.lightBlueAccent,
          )),
    );
  }

  void _sendPost(BuildContext context) {
    Submit sub = new Submit();
    postData.homeLoc = _currentAirportCodes[0];
    print(_currentAirportCodes);
    postData.destList =
        _currentAirportCodes.getRange(1, _currentAirportCodes.length).toList();

    print(postData.googleCantJSONThingsSoIWillDoIt());
    sub.post(postData.googleCantJSONThingsSoIWillDoIt(), Util.httpUrl + '/search').then((Response response) {
      /*
    sub
        .post(
            r'{"homeloc":"LAX","destlist":["PRG","BUD","LGW","FCO","DUB"],"starttime":1527145200000,"endtime":1528959600000,"maxstay":6,"minstay":2,"maxprice":1000,"minlength":3,"passengers":1}',
            Util.httpUrl + '/search')
        .then((Response response) {
        */
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


  //NumRocker takes postData parameter as input to set on change
  NumRocker maxRock = new NumRocker(iD: 1, dispVal: 5);
  NumRocker minRock = new NumRocker(iD: 2, dispVal: 2);
  NumRocker citRock = new NumRocker(
      iD: 3, minVal: 1, dispVal: 3, iconSize: 20.0, fontSize: 25.0);
  NumRocker passRock = new NumRocker(
      iD: 4, minVal: 1, iconSize: 20.0, fontSize: 25.0, colMinim: Colors.grey);

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
        child: SizedBox(
          width: 400.0,
          child: new Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                new Padding(
                  padding: new EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 5.0),
                  child: new Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    new Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        new Text(
                          "Max",
                          textAlign: TextAlign.right,
                          style: new TextStyle(
                            fontSize: 30.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        new Text(
                          "time in a City",
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                    new Column(
                      children: <Widget>[
                        maxRock,
                      ],
                    ),
                  ],
                  ),
                ),
                new Padding(
                  padding: new EdgeInsets.fromLTRB(20.0, 5.0, 20.0, 5.0),
                  child: new Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    new Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        new Text(
                          "Min",
                          textAlign: TextAlign.right,
                          style: new TextStyle(
                            fontSize: 30.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        new Text(
                          "time in a City",
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                    new Column(
                      children: <Widget>[
                        minRock,
                      ],
                    ),
                  ],
                ),
                ),
                new Padding(
                  padding: new EdgeInsets.fromLTRB(20.0, 5.0, 20.0, 0.0),
                  child: new Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      new Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          new Text(
                            "Minimum",
                            textAlign: TextAlign.right,
                            style: new TextStyle(
                              fontSize: 18.0,
                            ),
                          ),
                          new Text(
                            "num of Cities",
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                      new Column(
                        children: <Widget>[
                          citRock,
                        ],
                      ),
                    ],
                  ),
                ),
                new Padding(
                  padding: new EdgeInsets.fromLTRB(20.0, 5.0, 20.0, 10.0),
                  child: new Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      new Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          new Text(
                            "Number",
                            textAlign: TextAlign.right,
                            style: new TextStyle(
                              fontSize: 18.0,
                              ),
                          ),
                          new Text(
                            "of passengers",
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                      new Column(
                        children: <Widget>[
                          passRock,
                        ],
                      ),
                    ],
                  ),
                ),
                new Padding(
                  padding: new EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
                  child: new Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      new Text(
                        "Max Price",
                        style: new TextStyle(
                          fontSize: 30.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      new Row(
                        children: <Widget>[
                          new Text(
                            "\$",
                            style: TextStyle(
                              fontSize: 30.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          new SizedBox(
                            width: 150.0,
                            child: new Container(
                              decoration: new BoxDecoration(
                                border: new Border.all(
                                  color: Colors.black,
                                  width: 1.0,
                                ),
                                shape: BoxShape.rectangle,
                                //borderRadius: new Radius.circular(10.0),
                              ),
                              child: new TextFormField(
                                decoration: new InputDecoration(
                                ),
                                onFieldSubmitted: (String newVal) {
                                  priceVal = int.parse(newVal);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                new Padding(
                  padding: new EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
                  child:
                    new Text(
                      "Rough Travel Dates",
                      textAlign: TextAlign.center,
                      style: new TextStyle(
                        fontSize: 35.0,
                        fontWeight: FontWeight.bold,
                      )
                    )
                ),
                new Padding(
                  padding: new EdgeInsets.fromLTRB(20.0, 5.0, 20.0, 10.0),
                  child: new Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      new Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          new Padding(
                            padding: EdgeInsets.fromLTRB(15.0, 0.0, 0.0, 0.0),
                            child: new Text("Start",
                              textAlign: TextAlign.left,
                              style: new TextStyle(
                                fontSize: 35.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          new FlatButton(child: start),
                        ],
                      ),
                      new Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          new Padding(
                            padding: EdgeInsets.fromLTRB(0.0, 0.0, 15.0, 0.0),
                            child: new Text("End",
                              textAlign: TextAlign.right,
                              style: new TextStyle(
                                fontSize: 35.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          new FlatButton(child: end),
                        ],
                      ),
                    ],
                  ),
                ),
                new Padding(
                  padding: const EdgeInsets.fromLTRB(1.0, 15.0, 1.0, 0.0),
                  child: new FlatButton(
                    onPressed:  () {
                      postData.maxStay = maxStayVal;
                      postData.minStay = minStayVal;
                      postData.minLength = minLengthVal;
                      postData.passengers = passVal;
                      postData.maxPrice = priceVal;

                      print(postData.maxStay);
                      print(postData.minStay);
                      print(postData.minLength);
                      print(postData.passengers);
                      print(postData.maxPrice);
                      print(postData.startTime);
                      print(postData.endTime);

                      Navigator.push(
                        context,
                        new MaterialPageRoute(builder: (context) => new ResultScreen()),
                      );
                    },
                    color: Colors.lightBlue,
                    child: new Text("Search",
                      style: new TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class NumRocker extends StatefulWidget {

  //iD values: maxStay = 1, minStay = 2, minCities = 3, numPassengers = 4
  int iD;
  int minVal;
  int dispVal;
  int maxVal;
  double iconSize;
  double fontSize;
  Color colMinim;
  Color colMaxim;

  NumRocker({
    this.iD = 0,
    this.minVal = 0,
    this.dispVal = 1,
    this.maxVal = 99,
    this.iconSize = 35.0,
    this.fontSize = 45.0,
    this.colMinim = Colors.lightBlueAccent,
    this.colMaxim = Colors.lightBlueAccent,
  });


  @override
  _NumRockerState createState() => new _NumRockerState(
      id: iD,
      min: minVal,
      val: dispVal,
      max: maxVal,
      iconS: iconSize,
      fontS: fontSize,
      colMin: colMinim,
      colMax: colMaxim,
  );
}

class _NumRockerState extends State<NumRocker> {
  _NumRockerState({
    this.id, this.min, this.val, this.max, this.iconS, this.fontS,
    this.colMin, this.colMax
  });
  int id;
  int min;
  int val;
  int max;
  double iconS;
  double fontS;
  Color colMin;
  Color colMax;

  void dec() {
    setState(() {
      if(val > min) {
        val--;
        if (val == min) {
          colMin = Colors.grey;
        }
        if (val == max-1) {
          colMax = Colors.lightBlueAccent;
        }
      }

      //id check
      if(id == 0) {
          print('id = 0, ID NOT SET PROPERLY');
      } else if (id == 1) {
        //id = maxStay
        maxStayVal = val;
      } else if (id == 2){
        //id = minStay
        minStayVal = val;
      } else if (id == 3){
        //id = minCities
        minLengthVal = val;
      } else if (id == 4){
        //id = numPassengers
        passVal = val;
      } else {
        print('id not 0-4, UNDEFINED');
      }

    });
  }

  void inc() {
    setState(() {
      if(val < max) {
        val++;
        if (val == min + 1) {
          colMin = Colors.lightBlueAccent;
        }
        if (val == max) {
          colMax = Colors.grey;
        }
      }

      //id check
      if(id == 0) {
        print('id = 0, ID NOT SET PROPERLY');
      } else if (id == 1) {
        //id = maxStay
        maxStayVal = val;
      } else if (id == 2){
        //id = minStay
        minStayVal = val;
      } else if (id == 3){
        //id = minCities
        minLengthVal = val;
      } else if (id == 4){
        //id = numPassengers
        passVal = val;
      } else {
        print('id not 0-4, UNDEFINED');
      }
    });
  }

  @override
  Widget build(BuildContext context){
    return new Row(
      children: <Widget>[
        new IconButton(
          icon: new Icon(
            Icons.remove,
            color: colMin,
            size: iconS,
          ),
          onPressed: (){
            dec();
          },
        ),
        new Padding(
          padding: new EdgeInsets.fromLTRB(5.0, 0.0, 5.0, 0.0),
          child: new Text(
            val.toString(),
            style: new TextStyle(
              fontSize: fontS,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        new IconButton(
          icon: new Icon(
            Icons.add,
            color: colMax,
            size: iconS,
          ),
          onPressed: (){
            inc();
          },
        ),
      ],
    );
  }
}
