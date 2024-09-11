#ifndef __ADD_CUSTOM_AUDIO_FILE_H__
#define __ADD_CUSTOM_AUDIO_FILE_H__

#include <iostream>
#include <fstream>
#include <sstream>
#include "utils.h"
#include "json.hpp"
#include "doorsbase.h"
#include "audiocfg.hpp"
#include "public.hpp"
#include "AudioPlayStatus.hpp"
#include "AudioPlayUtils.hpp"

extern int g_updateJson;
using namespace std;
using json = nlohmann::json;
// extern vector<int> playing;

namespace asns {
    const std::string ADD_CUSTOM_AUDIO_FILE = "/cfg/add_custom_audio_file.json";

    class CAddCustomAudioFileData {
    public:
        int customAudioID;
        string customAudioName;
        string filePath;
        string filePathType;
        char filename[128];

    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE_WITH_DEFAULT(CAddCustomAudioFileData, customAudioID, customAudioName, filePath,
                                                    filePathType)

        const char *getCustomAudioName() const { return customAudioName.c_str(); }

        char *parseFile() {
            char *p1 = strstr(filePath.c_str(), "?filename=");
            if (p1) {
                p1 += strlen("?filename=");
                char *p2 = strchr(p1, '&');
                if (p2) {
                    strncpy(filename, p1, p2 - p1);
                }
            }
            return filename;
        }

        const char *getFileName() const { return filename; }

        const char *getFilePath() const { return filePath.c_str(); }

        int getCustomAudioID() const { return customAudioID; }

        int play(const string& prefix, const string& endTime, const int priority) {
            if (strlen(filename) <= 0) {
                parseFile();
            }
            CUtils utils;
            LOG(INFO) << "custom audio file data : playing " << customAudioID << ",file" << customAudioName;

            // background play. and monitor....
            //
            char cmd[256] = {0};
            sprintf(cmd, "madplay %s%s", prefix.c_str(), getFileName());
            char background_cmd[256] = {0};
            sprintf(background_cmd, "%s&", cmd);
            LOG(INFO) << "palying status :" <<  CUtils::get_process_status("madplay");
            system(background_cmd); // background play
            LOG(INFO) << "cmd: " << background_cmd;
            PlayStatus::getInstance().setPlayId(asns::TIMED_TASK_PLAYING);
            PlayStatus::getInstance().setPriority(priority);

            CSTime tnow;

            tnow.GetCurTime();
            int h, m, s;
            sscanf(endTime.c_str(), "%d:%d:%d", &h, &m, &s);
            CSTime t1(tnow.m_nYear, tnow.m_nMon, tnow.m_nDay, h, m, s);

            while (1) {

                tnow.GetCurTime();

                int exist = CUtils::get_process_status(cmd);
                if (!exist) {
                    LOG(INFO) << "play finish of cmd:" << cmd;
                    break;
                }
                if (tnow.m_time <= t1.m_time) {
                    // current time is match. waiting
                    LOG(INFO) << "playing:" << cmd;
                    sleep(1);
                } else {
                    // out of time. stop if it is playing...
                    LOG(INFO) << "out of time. play stop! last cmd is:" << cmd;
                    AudioPlayUtil::audio_stop();
                }
                if(g_updateJson){
                    // out of time. stop if it is playing...
                    LOG(INFO) << "get new json stop now audio";
                    AudioPlayUtil::audio_stop();
                }
                sleep(2);
            }
            return 0;
        }
    };

    class CSpeechSynthesisBusiness {
    public:
        int play(const string& endTime, const int priority, const std::string &txt, const std::string &voiceType,const int model) {
            CUtils utils;
            if(model == SINGLE_PLAY){
                AudioPlayUtil::tts_num_play(1,txt);
                return 0;
            }
            AudioPlayUtil::tts_num_play(1, txt, ASYNC_START, 50, FEMALE);
            CSTime tnow;
            tnow.GetCurTime();
            int h, m, s;
            sscanf(endTime.c_str(), "%d:%d:%d", &h, &m, &s);
            CSTime t1(tnow.m_nYear, tnow.m_nMon, tnow.m_nDay, h, m, s);

            while (1) {
                tnow.GetCurTime();
                int exist = CUtils::get_process_status("ffplay") || CUtils::get_process_status("tts.sh") || CUtils::get_process_status("madplay");
                if (!exist) {
                    LOG(INFO) << "play finish of tts";
                    break;
                }
                if (tnow.m_time <= t1.m_time) {
                    // current time is match. waiting
                    LOG(INFO) << "playing tts";
                    sleep(1);
                } else {
                    // out of time. stop if it is playing...
                    LOG(INFO) << "out of time. play stop! last tts";
                    AudioPlayUtil::audio_stop();
                }
                if(g_updateJson){
                    // out of time. stop if it is playing...
                    LOG(INFO) << "get new json stop now tts";
                    AudioPlayUtil::audio_stop();
                }
                sleep(2);
            }
            return 0;
        }
    };

