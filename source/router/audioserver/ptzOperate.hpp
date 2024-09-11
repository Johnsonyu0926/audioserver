#pragma once

#include "json.hpp"
#include "utils.h"
#include "Rs485.hpp"

namespace asns {
    class CPtzOperateResult {
    private:
        std::string cmd;
        int resultId;
        std::string msg;

    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CPtzOperateResult, cmd, resultId, msg)

        void do_fail(const std::string& str) {
            cmd = "PtzOperate";
            resultId = 2;
            msg = str;
        }

        void do_success() {
            cmd = "PtzOperate";
            resultId = 1;
            msg = "PtzOperate success";
        };
    };

    class CPtzOperate {
    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CPtzOperate, cmd, operateCmd)

        int do_req(CSocket *pClient) {
            CUtils utils;
            CPtzOperateResult res;
            res.do_success();
            if(operateCmd.empty()){
                res.do_fail("operateCmd is empty");
            } else {
                std::string str = utils.hex_to_string(operateCmd);
                if(Rs485::_uart_work(str.c_str(),str.length() != 1)){
                    res.do_fail("operateCmd write fail");
                }
            }
            json j = res;
            std::string s = j.dump();
            pClient->Send(s.c_str(), s.length());
            return 1;
        }

    private:
        std::string cmd;
        std::string operateCmd;
    };
}
