// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:food_saver/models/food_model.dart';
import 'package:food_saver/models/user_model.dart';
import 'package:food_saver/screens/food_details_screen.dart';
import 'package:food_saver/screens/login/textfom.dart';
import 'package:food_saver/screens/mainPage/foods_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:feature_discovery/feature_discovery.dart';

class MyMainpage extends StatefulWidget {
  MyMainpage({super.key});
  static String routename = "/Mainpage";
  static UserModel? currentUser;

  static Future<void> getCurrentUser() async {
    final QuerySnapshot<Map<String, dynamic>> user = await FirebaseFirestore
        .instance
        .collection('users')
        .where('email',
            isEqualTo: FirebaseAuth.instance.currentUser!.email.toString())
        .get();
    MyMainpage.currentUser = UserModel.fromJson(user.docs.first.data());
  }

  static Future<void> removeFoodItemById(String foodId) async {
    CollectionReference collection =
        FirebaseFirestore.instance.collection('foods');
    try {
      QuerySnapshot querySnapshot =
          await collection.where('foodId', isEqualTo: foodId).get();
      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.delete();
        print('Food item with ID $foodId removed successfully');
      } else {
        print('Food item with ID $foodId not found');
      }
    } catch (e) {
      print('Failed to remove food item: $e');
    }
  }

  @override
  State<MyMainpage> createState() => _MyMainpageState();
}

class _MyMainpageState extends State<MyMainpage> {
  final _formKey = GlobalKey<FormState>();

  List<FoodModel> foodItemsList = [];
  List<FoodModel> searchResults = [];
  List<String> features = [
    'feature_1',
    'feature_2',
    'feature_3',
  ];

  bool isSearching = false;
  TextEditingController searchController = TextEditingController();
  TextEditingController placesController = TextEditingController();
  LatLng? foodLocation;
  final uuid = const Uuid();
  String sessionToken = "12345";
  List<dynamic> placesList = [];

  Future<void> getFoodItems() async {
    foodItemsList = [];
    QuerySnapshot<Map<String, dynamic>> foodItemsSnapshot =
        await FirebaseFirestore.instance.collection("foods").get();
    foodItemsSnapshot.docs.map((item) {
      if ((item.data()['picked'] == false || item.data()['picked'] == null)) {
        foodItemsList.add(FoodModel.fromJson(item.data()));
      }
    }).toList();
    setState(() {});
  }

  static const CameraPosition _kLake = CameraPosition(
      bearing: 192.8334901395799,
      target: LatLng(37.43296265331129, -122.08832357078792),
      tilt: 59.440717697143555,
      zoom: 19.151926040649414);

  Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  @override
  void initState() {
    super.initState();
    getFoodItems();
    MyMainpage.getCurrentUser();
    placesController.addListener(() {
      onChange();
    });
    FeatureDiscovery.discoverFeatures(context, features);
    FeatureDiscovery.clearPreferences(context, features);
    setState(() {});
  }

  void onChange() {
    if (sessionToken == null) {
      setState(() {
        sessionToken = uuid.v4();
      });
    }
    if (placesController.text.isEmpty) {
      placesList = [];
      setState(() {});
    }

    getSuggestions(placesController.text);
  }

  void getSuggestions(String query) async {
    const kplacesApiKey = 'AIzaSyCGXjH2olWHaRbJBH4SRNGmYfX60skyWs8';
    String baseURL =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    String requestUrl =
        '$baseURL?input=$query&key=$kplacesApiKey&sessiontoken=$sessionToken';
    var response = await http.get(Uri.parse(requestUrl));
    if (response.statusCode == 200) {
      placesList = jsonDecode(response.body.toString())['predictions'];
      print(placesList);
      setState(() {});
    } else {
      throw Exception('Failed to get Places');
    }
  }

