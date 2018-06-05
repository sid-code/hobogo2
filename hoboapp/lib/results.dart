import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'util.dart';

Icon arrow = new Icon(IconData(0xe5c8, fontFamily: 'MaterialIcons'));

class ResultScreen extends StatefulWidget {
  static String token = '';
  ResultScreen({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _ResultScreenState createState() => new _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<FlightItems> _allFlights = [];
  List<FlightItems> _cheapest20Flights = [];
  IOWebSocketChannel ws;
  WebSocket ws2;
  bool firstRun = true;
  bool firstRun2 = true;
  SizedBox _genResult(Flight input) {
    Flight inFlight = input;
    return new SizedBox(
        width: 400.0,
        height: 84.0,
        child: new GestureDetector(
            onTap: () {},
            child: new Card(
                child: new Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                  new Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      new Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            "\$ " + inFlight.Price.toString(),
                            textAlign: TextAlign.right,
                            style: new TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  new Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      new Align(
                        widthFactor: 1.5,
                        alignment: Alignment.center,
                        child: new Text(
                            new DateFormat.yMd().format(inFlight.DepartTime) +
                                '\n' +
                                new DateFormat.jm().format(inFlight.DepartTime),
                            textAlign: TextAlign.left),
                      ),
                      new Align(
                        widthFactor: 1.5,
                        alignment: Alignment.center,
                        child: new Text(inFlight.From,
                            textAlign: TextAlign.center),
                      ),
                      arrow,
                      new Align(
                        widthFactor: 1.5,
                        alignment: Alignment.center,
                        child: new Text(
                          inFlight.Loc,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      new Align(
                        widthFactor: 1.5,
                        alignment: Alignment.center,
                        child: new Text(
                            new DateFormat.yMd().format(inFlight.ArriveTime) +
                                '\n' +
                                new DateFormat.jm().format(inFlight.ArriveTime),
                            textAlign: TextAlign.right),
                      ),
                      new Icon(
                        IconData(0xe192, fontFamily: 'MaterialIcons'),
                      ),
                      new Align(
                          alignment: Alignment.centerRight,
                          child: new Text(
                            inFlight.TravelTime.inHours.toString() +
                                'h ' +
                                (inFlight.TravelTime.inMinutes -
                                        60 * inFlight.TravelTime.inHours)
                                    .toString() +
                                'm',
                            textAlign: TextAlign.left,
                          ))
                    ],
                  ),
                ]))));
  }

  _buildList(List data) {
    if (data == null) {
      return;
    }
    double totalPrice = 0.0;
    DateTime tripStart = DateTime.fromMillisecondsSinceEpoch(
        int.parse(data[0]['departtime']),
        isUtc: true);
    DateTime tripEnd = DateTime.fromMillisecondsSinceEpoch(
        int.parse(data[data.length - 1]['arrivetime']),
        isUtc: true);
    List<String> codes = [];
    List<SizedBox> addVal = [];
    for (int i = 0; i < data.length; i++) {
      totalPrice += double.parse(data[i]['price'].toString());
      if (i == 0) {
        codes.add(data[i]['from']);
        codes.add(data[i]['loc']);
      } else {
        codes.add(data[i]['loc']);
      }
      Flight f = new Flight(
          int.parse(data[i]['id'].toString()),
          data[i]['loc'],
          data[i]['from'].toString(),
          int.parse(data[i]['departtime'].toString()),
          int.parse(data[i]['arrivetime'].toString()),
          double.parse(data[i]['price'].toString()),
          data[i]['deeplink'].toString(),
          int.parse(data[i]['passengers'].toString()));
      addVal.add(_genResult(f));
    }
    _allFlights.add(new FlightItems(
        flightCards: addVal,
        price: totalPrice,
        tripStart: tripStart,
        tripEnd: tripEnd,
        codes: codes));
    _allFlights.sort((a, b) => a.price.compareTo(b.price));
    _cheapest20Flights = [];
    for (int i = 0; i <= 20 && i < _allFlights.length; i++) {
      _cheapest20Flights.add(_allFlights[i]);
    }
  }

  Future sleep() {
    return new Future.delayed(const Duration(seconds: 5), () => "5");
  }

  @override
  Widget build(BuildContext context) {
    if (firstRun) {
      if (!ResultScreen.token.isEmpty) {
        // TODO: Better error handling
        WebSocket
            .connect(Util.wsUrl + '/subscribe?token=' + ResultScreen.token)
            .then((WebSocket socket) {
          ws2 = socket;
          sleep().then((_) {
            setState(() {});
          });
        }).catchError((error) {
          print(error.message);
          print(error.runtimeType);
        });
      }
      firstRun = !firstRun;
    }
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Results'),
      ),
      body: new Center(
        child: new Align(
          alignment: Alignment.topCenter,
          child: new SingleChildScrollView(
            child: new StreamBuilder(
              stream: ws2,
              builder: (context, snapshot) {
                if (snapshot.data != null && snapshot.data.length > 0) {
                  _buildList(JSON.decode(snapshot.data));
                  int index = 0;
                  return new ExpansionPanelList(
                      expansionCallback: (int index, bool isExpanded) {
                        setState(() {
                          _cheapest20Flights[index].isExpanded = !isExpanded;
                        });
                      },
                      children: _cheapest20Flights.map((FlightItems item) {
                        return new ExpansionPanel(
                            isExpanded: item.isExpanded,
                            headerBuilder: item.headerBuilder,
                            body: new Column(
                              children: item.flightCards,
                            ));
                      }).toList());
                } else {
                  return new Text(
                      'We are searching flights for you :)\nPlease give us a few minutes');
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class Flight {
  int ID;
  String Loc;
  String From;
  DateTime DepartTime;
  DateTime ArriveTime;
  double Price;
  String DeepLink;
  int Passengers;
  Duration TravelTime;

  Flight(int id, String loc, String from, int departtime, int arrivetime,
      double price, String deeplink, int passengers) {
    this.ID = ID;
    this.Loc = loc;
    this.From = from;
    this.DepartTime =
        new DateTime.fromMillisecondsSinceEpoch(departtime, isUtc: true);
    this.ArriveTime =
        new DateTime.fromMillisecondsSinceEpoch(arrivetime, isUtc: true);
    this.Price = price;
    this.DeepLink = deeplink;
    this.Passengers = passengers;
    this.TravelTime = this.ArriveTime.difference(this.DepartTime);
  }
}

class FlightItems {
  FlightItems(
      {this.flightCards, this.price, this.tripStart, this.tripEnd, this.codes});

  List<SizedBox> flightCards = [];
  double price;
  DateTime tripStart;
  DateTime tripEnd;
  List<String> codes;
  bool isExpanded = false;

  ExpansionPanelHeaderBuilder get headerBuilder {
    return (BuildContext context, bool isExpanded) {
      List<Widget> vals = [];
      List<Widget> vals2 = [];
      List<Widget> vals3 = [];
      vals.add(new Text(new DateFormat.yMd().format(tripStart).toString()));
      vals.add(new Text(new DateFormat.jm().format(tripStart).toString()));
      for (int i = 0; i < codes.length; i++) {
        vals2.add(new Text(codes[i]));
        if (i < codes.length - 1) {
          vals2.add(arrow);
        }
      }
      vals3.add(new Text(new DateFormat.yMd().format(tripEnd).toString()));
      vals3.add(new Text(new DateFormat.jm().format(tripEnd).toString()));
      return new Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            new Column(children: vals),
            new Row(children: vals2),
            new Column(children: vals3),
            new Text('\$' + price.toString()),
          ]);
    };
  }
}
