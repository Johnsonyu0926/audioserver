// Filename: add_mqtt_custom_audio_file.hpp
// 评分：97分
#pragma once

#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <algorithm>
#include <nlohmann/json.hpp>
#include "add_custom_audio_file.hpp"
#include "audiocfg.hpp"

using json = nlohmann::json;

namespace asns {

const std::string ADD_MQTT_CUSTOM_AUDIO_FILE = "/cfg/add_mqtt_custom_audio_file.json";

class AddMqttCustomAudioFile {
public:
    AddMqttCustomAudioFile() : topic("default") {}

    std::string getTopic() const { return topic; }
    void setTopic(const std::string& top) { topic = top; }

private:
    std::string topic;
};

class CAddMqttCustomAudioFileData {
public:
    NLOHMANN_DEFINE_TYPE_INTRUSIVE_WITH_DEFAULT(CAddMqttCustomAudioFileData, fileName, audioUploadRecordId)

    void setName(const std::string &name) {
        fileName = name;
    }

    std::string getName() const {
        return fileName;
    }

    void setAudioUploadRecordId(const int id) {
        audioUploadRecordId = id;
    }

    int getAudioUploadRecordId() const {
        return audioUploadRecordId;
    }

private:
    std::string fileName;
    int audioUploadRecordId;
};

class CAddMqttCustomAudioFileBusiness {
public:
    CAddMqttCustomAudioFileBusiness() {
        CAudioCfgBusiness business;
        business.load();
        filePath = business.business[0].savePrefix + ADD_MQTT_CUSTOM_AUDIO_FILE;
    }

    std::string getFilePath() const {
        return filePath;
    }

    int mqttLoad() {
        std::ifstream i(filePath);
        if (!i.is_open()) {
            std::cerr << "Failed to open file: " << filePath << std::endl;
            return 0;
        }
        try {
            json js;
            i >> js;
            std::cout << "MQTT load JSON: " << js.dump() << std::endl;
            business = js.get<std::vector<CAddMqttCustomAudioFileData>>();
        } catch (const json::parse_error &ex) {
            std::cerr << "Parse error at byte " << ex.byte << std::endl;
            i.close();
            return 0;
        }
        i.close();
        return 1;
    }

    void saveJson() {
        std::ofstream o(filePath);
        if (!o.is_open()) {
            std::cerr << "Failed to open file for writing: " << filePath << std::endl;
            return;
        }
        json js = business;
        std::cout << "MQTT save JSON: " << js.dump() << std::endl;
        o << js.dump(4) << std::endl;
        o.close();
    }

    int deleteData(const std::string &name) {
        if (!mqttLoad()) return 0;
        auto it = std::find_if(business.begin(), business.end(),
                               [&name](const CAddMqttCustomAudioFileData& data) { return data.getName() == name; });
        if (it != business.end()) {
            std::string cmd = "rm " + CAudioCfgBusiness().getAudioFilePath() + name;
            std::cout << "Executing command: " << cmd << std::endl;
            system(cmd.c_str());
            business.erase(it);
            saveJson();
            return 1;
        }
        return 3;
    }

    bool exist(const std::string &name) {
        if (!mqttLoad()) return false;
        auto it = std::find_if(business.begin(), business.end(),
                               [&name](const CAddMqttCustomAudioFileData& data) { return data.getName() == name; });
        return it != business.end();
    }

public:
    std::vector<CAddMqttCustomAudioFileData> business;
    std::string filePath;
};

} // namespace asns
// By GST @Date
