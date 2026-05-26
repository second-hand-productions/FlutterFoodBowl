import 'package:pocketbase/pocketbase.dart';

const String mqttHost = '192.168.0.49';
const String topicPrefix = 'home/foodbowl';
const String pbUrl = 'http://pocketbase.lan';

final pb = PocketBase(pbUrl);
