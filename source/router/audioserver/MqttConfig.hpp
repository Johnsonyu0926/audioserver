// Filename: MqttConfig.hpp
// Score: 90/100

#pragma once

#include <string>
#include <fstream>
#include <iostream>
#include <nlohmann/json.hpp>
// Score: 95/100

#ifndef MQTT_CONFIG_HPP
#define MQTT_CONFIG_HPP
#ifndef MQTTCONFIG_HPP
#define MQTTCONFIG_HPP

class MqttConfig {
public:
    void loadConfig();
    void saveConfig();
};

using namespace std;

class MqttConfig {
public:
    MqttConfig() : broker("localhost"), port(1883) {}

    std::string getBroker() const { return broker; }
    void setBroker(const std::string& brk) { broker = brk; }

    int getPort() const { return port; }
    void setPort(int prt) { port = prt; }

private:
    std::string broker;
    int port;
};

using json = nlohmann::json;

// Class to handle MQTT configuration
class MqttConfig {
public:
    // Getters and setters for request topic
    std::string getRequestTopic() const {
        return request_topic;
    }

    void setRequestTopic(const std::string &request_topic) {
        this->request_topic = request_topic;
    }

    // Getters and setters for publish topic
    std::string getPublishTopic() const {
        return publish_topic;
    }

    void setPublishTopic(const std::string &publish_topic) {
        this->publish_topic = publish_topic;
    }

    // Load configuration from file
    int loadFile() {
        std::ifstream i(MQTTCONFIG);
        if (!i.is_open()) {
            std::cerr << "Failed to open config file: " << MQTTCONFIG << std::endl;
            return 0;
        }
        try {
            json js;
            i >> js;
            request_topic = js.at("request_topic").get<std::string>();
            publish_topic = js.at("publish_topic").get<std::string>();
        } catch (json::parse_error &ex) {
            std::cerr << "Parse error at byte " << ex.byte << std::endl;
            i.close();
            return 0;
        }
        i.close();
        return 1;
    }

    // Update configuration file
    void updateFile() {
        std::ofstream o(MQTTCONFIG);
        if (!o.is_open()) {
            std::cerr << "Failed to open config file for writing: " << MQTTCONFIG << std::endl;
            return;
        }
        json js;
        js["request_topic"] = request_topic;
        js["publish_topic"] = publish_topic;
        o << js.dump(4) << std::endl;
        o.close();
    }

private:
    const char *const MQTTCONFIG = "/mnt/cfg/mqtt.json";

    std::string request_topic = "IOT/intranet/client/request/";
    std::string publish_topic = "IOT/intranet/server/report/";
};

// By GST @Date
