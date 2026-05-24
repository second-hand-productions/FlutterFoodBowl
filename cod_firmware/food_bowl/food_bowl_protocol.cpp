#include "food_bowl_protocol.h"

#include <WiFi.h>
#include <stdio.h>

void buildIdentity(FoodBowlIdentity& identity) {
  uint8_t mac[6];
  WiFi.macAddress(mac);

  snprintf(
    identity.macAddress,
    sizeof(identity.macAddress),
    "%02x:%02x:%02x:%02x:%02x:%02x",
    mac[0],
    mac[1],
    mac[2],
    mac[3],
    mac[4],
    mac[5]
  );

  snprintf(
    identity.bowlId,
    sizeof(identity.bowlId),
    "bowl-%02x%02x%02x%02x%02x%02x",
    mac[0],
    mac[1],
    mac[2],
    mac[3],
    mac[4],
    mac[5]
  );

  snprintf(
    identity.clientId,
    sizeof(identity.clientId),
    "foodbowl-%s",
    identity.bowlId
  );
}

void buildTopics(const char* bowlId, FoodBowlTopics& topics) {
  snprintf(
    topics.discovery,
    sizeof(topics.discovery),
    "foodbowl/discovery/%s",
    bowlId
  );
  snprintf(
    topics.command,
    sizeof(topics.command),
    "foodbowl/%s/door/set",
    bowlId
  );
  snprintf(
    topics.status,
    sizeof(topics.status),
    "foodbowl/%s/door/status",
    bowlId
  );
  snprintf(
    topics.result,
    sizeof(topics.result),
    "foodbowl/%s/door/result",
    bowlId
  );
  snprintf(
    topics.availability,
    sizeof(topics.availability),
    "foodbowl/%s/door/availability",
    bowlId
  );
}

void buildDiscoveryPayload(
  const FoodBowlIdentity& identity,
  const char* ipAddress,
  char* payload,
  size_t payloadSize
) {
  snprintf(
    payload,
    payloadSize,
    "{\"bowl_id\":\"%s\",\"mac_address\":\"%s\",\"ip_address\":\"%s\"}",
    identity.bowlId,
    identity.macAddress,
    ipAddress
  );
}

void buildResultPayload(
  const char* command,
  bool ok,
  const char* status,
  const char* detail,
  char* payload,
  size_t payloadSize
) {
  snprintf(
    payload,
    payloadSize,
    "{\"command\":\"%s\",\"success\":%s,\"status\":\"%s\",\"detail\":\"%s\"}",
    command,
    ok ? "true" : "false",
    status,
    detail
  );
}
