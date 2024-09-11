#ifndef __CGETAUDIOLIST_H__
#define __CGETAUDIOLIST_H__

#include <iostream>
#include "json.hpp"
#include "add_custom_audio_file.hpp"
#include "add_column_custom_audio_file.hpp"
#include "audiocfg.hpp"
#include "utils.h"

using namespace std;

namespace asns {

    class CGetAudioData {
    public:
        int storageType;
        int type;
        string fileName;
        float size;
        int audioId;

    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CGetAudioData, storageType, type, fileName, size, audioId)
    };

    class CGetAudioListResult {
    private:
        string cmd;
        int resultId;
        string msg;
        vector <CGetAudioData> data;

    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CGetAudioListResult, cmd, resultId, data, msg)

    public:
        void do_success() {
            cmd = "GetAudioList";
            resultId = 1;
            msg = "GetAudioList handle success";

            CAddCustomAudioFileBusiness audios;
            audios.load();
            for (auto & busines : audios.business) {
                CGetAudioData v;
                v.storageType = 1;
                v.type = 32;
                busines.parseFile();
                v.fileName = busines.customAudioName;
                CAudioCfgBusiness cfg;
                cfg.load();
                CUtils utils;
                v.size = utils.get_size(cfg.getAudioFilePath().c_str(), busines.customAudioName.c_str());
                v.audioId = busines.customAudioID;
                data.push_back(v);
            }

            CAddColumnCustomAudioFileBusiness business;
            business.Columnload();
            for (const auto &it: business.business) {
                CGetAudioData v;
                v.storageType = 0;
                v.type = 2;
                v.fileName = it.getName();
                CAudioCfgBusiness cfg;
                cfg.load();
                CUtils utils;
                v.size = utils.get_size(cfg.getAudioFilePath().c_str(), it.getName().c_str());
                v.audioId = 0;
                data.push_back(v);
            }
        };
    };

    class CGetAudioList {
    private:
        string cmd;

    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CGetAudioList, cmd)

    public:
        int do_req(CSocket *pClient) {
            CGetAudioListResult res;
            res.do_success();
            json j = res;
            std::string s = j.dump();
            LOG(INFO) <<"return json:"<< s;
            pClient->Send(s.c_str(), s.length());
            return 1;
        }
    };

} // namespace tcpserver
#endif
