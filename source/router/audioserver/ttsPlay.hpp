#pragma once

#include "json.hpp"
#include "utils.h"
#include "public.hpp"
#include <thread>
#include "AudioPlayUtils.hpp"

namespace asns {
    class CTtsPlayResult {
    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CTtsPlayResult, cmd, resultId, msg)

        void do_success() {
            cmd = "TtsPlay";
            resultId = 1;
            msg = "play success";
        }

        void do_fail(const std::string& str) {
            cmd = "TtsPlay";
            resultId = 2;
            msg = str;
        }

    private:
        std::string cmd;
        int resultId;
        std::string msg;
    };

    class CTtsPlay {
    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CTtsPlay, cmd, content, playType, duration, voiceType, speed)

        int do_req(CSocket *pClient) {
            CTtsPlayResult ttsPlayResult;
            ttsPlayResult.do_success();
            CUtils utils;
            if (CUtils::get_process_status("madplay") || CUtils::get_process_status("ffplay") || PlayStatus::getInstance().getPlayState()) {
                ttsPlayResult.do_fail("Existing playback task");
            } else {
                std::string txt = utils.hex_to_string(content);
                switch (playType) {
                    case 0:
                        AudioPlayUtil::tts_loop_play(txt, ASYNC_START, speed, voiceType);
                        break;
                    case 1: {
                        if (duration < 1) {
                            ttsPlayResult.do_fail("parameter cannot be less than 1");
                            break;
                        }
                        AudioPlayUtil::tts_num_play(duration, txt, ASYNC_START, speed, voiceType);
                        break;
                    }
                    case 2: {
                        if (duration < 1) {
                            ttsPlayResult.do_fail("parameter cannot be less than 1");
                            break;
                        }
                        AudioPlayUtil::tts_time_play(duration, txt, ASYNC_START, speed,voiceType);
                        break;
                    }
                }
            }
            json js = ttsPlayResult;
            std::string str = js.dump();
            return pClient->Send(str.c_str(), str.length());
        }

    private:
        std::string cmd;
        std::string content;
        int playType;
        int duration;
        int voiceType;
        int speed;
    };
}