    class CAddCustomAudioFileBusiness {
    public:
        vector <CAddCustomAudioFileData> business;
        std::string filePath;
    public:
        string savePrefix;

        CAddCustomAudioFileBusiness() {
            CAudioCfgBusiness business;
            business.load();
            filePath = business.business[0].savePrefix + ADD_CUSTOM_AUDIO_FILE;
        }

        std::string getFilePath() const {
            return filePath;
        }

        int parseRequest(const string& data) {
            cout << data << endl;
            json j = json::parse(data, nullptr, false);
            try {
                business = j.at("data");
            }
            catch (json::parse_error &ex) {
                LOG(ERROR) << "parse error at byte " << ex.byte;
                return -1;
            }
            return 0;
        }

        int add(const string& data) {
            cout << data << endl;
            json j = json::parse(data, nullptr, false);
            try {
                CAddCustomAudioFileData node = j.at("data");

                if (exist(node)) {
                    LOG(INFO) << "exist node ";
                    return 0;
                }
                append(node);
            }
            catch (json::parse_error &ex) {
                LOG(ERROR) << "parse error at byte " << ex.byte;
                return -1;
            }
            return 0;
        }

        int exist(const CAddCustomAudioFileData& node) {
            for (const auto& data : business) {
                if (data.getCustomAudioID() == node.getCustomAudioID()) {
                    return 1;
                }
            }
            return 0;
        }

        int exist(const std::string &name) {
            load();
            for (auto & busines : business) {
                if (busines.customAudioName == name) {
                    return 1;
                }
            }
            return 0;
        }

        int append(const CAddCustomAudioFileData& node) {
            business.push_back(node);
            download(node);
            saveToJson();
            return 0;
        }

        int saveToJson() {
            json j;
            j["data"] = business;
            std::ofstream o(filePath);
            o << std::setw(4) << j << std::endl;
            o.close();
            return 0;
        }

        int download(CAddCustomAudioFileData node) const {
            char cmd[1024] = {0};
            node.parseFile();
            sprintf(cmd, "dodownload.sh \"%s\" \"%s/%s\"",
                    (char *) node.getFilePath(),
                    savePrefix.c_str(),
                    (char *) node.getFileName());
            LOG(INFO) << "===========NLOHMANN_DEFINE_TYPE_INTRUSIVE=========:" << cmd;
            system(cmd);
            return 0;
        }

        int load() {
            std::ifstream i(filePath);
            if (!i) {
                return 0;
            }
            json j;
            try {
                i >> j;
                business = j.at("data");
            }
            catch (json::parse_error &ex) {
                LOG(ERROR) << "parse error at byte " << ex.byte;
                return -1;
            }
            LOG(INFO) << "load " << ADD_CUSTOM_AUDIO_FILE.c_str() << "  success! ";
            LOG(INFO) << "count:" << business.size();
            return 0;
        }

        int play(const int id, const string& endtime, const int priority) const {
            LOG(INFO) << "business count:" << business.size();
            for (auto data : business) {
                LOG(INFO) << "CustomAudioID： " << data.getCustomAudioID() << " id: " << id;
                if (data.getCustomAudioID() == id) {
                    LOG(INFO) << "savePrefix： " << savePrefix.c_str() << " endtime " << endtime.c_str() << "priority" << priority;
                    data.play(savePrefix, endtime, priority);
                }
            }
            return 0;
        }

        int deleteAudio(const std::string& name) {
            this->load();
            for (auto it = business.begin(); it != business.end(); ++it) {
                if (it->customAudioName == name) {
                    char cmd[256] = {0};
                    CAudioCfgBusiness cfg;
                    cfg.load();

                    sprintf(cmd, "rm %s%s", cfg.getAudioFilePath().c_str(), name.c_str());
                    LOG(INFO) << "cmd: " << cmd;
                    system(cmd);
                    business.erase(it);
                    this->saveToJson();
                    return 1;
                }
            }
            return 0;
        }
    };
}
#endif