  Future<void> getPlaceDetails(String placeId) async {
    EasyLoading.show(status: "Getting Location Info");
    const kplacesApiKey = 'AIzaSyCGXjH2olWHaRbJBH4SRNGmYfX60skyWs8';
    String baseURL = 'https://maps.googleapis.com/maps/api/place/details/json';
    String request =
        '$baseURL?place_id=$placeId&key=$kplacesApiKey&sessiontoken=$sessionToken';
    var response = await http.get(Uri.parse(request));
    if (response.statusCode == 200) {
      var result = jsonDecode(response.body.toString())['result'];
      var location = result['geometry']['location'];
      setState(() {
        foodLocation = LatLng(location['lat'], location['lng']);
      });
      EasyLoading.dismiss();
    } else {
      EasyLoading.dismiss();
      throw Exception('Failed to get Place details');
    }
  }

  String generateSecureId() {
    var random = Random();
    int randomDigits = random.nextInt(10000);
    String formattedDigits = randomDigits.toString().padLeft(4, '0');
    return 'fsi-$formattedDigits';
  }

  @override
  Widget build(BuildContext context) {
    final double screenWith = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: screenWith,
                    height: screenHeight * 0.2,
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    MyMainpage.currentUser != null
                                        ? MyMainpage.currentUser!.username
                                            .toString()
                                        : 'Loading',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    MyMainpage.currentUser != null
                                        ? ' (${MyMainpage.currentUser!.email.toString()})'
                                        : '',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        overflow: TextOverflow.fade),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () {
                                  Navigator.pushNamed(
                                      context, FoodsPage.routename);
                                },
                                child: DescribedFeatureOverlay(
                                  featureId: features[1],
                                  tapTarget: Icon(
                                    Icons.food_bank,
                                    color: Colors.black87,
                                  ),
                                  title: Text('Food History'),
                                  description: Text(
                                      'Click this icon to go to food history page. Where you can find current and picked food items with proper labels.'),
                                  child: const CircleAvatar(
                                    child: Icon(
                                      Icons.food_bank,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                              // InkWell(
                              //   onTap: () async {
                              //     SharedPreferences sharedPreference =
                              //         await SharedPreferences.getInstance();
                              //     sharedPreference.clear();
                              //     FirebaseAuth.instance.signOut();
                              //     Navigator.pushReplacementNamed(
                              //         context, MyLogin.routename);
                              //   },
                              //   child: const CircleAvatar(
                              //     child: Icon(
                              //       Icons.logout,
                              //       color: Colors.black87,
                              //     ),
                              //   ),
                              // ),
                            ],
                          ),
                          TextFormField(
                            controller: searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                hintText: 'Search Food',
                                hintStyle: const TextStyle(
                                  color: Colors.white54,
                                ),
                                suffixIcon: DescribedFeatureOverlay(
                                  featureId: features[2],
                                  tapTarget: Icon(Icons.search),
                                  contentLocation: ContentLocation.below,
                                  title: Text('Live Search'),
                                  description: Text(
                                    'Live search is here for users ease to get live search results as they are typing food names',
                                  ),
                                  child: const Icon(
                                    Icons.search,
                                    color: Colors.white54,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 15)),
                            onChanged: (value) {
                              searchResults = [];
                              if (value.isNotEmpty) {
                                isSearching = true;
                                foodItemsList.forEach((e) {
                                  if (e.foodName
                                      .toString()
                                      .toLowerCase()
                                      .contains(value.toLowerCase())) {
                                    searchResults.add(e);
                                  }
                                });
                              } else {
                                isSearching = false;
                              }
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: foodItemsList.isNotEmpty
                        ? InkWell(
                            onTapDown: (details) {
                              getFoodItems();
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(top: 20.0),
                              child: RefreshIndicator(
                                onRefresh: () async {
                                  getFoodItems.call();
                                },
                                child: ListView.builder(
                                  itemCount: isSearching
                                      ? searchResults.length
                                      : foodItemsList.length,
                                  itemBuilder: (context, index) {
                                    FoodModel foodItem = isSearching
                                        ? searchResults[index]
                                        : foodItemsList[index];
                                    return InkWell(
                                      onTap: () {
                                        final jsonData = foodItem.toJson();
                                        Navigator.pushNamed(context,
                                            FoodDetailsScreen.routename,
                                            arguments: {'foodItem': jsonData});
                                      },
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            FoodDetailsScreen.routename,
                                            arguments: {
                                              'foodItem': foodItem.toJson(),
                                            },
                                          );
                                        },
                                        onLongPress: () {
                                          showDialog(
                                              context: context,
                                              builder: (context) {
                                                return AlertDialog(
                                                  icon: Icon(Icons.warning),
                                                  title: Text(
                                                      'Are you sure to delete the item (${foodItem.foodName})?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () {
                                                        EasyLoading.show(
                                                            status:
                                                                'Deleting Food Item');
                                                        MyMainpage.removeFoodItemById(
                                                                foodItem.foodId
                                                                    .toString())
                                                            .then((value) {
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                'Food Item Deleted Successfully',
                                                              ),
                                                            ),
                                                          );
                                                          getFoodItems()
                                                              .then((value) {
                                                            EasyLoading
                                                                .dismiss();
                                                            Navigator.pop(
                                                                context);
                                                          });
                                                        });
                                                      },
                                                      child: Text('Yes'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                      },
                                                      child: Text('No'),
                                                    ),
                                                  ],
                                                );
                                              });
                                        },
                                        child: Card(
                                          child: ListTile(
                                            leading: const CircleAvatar(
                                              child: Icon(Icons.food_bank),
                                            ),
                                            title: Text(
                                                foodItem.foodName.toString()),
                                            subtitle: Text(
                                                foodItem.details.toString()),
                                            trailing: const Icon(
                                                Icons.arrow_forward_ios),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          )
                        : const Center(child: Text("No Food Item yet")),
                  ),
                ],
              ),
            ),
            isSearching
                ? Container(
                    width: screenWith * 0.9,
                    height: screenHeight * 0.5,
                    margin: EdgeInsets.only(top: screenHeight * 0.2),
                    decoration:
                        const BoxDecoration(color: Colors.white, boxShadow: [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 25,
                      )
                    ]),
                    child: ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          return InkWell(
                            onTap: () {
                              Navigator.pushNamed(
                                  context, FoodDetailsScreen.routename,
                                  arguments: {
                                    'foodItem': searchResults[index].toJson()
                                  });
                            },
                            child: Card(
                              child: ListTile(
                                title: Text(
                                    searchResults[index].foodName.toString()),
                                trailing: const Icon(Icons.arrow_forward_ios),
                              ),
                            ),
                          );
                        }),
                  )
                : const SizedBox(),
          ],
        ),
      ),
      floatingActionButton: DescribedFeatureOverlay(
        featureId: features[0],
        tapTarget: Icon(Icons.add),
        title: Text('Add a new food item'),
        description: Text('Click this + icon to add a new food item.'),
        contentLocation: ContentLocation.above,
        child: FloatingActionButton(
          backgroundColor: Colors.black87,
          onPressed: () {
            placesController.clear();
            final TextEditingController foodNameController =
                TextEditingController();
            final TextEditingController foodDetailsController =
                TextEditingController();
            final TextEditingController foodExpDateController =
                TextEditingController();
            final TextEditingController foodQuantityController =
                TextEditingController();
            showModalBottomSheet(
                isScrollControlled: true,
                showDragHandle: true,
                context: context,
                builder: (context) {
                  return SizedBox(
                      height: screenHeight * 0.9,
                      width: screenWith,
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 10.0, bottom: 15),
                                child: Text(
                                  'Add a Food Item',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              MyTextform(
                                hintText: 'Enter Food Title',
                                obscureText: false,
                                controller: foodNameController,
                                validator: (value) {
                                  if (value.toString().isEmpty) {
                                    return 'Food Name can\'t be empty';
                                  } else {
                                    return null;
                                  }
                                },
                              ),
                              const SizedBox(
                                height: 15,
                              ),
                              MyTextform(
                                hintText: 'Enter Food Details',
                                obscureText: false,
                                controller: foodDetailsController,
                                validator: (value) {
                                  if (value.toString().isEmpty) {
                                    return 'Food Details can\'t be empty';
                                  } else {
                                    return null;
                                  }
                                },
                              ),
                              const SizedBox(
                                height: 15,
                              ),
                              MyTextform(
                                hintText: 'Enter Expiry Date',
                                obscureText: false,
                                controller: foodExpDateController,
                                validator: (value) {
                                  if (value.toString().isEmpty) {
                                    return 'Expiry Date can\'t be empty';
                                  } else {
                                    return null;
                                  }
                                },
                              ),
                              const SizedBox(
                                height: 15,
                              ),
                              MyTextform(
                                hintText: 'Enter Quantity',
                                obscureText: false,
                                controller: foodQuantityController,
                                validator: (value) {
                                  if (value.toString().isEmpty) {
                                    return 'Food Quantity can\'t be empty';
                                  } else {
                                    return null;
                                  }
                                },
                              ),
                              const SizedBox(
                                height: 15,
                              ),
                              Container(
                                width: screenWith * 0.9,
                                height: 250,
                                decoration: BoxDecoration(
                                    border: Border.all(color: Colors.black87)),
                                child: Stack(
                                  children: [
                                    GoogleMap(
                                      initialCameraPosition: _kLake,
                                      onMapCreated:
                                          (GoogleMapController controller) {
                                        _controller.complete(controller);
                                      },
                                      compassEnabled: false,
                                      zoomControlsEnabled: false,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        children: [
                                          TextFormField(
                                            controller: placesController,
                                            style: const TextStyle(
                                                color: Colors.white),
                                            decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                filled: true,
                                                fillColor: Colors.black45,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                  vertical: 10,
                                                  horizontal: 10,
                                                ),
                                                hintText: 'Search a location',
                                                hintStyle: TextStyle(
                                                    color: Colors.white54)),
                                          ),
                                          placesList.isNotEmpty
                                              ? Container(
                                                  decoration:
                                                      const BoxDecoration(
                                                          color:
                                                              Colors.black45),
                                                  height: 180,
                                                  child: ListView.builder(
                                                    itemCount:
                                                        placesList.length,
                                                    itemBuilder:
                                                        (context, index) {
                                                      return InkWell(
                                                        onTap: () async {
                                                          await getPlaceDetails(
                                                              placesList[index]
                                                                  ['place_id']);
                                                          setState(() {
                                                            placesController
                                                                .text = placesList[
                                                                    index]
                                                                ['description'];
                                                            placesList = [];
                                                          });
                                                        },
                                                        child: ListTile(
                                                          dense: false,
                                                          tileColor:
                                                              Colors.white,
                                                          title: Text(placesList[
                                                                  index]
                                                              ['description']),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                )
                                              : const SizedBox()
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                height: 15,
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    EasyLoading.show(
                                        status: 'Adding Food Item');
                                    FoodModel foodModel = FoodModel(
                                      foodName: foodNameController.text,
                                      foodId: generateSecureId(),
                                      details: foodDetailsController.text,
                                      foodQuantity: foodQuantityController.text,
                                      expiryDate: foodExpDateController.text,
                                      addedBy: MyMainpage.currentUser!.email
                                          .toString(),
                                      locationLat: foodLocation!.latitude,
                                      locationLng: foodLocation!.longitude,
                                      locationName: placesController.text,
                                    );
                                    final jsonFoodData = foodModel.toJson();
                                    FirebaseFirestore.instance
                                        .collection('foods')
                                        .add(jsonFoodData)
                                        .then((value) {
                                      getFoodItems().then((value) {
                                        Navigator.pop(context);
                                      });
                                    });
                                    EasyLoading.dismiss();
                                  } else {
                                    print('HELO');
                                    EasyLoading.dismiss();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  maximumSize: Size(screenWith * 0.9, 50),
                                  minimumSize: Size(screenWith * 0.9, 50),
                                  backgroundColor: Colors.black87,
                                ),
                                child: const Text(
                                  'Add Item',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              const SizedBox(
                                height: 20,
                              )
                            ],
                          ),
                        ),
                      ));
                });
          },
          child: const Icon(
            Icons.add,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
