#ifndef FOOD_BOWL_PROTOCOL_H
#define FOOD_BOWL_PROTOCOL_H

#include <stddef.h>

struct FoodBowlIdentity {
  char bowlId[24];
  char macAddress[18];
  char clientId[64];
};

struct FoodBowlTopics {
  char discovery[80];
  char command[80];
  char status[80];
  char result[80];
  char availability[88];
};

void buildIdentity(FoodBowlIdentity& identity);
void buildTopics(const char* bowlId, FoodBowlTopics& topics);

void buildDiscoveryPayload(
  const FoodBowlIdentity& identity,
  const char* ipAddress,
  char* payload,
  size_t payloadSize
);

void buildResultPayload(
  const char* command,
  bool ok,
  const char* status,
  const char* detail,
  char* payload,
  size_t payloadSize
);

#endif
