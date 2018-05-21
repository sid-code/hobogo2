import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ResultScreen extends StatefulWidget {
  static String token = '';
  ResultScreen({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _ResultScreenState createState() => new _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  IOWebSocketChannel ws;
  WebSocket ws2;
  bool firstRun = true;
  Card _genResult(Flight input) {
    Flight inFlight = input;
    return new Card(
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
        ]));
  }

  @override
  Widget build(BuildContext context) {
    if (firstRun) {
      if (!ResultScreen.token.isEmpty) {
        WebSocket
            .connect(
                'ws://142.4.213.30:8080/subscribe?token=' + ResultScreen.token)
            .then((WebSocket socket) {
          ws2 = socket;
        });
      }
      firstRun = !firstRun;
    }
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Results'),
      ),
      body: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new Text(ResultScreen.token),
            new Flexible(
                child: new StreamBuilder(
              stream: ws2,
              builder: (context, snapshot) {
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
              },
            )),
          ],
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
    this.DepartTime = new DateTime(departtime);
    this.ArriveTime = new DateTime(arrivetime);
    this.Price = price;
    this.DeepLink = deeplink;
    this.Passengers = passengers;
    this.TravelTime = this.ArriveTime.difference(this.DepartTime);
  }
}
