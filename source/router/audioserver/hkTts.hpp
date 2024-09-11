#pragma once

#include <iostream>
#include "json.hpp"
#include "utils.h"
#include "public.hpp"

#define NON_PLAY_PRIORITY 100

extern int g_playing_priority;
using json = nlohmann::json;

namespace asns {
    class CStartTTSAudioData {
    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CStartTTSAudioData, indexCode, command, TTSContent, audioLevel, audioOutID,
                                       ttscontent)

    public:
        std::string indexCode;
        std::string command;
        std::string TTSContent;
        int audioLevel;
        std::vector<int> audioOutID;
        std::string ttscontent;
    };

    class CStartTTSAudioResult {
    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CStartTTSAudioResult, status, code, errorMsg, data)

        void do_success(const std::string &msg) {
            status = 200;
            code = "0x00000000";
            errorMsg = msg;
            data = {};
        }

    private:
        int status;
        std::string code;
        std::string errorMsg;
        json data;
    };

    class CStartTTSAudio {
    public:
        std::string parse(const std::string &res) {
            try {
                json js = json::parse(res);
                data = js;
            } catch (json::parse_error &ex) {
                LOG(ERROR) << "parse error at byte " << ex.byte;
                return "";
            }
            LOG(INFO) << "g_playing_priority:" << g_playing_priority << "TTS level:" << data.audioLevel;
            if (g_playing_priority <= data.audioLevel) {
                CStartTTSAudioResult result;
                result.do_success("A high-priority play task has been created");
                json s = result;
                LOG(INFO) << "hk tts res:" << s.dump();
                return s.dump();
            }
            AudioPlayUtil::audio_stop();
            g_playing_priority = data.audioLevel;
            std::string txt = data.ttscontent;
            CUtils::async_wait(1, 0, 0, [txt] {
                LOG(INFO) << "hk tts:" << txt;
                AudioPlayUtil::tts_num_play(1,txt);
                g_playing_priority = NON_PLAY_PRIORITY;
            });
            CStartTTSAudioResult result;
            result.do_success("success");
            json s = result;
            LOG(INFO) << "hk tts res:" << s.dump();
            return s.dump();
        }

    private:
        CStartTTSAudioData data;
    };
}
