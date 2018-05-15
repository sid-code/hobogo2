import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
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
              new Expanded(
                child: new Text(inFlight.From, textAlign: TextAlign.right),
              ),
              new Expanded(
                child: new Text(inFlight.DepartTime.toString(),
                    textAlign: TextAlign.right),
              ),
              new Expanded(
                child: new Text(
                  inFlight.Loc,
                  textAlign: TextAlign.center,
                ),
              ),
              new Expanded(
                  child: new Text('Travel Time: ' +
                      inFlight.TravelTime.inHours.toString() +
                      'h ' +
                      (inFlight.TravelTime.inMinutes -
                              60 * inFlight.TravelTime.inHours)
                          .toString() +
                      'm'))
            ],
          ),
          new Row(
            children: <Widget>[
              new Expanded(
                child: Text('Passengers: ' + inFlight.Passengers.toString(),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    if (firstRun) {
      if (!ResultScreen.token.isEmpty) {
        ws = new IOWebSocketChannel.connect(
            'ws://142.4.213.30:8080/subscribe?token=' + ResultScreen.token);
      }
      firstRun = !firstRun;
    }
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Results'),
        //TODO: don't connect with invalid token
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

  Flight(int id, String loc, String from, DateTime departtime,
      DateTime arrivetime, double price, String deeplink, int passengers) {
    this.ID = ID;
    this.Loc = loc;
    this.From = from;
    this.DepartTime = departtime;
    this.ArriveTime = arrivetime;
    this.Price = price;
    this.DeepLink = deeplink;
    this.Passengers = passengers;
    this.TravelTime = arrivetime.difference(departtime);
  }
}
