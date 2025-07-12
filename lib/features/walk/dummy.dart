import 'package:google_maps_flutter/google_maps_flutter.dart';

class DummyLocation {
  final String name;
  final LatLng coordinates;
  final int popularity;
  final double cost;
  final String description;
  final int estimatedTime; // in minutes
  bool collected;

  DummyLocation({
    required this.name,
    required this.coordinates,
    required this.popularity,
    required this.cost,
    required this.description,
    required this.estimatedTime,
    this.collected = false,
  });
}

class DummyImage {
  final String url;
  final LatLng coordinates;
  DummyImage({required this.url, required this.coordinates});
}

class DummyTask {
  final String description;
  final int totalImagesRequired;
  final List<DummyImage> images;
  final String status;
  int imagesFulfilled;

  DummyTask({
    required this.description,
    required this.totalImagesRequired,
    this.images = const [],
    this.status = 'pending',
    this.imagesFulfilled = 0,
  });
}

// Dummy data for City Walk Plan 1: Historic Downtown
final List<DummyLocation> historicDowntownLocations = [
  DummyLocation(
    name: 'Old Town Square',
    coordinates: LatLng(35.6895, 139.6917),
    popularity: 5,
    cost: 0.0,
    description: 'Historic central square with beautiful architecture',
    estimatedTime: 30,
  ),
  DummyLocation(
    name: 'Heritage Museum',
    coordinates: LatLng(35.6897, 139.6922),
    popularity: 4,
    cost: 10.0,
    description: 'Local history museum with fascinating exhibits',
    estimatedTime: 45,
  ),
  DummyLocation(
    name: 'Victorian Street',
    coordinates: LatLng(35.6899, 139.6925),
    popularity: 4,
    cost: 0.0,
    description: 'Well-preserved Victorian-era street',
    estimatedTime: 25,
  ),
];

final List<DummyTask> historicDowntownTasks = [
  DummyTask(
    description: 'Take a photo of the oldest building in the square',
    totalImagesRequired: 1,
  ),
  DummyTask(
    description: 'Capture three different architectural styles',
    totalImagesRequired: 3,
  ),
  DummyTask(
    description: 'Find and photograph a historical plaque',
    totalImagesRequired: 1,
  ),
];

// Dummy data for City Walk Plan 2: Park and Gardens
final List<DummyLocation> parkAndGardensLocations = [
  DummyLocation(
    name: 'Botanical Gardens Entry',
    coordinates: LatLng(35.6925, 139.6917),
    popularity: 5,
    cost: 5.0,
    description: 'Beautiful entrance to the botanical gardens',
    estimatedTime: 20,
  ),
  DummyLocation(
    name: 'Japanese Garden',
    coordinates: LatLng(35.6927, 139.6920),
    popularity: 5,
    cost: 0.0,
    description: 'Traditional Japanese garden with koi pond',
    estimatedTime: 40,
  ),
  DummyLocation(
    name: 'Rose Garden',
    coordinates: LatLng(35.6929, 139.6923),
    popularity: 4,
    cost: 0.0,
    description: 'Collection of rare and beautiful roses',
    estimatedTime: 30,
  ),
];

final List<DummyTask> parkAndGardensTasks = [
  DummyTask(
    description: 'Photograph three different types of flowers',
    totalImagesRequired: 3,
  ),
  DummyTask(
    description: 'Take a picture of the koi pond',
    totalImagesRequired: 1,
  ),
  DummyTask(
    description: 'Find and photograph a unique tree species',
    totalImagesRequired: 1,
  ),
];

// Dummy data for City Walk Plan 3: City Hills
final List<DummyLocation> cityHillsLocations = [
  DummyLocation(
    name: 'Hill Base Station',
    coordinates: LatLng(35.6955, 139.6917),
    popularity: 3,
    cost: 0.0,
    description: 'Starting point for the hill climb',
    estimatedTime: 15,
  ),
  DummyLocation(
    name: 'Midway Viewpoint',
    coordinates: LatLng(35.6957, 139.6920),
    popularity: 4,
    cost: 0.0,
    description: 'Scenic rest stop with city views',
    estimatedTime: 30,
  ),
  DummyLocation(
    name: 'Summit Lookout',
    coordinates: LatLng(35.6959, 139.6923),
    popularity: 5,
    cost: 0.0,
    description: 'Panoramic views of the entire city',
    estimatedTime: 45,
  ),
];

final List<DummyTask> cityHillsTasks = [
  DummyTask(
    description: 'Take a photo at the base station marker',
    totalImagesRequired: 1,
  ),
  DummyTask(
    description: 'Capture the city view from two different heights',
    totalImagesRequired: 2,
  ),
  DummyTask(
    description: 'Photo of summit achievement marker',
    totalImagesRequired: 1,
  ),
];

// Helper function to get locations and tasks by walk title
Map<String, dynamic> getWalkData(String walkTitle) {
  switch (walkTitle) {
    case 'City Walk Plan 1':
      return {
        'locations': historicDowntownLocations,
        'tasks': historicDowntownTasks,
      };
    case 'City Walk Plan 2':
      return {
        'locations': parkAndGardensLocations,
        'tasks': parkAndGardensTasks,
      };
    case 'City Walk Plan 3':
      return {
        'locations': cityHillsLocations,
        'tasks': cityHillsTasks,
      };
    default:
      return {
        'locations': [],
        'tasks': [],
      };
  }
}
