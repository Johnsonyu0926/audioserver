#pragma once

#include "json.hpp"
#include "audiocfg.hpp"
#include "utils.h"
#include "public.hpp"

//{"duration":"5","uploadUrl":"http://192.168.85.1:8091/iot/1v1/api/v1/micRecordUpload","cmd":"MicRecord"}
namespace asns {

    class CMicRecordResult {
    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CMicRecordResult, cmd, resultId, msg)

        void do_success() {
            cmd = "MicRecord";
            resultId = 1;
            msg = "success";
        }

        void do_fail(const std::string& str) {
            cmd = "MicRecord";
            resultId = 2;
            msg = str;
        }

    private:
        std::string cmd;
        int resultId;
        std::string msg;
    };

    class CMicRecord {
    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CMicRecord, cmd, duration, uploadUrl)

        int do_req(CSocket *pClient) {
            CAudioCfgBusiness bus;
            bus.load();
            std::string imei = bus.business[0].deviceID;
            CUtils utils;
            if (utils.get_process_status("ffmpeg")) {
                CMicRecordResult result;
                result.do_fail("Currently recording");
                json js = result;
                std::string res = js.dump();
                return pClient->Send(res.c_str(), res.length());
            }
            int time = std::atoi(duration.c_str());
            std::string url = uploadUrl;
            std::string strImei = imei;
            utils.async_wait(1, 0, 0, [=] {
                CUtils utils;
                std::string res = utils.record_upload(time, url, strImei);
                LOG(INFO) << "result:" << res;
                if (res.find("true") != std::string::npos) {
                    CMicRecordResult result;
                    result.do_success();
                    json js = result;
                    std::string res = js.dump();
                    pClient->Send(res.c_str(), res.length());
                } else {
                    CMicRecordResult result;
                    result.do_fail("post error");
                    json js = result;
                    std::string res = js.dump();
                    pClient->Send(res.c_str(), res.length());
                }
            });
            return 1;
        }

    private:
        std::string cmd;
        std::string duration;
        std::string uploadUrl;
    };

    class CSThread;


}
