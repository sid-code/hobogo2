import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Icon arrow = new Icon(IconData(0xe5c8, fontFamily: 'MaterialIcons'));

class ResultScreen extends StatefulWidget {
  static String token = '';
  ResultScreen({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _ResultScreenState createState() => new _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<FlightItem> _flights = [];
  List<FlightItems> _flights2 = [];
  IOWebSocketChannel ws;
  WebSocket ws2;
  bool firstRun = true;
  bool firstRun2 = true;
  SizedBox _genResult(Flight input) {
    Flight inFlight = input;
    return new SizedBox(
        width: 400.0,
        height: 200.0,
        child: new Card(
            child: new ListView(
                padding: const EdgeInsets.all(4.0),
                itemExtent: 40.0,
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
                    child: new Text(inFlight.From, textAlign: TextAlign.center),
                  ),
                  //AIRPLANE ICON
                  new Icon(IconData(0xe5c8, fontFamily: 'MaterialIcons')),
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
            ])));
  }

  bool expanded = false;
/*
  _buildList(List data) {
    for (int i = 0; i < data.length; i++) {
      Flight f = new Flight(
          int.parse(data[i]['id'].toString()),
          data[i]['loc'],
          data[i]['from'].toString(),
          int.parse(data[i]['departtime'].toString()),
          int.parse(data[i]['arrivetime'].toString()),
          double.parse(data[i]['price'].toString()),
          data[i]['deeplink'].toString(),
          int.parse(data[i]['passengers'].toString()));
      if (i < _flights.length) {
        print('saving expanded val');
        _flights[i].flightCard = _genResult(f);
      } else {
        print('fucking expanded val');
        _flights.add(new FlightItem(flightCard: _genResult(f)));
      }
    }
  }
*/
  _buildList(List data) {
    List<SizedBox> addVal = [];
    for (int i = 0; i < data.length; i++) {
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
    _flights2.add(new FlightItems(flightCards: addVal));
  }

  @override
  Widget build(BuildContext context) {
    if (firstRun) {
      if (!ResultScreen.token.isEmpty) {
        // TODO: Better error handling
        print('token:' + ResultScreen.token);
        WebSocket
            .connect(
                'ws://35.196.30.233:80/subscribe?token=' + ResultScreen.token)
            .then((WebSocket socket) {
          print('ws2 connected');
          print(socket.closeCode);
          print(socket.closeReason);
          ws2 = socket;
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
                print(snapshot.data);
                if (snapshot.data != null && snapshot.data.length > 0) {
                  _buildList(JSON.decode(snapshot.data));
                  int index = 0;
                  return new ExpansionPanelList(
                      expansionCallback: (int index, bool isExpanded) {
                        setState(() {
                          print('setting state');
                          _flights2[index].isExpanded = !isExpanded;
                          print('setstate index:' + index.toString());
                          print(_flights2[index].isExpanded);
                        });
                      },
                      children: _flights2.map((FlightItems item) {
                        return new ExpansionPanel(
                            isExpanded: item.isExpanded,
                            headerBuilder: item.headerBuilder,
                            body: new Column(
                              children: item.flightCards,
                            ));
                      }).toList()

                      /*
                      _flights.map((FlightItem item) {
                        print('index:' + index.toString());
                        print(_flights[index].isExpanded);
                        print(_flights.length);
                        index++;
                        return new ExpansionPanel(
                            isExpanded: item.isExpanded,
                            headerBuilder: item.headerBuilder,
                            body: item.getFlightCard());
                      }).toList()
                      */
                      );
                } else {
                  return new Text('Please wait for results :)');
                }
                /*
                print(snapshot.data);
                if (snapshot.data != null && snapshot.data.length > 0) {
                  dynamic data = JSON.decode(snapshot.data);
                  Flight f = new Flight(
                      int.parse(data[0]['id'].toString()),
                      data[0]['loc'],
                      data[0]['from'].toString(),
                      int.parse(data[0]['departtime'].toString()),
                      int.parse(data[0]['arrivetime'].toString()),
                      double.parse(data[0]['price'].toString()),
                      data[0]['deeplink'].toString(),
                      int.parse(data[0]['passengers'].toString()));
                  return _genResult(f);
                } else {
                  return new Text('nothing here');
                }
                */
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
  FlightItems({this.flightCards});

  List<SizedBox> flightCards = [];
  bool isExpanded = false;

  ExpansionPanelHeaderBuilder get headerBuilder {
    return (BuildContext context, bool isExpanded) {
      return new Text('header');
    };
  }
}

class FlightItem {
  FlightItem({this.flightCard});

  SizedBox flightCard;
  bool isExpanded = false;

  SizedBox getFlightCard() {
    return flightCard;
  }

  ExpansionPanelHeaderBuilder get headerBuilder {
    return (BuildContext context, bool isExpanded) {
      return new Text('header');
    };
  }
}
