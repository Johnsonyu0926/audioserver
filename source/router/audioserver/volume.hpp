#ifndef __CVOLUME_H__
#define __CVOLUME_H__

#include <iostream>
#include <fstream>
#include <sstream>
#include "json.hpp"
#include "utils.h"

using namespace std;
using json = nlohmann::json;

namespace asns {
    const std::string VOLUME_JSON_FILE = "/cfg/volume.json";

    class CVolumeSetResult {

    private:
        string cmd;
        int resultId;
        string msg;

    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CVolumeSetResult, cmd, resultId, msg)

    public:
        void do_success() {
            cmd = "VolumeSet";
            resultId = 1;
            msg = "VolumeSet handle success";
        };
    };

    class CVolumeSet {
    private:
        string cmd;
        int volume;

    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CVolumeSet, cmd, volume)

    private:
        int vo[8] = {0, 100, 105, 110, 115, 120, 125, 130};
        //int vo_ros[8] = {0, 10, 20, 25, 30, 40, 45, 50};
        int vo_ros[8] = {0, 4, 8, 12, 17, 22, 27, 32};
        std::string filePath;
    public:
        CVolumeSet() : volume(3) {
            CAudioCfgBusiness business;
            business.load();
            filePath = business.business[0].savePrefix + VOLUME_JSON_FILE;
        }

        std::string getFilePath() const {
            return filePath;
        }

        ~CVolumeSet() = default;

        int getVolume() const { return volume; }

        void setVolume(const int v) { volume = v; }

    public:
        void addj(const int v) const {
            CUtils utils;
            if (utils.is_ros_platform()) {
                //sprintf(cmd, "amixer sset PCM %d", vo_ros[v]);
                char dacxCmd[128] = {0};
                char dac0Cmd[128] = {0};
                sprintf(dacxCmd, "dspset /dev/ttyS2 dacxgan %d", vo_ros[v]);
                sprintf(dac0Cmd, "dspset /dev/ttyS2 dac0gan %d", vo_ros[v]);
                CUtils::cmd_system(dacxCmd);
                usleep(1000 * 100);
                CUtils::cmd_system(dac0Cmd);
            } else {
                char cmd[128] = {0};
                sprintf(cmd, "amixer set Headphone Playback %d", vo[v]);
                CUtils::cmd_system(cmd);
            }
        }

    public:
        int saveToJson() {
            json j;
            j["volume"] = volume;
            std::ofstream o(filePath);
            o << std::setw(4) << j << std::endl;
            char buf[64] = {0};
            sprintf(buf, "cm set_val sys dacxgan %d", volume);
            system(buf);
            sprintf(buf, "cm set_val sys dac0gan %d", volume);
            system(buf);
            o.close();
            return 0;
        }

        void configVolume(const int vol) {
            volume = vol;
            addj(volume);
            saveToJson();
        }

        int load() {
            std::ifstream i(filePath);
            if (!i) {
                LOG(WARNING) << "no volume file , use default volume. file name is:" << filePath;
                return 0;
            }
            json j;
            try {
                i >> j;
                volume = j.at("volume");
            }
            catch (json::parse_error &ex) {
                LOG(ERROR) << "parse error at byte " << ex.byte;
                i.close();
                return -1;
            }
            i.close();
            //addj(volume);
            return 1;
        }

        int do_req(CSocket *pClient) {
            if (volume > 7 || volume < 0) {
                LOG(ERROR) << "volume level error." << volume;
                return -1;
            }
            LOG(INFO) << "volume:" << volume << ",trans to:" << vo[volume];
            addj(volume);
            CVolumeSetResult res;
            res.do_success();
            json j = res;
            std::string s = j.dump();
            LOG(INFO) << "volume set resp and save:" << s;
            saveToJson();
            pClient->Send(s.c_str(), s.length());
            return 1;
        }
    };

} // namespace tcpserver
#endif
