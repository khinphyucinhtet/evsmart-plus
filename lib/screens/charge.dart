import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'menu.dart';
import 'home_driver.dart';
import 'alert.dart';
import 'noti.dart';
import 'rewards.dart';
import 'global_search.dart';
import 'app_header.dart';

class ChargePage extends StatefulWidget {
  const ChargePage({super.key});

  @override
  State<ChargePage> createState() => _ChargePageState();
}

class _ChargePageState extends State<ChargePage> {

  int selectedTab = 1;

  final MapController mapController = MapController();

  final LatLng defaultCenter =
  const LatLng(3.0738, 101.5183);

  LatLng? userLocation;

  StreamSubscription<Position>? positionStream;

  bool followUser = true;

  // SEARCH
  final TextEditingController searchController =
  TextEditingController();

  List<Map<String, dynamic>> filteredStations = [];

  bool showSuggestions = false;

  // STATIONS
  final List<Map<String, dynamic>> stations = [

    {"name":"Tesla Supercharger - Setia City Mall","lat":3.1127,"lng":101.4631,"chargers":6,"queue":2,"wait":"10 mins"},
    {"name":"ChargeEV - i-City","lat":3.0648,"lng":101.4876,"chargers":4,"queue":1,"wait":"5 mins"},
    {"name":"JomCharge - UITM Shah Alam","lat":3.0733,"lng":101.4992,"chargers":3,"queue":0,"wait":"0 mins"},
    {"name":"Shell Recharge - Seksyen 13","lat":3.0835,"lng":101.5298,"chargers":2,"queue":3,"wait":"15 mins"},
    {"name":"Petronas EV Charger - Seksyen 7","lat":3.0716,"lng":101.5062,"chargers":4,"queue":1,"wait":"6 mins"},
    {"name":"DC Handal - Shah Alam Stadium","lat":3.0822,"lng":101.5481,"chargers":5,"queue":4,"wait":"20 mins"}

  ];

  @override
  void initState() {
    super.initState();
    _requestLocation();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    searchController.dispose();
    super.dispose();
  }

  // LOCATION

  Future<void> _requestLocation() async {

    bool serviceEnabled =
    await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }

    if (permission == LocationPermission.denied) {
      return;
    }

    positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 2,
          ),
        ).listen((Position position) {

          LatLng newLoc =
          LatLng(position.latitude, position.longitude);

          setState(() {
            userLocation = newLoc;
          });

          if (followUser) {
            mapController.move(newLoc, 17);
          }
        });
  }

  // SEARCH LOGIC

  void searchStations(String query) {

    if (query.isEmpty) {

      setState(() {
        showSuggestions = false;
      });

      return;
    }

    List<Map<String, dynamic>> results =
    stations.where((station) {

      return station["name"]
          .toLowerCase()
          .contains(query.toLowerCase());

    }).toList();

    // sort by nearest

    if(userLocation!=null){

      results.sort((a,b){

        double da = Geolocator.distanceBetween(
            userLocation!.latitude,
            userLocation!.longitude,
            a["lat"],
            a["lng"]);

        double db = Geolocator.distanceBetween(
            userLocation!.latitude,
            userLocation!.longitude,
            b["lat"],
            b["lng"]);

        return da.compareTo(db);

      });

    }

    setState(() {

      filteredStations = results;
      showSuggestions = true;

    });

  }

  // SELECT STATION

  void selectStation(Map station){

    LatLng point =
    LatLng(station["lat"], station["lng"]);

    mapController.move(point,17);

    showStationPopup(station);

    setState(() {

      showSuggestions=false;
      searchController.clear();

    });

  }

  // DISTANCE

  String distanceToStation(double lat,double lng){

    if(userLocation==null) return "";

    double meters = Geolocator.distanceBetween(
        userLocation!.latitude,
        userLocation!.longitude,
        lat,
        lng);

    double km = meters/1000;

    return "${km.toStringAsFixed(1)} km away";
  }

  // NAVIGATION

  Future<void> navigateToStation(double lat,double lng) async {

    final Uri uri =
    Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");

    if(await canLaunchUrl(uri)){

      await launchUrl(uri);

    }

  }

  // POPUP

  void showStationPopup(Map station){

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {

        Color queueColor = Colors.green;

        if(station["queue"]>=3){
          queueColor = Colors.orange;
        }

        if(station["queue"]>=5){
          queueColor = Colors.red;
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20,20,20,30),
            child: SizedBox(
              height:280,
              child:Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children:[

                  Text(
                    station["name"],
                    style: const TextStyle(
                        fontSize:18,
                        fontWeight:FontWeight.bold),
                  ),

                  const SizedBox(height:15),

                  Row(
                    children:[
                      const Icon(Icons.ev_station,color:Colors.green),
                      const SizedBox(width:8),
                      Text("Chargers: ${station["chargers"]}")
                    ],
                  ),

                  const SizedBox(height:10),

                  Row(
                    children:[
                      const Icon(Icons.directions_car),
                      const SizedBox(width:8),
                      Text(
                        "Queue: ${station["queue"]}",
                        style:TextStyle(color:queueColor),
                      )
                    ],
                  ),

                  const SizedBox(height:10),

                  Row(
                    children:[
                      const Icon(Icons.timer),
                      const SizedBox(width:8),
                      Text("Estimated Wait: ${station["wait"]}")
                    ],
                  ),

                  const Spacer(),

                  Row(
                    children:[

                      Expanded(
                        child:OutlinedButton(
                          onPressed:(){
                            Navigator.pop(context);
                          },
                          child:const Text("Cancel"),
                        ),
                      ),

                      const SizedBox(width:12),

                      Expanded(
                        child:ElevatedButton(
                          style:ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFF2E7D32),
                          ),
                          onPressed:(){

                            Navigator.pop(context);

                            navigateToStation(
                                station["lat"],
                                station["lng"]);

                          },
                          child:const Text(
                            "LOCATE",
                            style:TextStyle(
                                color:Colors.white,
                                fontWeight:FontWeight.bold),
                          ),
                        ),
                      )

                    ],
                  )

                ],
              ),
            ),
          ),
        );

      },
    );

  }

  // MARKERS

  List<Marker> buildMarkers(){

    List<Marker> markers=[];

    if(userLocation!=null){

      markers.add(

        Marker(
          point:userLocation!,
          width:40,
          height:40,
          child:Container(
            decoration:BoxDecoration(
              shape:BoxShape.circle,
              color:Colors.blue,
              border:Border.all(color:Colors.white,width:4),
              boxShadow:[
                BoxShadow(
                  color:Colors.blue.withOpacity(0.6),
                  blurRadius:10,
                  spreadRadius:2,
                )
              ],
            ),
          ),
        ),

      );

    }

    for(var s in stations){

      markers.add(

        Marker(
          point:LatLng(s["lat"],s["lng"]),
          width:50,
          height:50,
          child:GestureDetector(
            onTap:(){
              showStationPopup(s);
            },
            child:Container(
              decoration:BoxDecoration(
                shape:BoxShape.circle,
                color:const Color(0xFF2E7D32),
                border:Border.all(color:Colors.black,width:2),
                boxShadow:[
                  BoxShadow(
                    color:Colors.green.withOpacity(0.7),
                    blurRadius:12,
                    spreadRadius:2,
                  )
                ],
              ),
              child:const Icon(
                Icons.ev_station,
                color:Colors.white,
                size:28,
              ),
            ),
          ),
        ),

      );

    }

    return markers;

  }

  // UI

  @override
  Widget build(BuildContext context){

    final double bottomSystem =
        MediaQuery.of(context).padding.bottom;

    return Scaffold(

      backgroundColor:Colors.white,

      body:Column(
        children:[

          AppHeader(
            onSearch:(key){
              GlobalSearchHandler
                  .handleSearch(context,key);
            },
          ),

          Expanded(
            child:Stack(
              children:[

                FlutterMap(
                  mapController:mapController,
                  options:MapOptions(
                    initialCenter:defaultCenter,
                    initialZoom:14.5,
                  ),
                  children:[

                    TileLayer(
                      urlTemplate:
                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName:
                      "com.evsmart.plus.evsmart_plus",
                    ),

                    MarkerLayer(
                      markers:buildMarkers(),
                    ),

                  ],
                ),

                // SEARCH BAR

                Positioned(
                  bottom:70,
                  left:15,
                  right:15,
                  child:Column(
                    children:[

                      Container(
                        decoration:BoxDecoration(
                          color:Colors.white,
                          borderRadius:
                          BorderRadius.circular(14),
                          boxShadow:[
                            BoxShadow(
                              color:Colors.black26,
                              blurRadius:8,
                            )
                          ],
                        ),
                        child:TextField(
                          controller:searchController,
                          onChanged:searchStations,
                          decoration:const InputDecoration(
                            hintText:
                            "Search charging stations...",
                            prefixIcon:Icon(Icons.search),
                            border:InputBorder.none,
                            contentPadding:
                            EdgeInsets.all(14),
                          ),
                        ),
                      ),

                      if(showSuggestions)

                        Container(
                          margin:
                          const EdgeInsets.only(top:6),
                          decoration:BoxDecoration(
                            color:Colors.white,
                            borderRadius:
                            BorderRadius.circular(12),
                            boxShadow:[
                              BoxShadow(
                                blurRadius:8,
                                color:Colors.black12,
                              )
                            ],
                          ),
                          child:ListView.builder(
                            shrinkWrap:true,
                            itemCount:
                            filteredStations.length,
                            itemBuilder:(context,index){

                              final station =
                              filteredStations[index];

                              return ListTile(
                                leading:const Icon(
                                  Icons.ev_station,
                                  color:Color(0xFF2E7D32),
                                ),
                                title:Text(station["name"]),
                                subtitle:Text(
                                  distanceToStation(
                                      station["lat"],
                                      station["lng"]),
                                ),
                                onTap:() =>
                                    selectStation(station),
                              );

                            },
                          ),
                        )

                    ],
                  ),
                ),

                // MY LOCATION BUTTON

                Positioned(
                  bottom:20,
                  right:20,
                  child:GestureDetector(
                    onTap:(){

                      if(userLocation!=null){

                        mapController.move(
                            userLocation!,17);

                      }

                    },
                    child:Container(
                      height:52,
                      width:52,
                      decoration:const BoxDecoration(
                        color:Color(0xFF2E7D32),
                        shape:BoxShape.circle,
                      ),
                      child:const Icon(
                        Icons.my_location,
                        color:Colors.white,
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),

        ],
      ),

      bottomNavigationBar:Container(

        height:85+bottomSystem,

        padding:EdgeInsets.only(
          top:8,
          bottom:bottomSystem+8,
        ),

        decoration:const BoxDecoration(
          color:Colors.white,
          boxShadow:[
            BoxShadow(
              blurRadius:12,
              color:Colors.black12,
            )
          ],
        ),

        child:Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceAround,
          children:[

            buildTab(Icons.home,"Home",0),
            buildTab(Icons.ev_station,"Charge",1),
            buildTab(Icons.warning,"Alert",2),
            buildTab(Icons.notifications,"Noti",3),
            buildTab(Icons.card_giftcard,"Rewards",4),

          ],
        ),

      ),

    );

  }

  Widget buildTab(
      IconData icon,String label,int index){

    bool isActive = selectedTab == index;

    return GestureDetector(
      onTap:(){

        if(index==1) return;

        if(index==0){
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder:(_)=>const DriverHomePage()));
        }

        if(index==2){
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder:(_)=>const AlertPage()));
        }

        if(index==3){
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder:(_)=>const NotificationPage()));
        }

        if(index==4){
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder:(_)=>const RewardsPage()));
        }

      },

      child:Container(

        width:70,

        decoration:isActive
            ?BoxDecoration(
          color:const Color(0xFF2E7D32)
              .withOpacity(0.1),
          borderRadius:
          BorderRadius.circular(12),
        )
            :null,

        child:Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children:[

            Icon(
              icon,
              size:24,
              color:isActive
                  ?const Color(0xFF2E7D32)
                  :Colors.grey,
            ),

            const SizedBox(height:4),

            Text(
              label,
              style:TextStyle(
                fontSize:12,
                color:isActive
                    ?const Color(0xFF2E7D32)
                    :Colors.grey,
              ),
            ),

          ],
        ),

      ),

    );

  }

}