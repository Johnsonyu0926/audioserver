#include <iostream>
#include <fstream>
#include <sstream>
#include <thread>

#include "json.hpp"

using json = nlohmann::json;

class TimedRestart {
public:
    const std::string TIMED_RESTART_FILE_NAME = "/mnt/cfg/timedRestart.json";

    TimedRestart() = default;

    int file_load() {
        std::ifstream i(TIMED_RESTART_FILE_NAME);
        if (!i.is_open()) {
            std::cerr << TIMED_RESTART_FILE_NAME << " file load error!" << std::endl;
            return 0;
        }

        try {
            json js;
            i >> js;
            std::cout << js.dump() << std::endl;
            timeList_ = js.at("rebootTask").get<std::vector<std::string> >();
        } catch (json::parse_error &ex) {
            std::cerr << "parse error at byte " << ex.byte << std::endl;
            i.close();
            return 0;
        }
        i.close();
        return 1;
    }

    void testJson() {
        json js;
        timeList_.emplace_back("01:00");
        js["rebootTask"] = timeList_;
        std::ofstream o(TIMED_RESTART_FILE_NAME);
        o << std::setw(4) << js << std::endl;
        o.close();
    }

    std::string getCurrTime() {
        const std::time_t t = std::time(nullptr);
        const std::tm *lt = localtime(&t);
        std::stringstream ss;
        ss << std::put_time(lt, "%H:%M");
        return ss.str();
    }



    void loop() {
        CUtils::async_wait(1, 0, 0, [&] {
            while (true) {
                std::for_each(timeList_.begin(), timeList_.end(), [&](const std::string &time) {
                    std::cout << time << " " << getCurrTime() << std::endl;
                    if (getCurrTime() == time) {
                        CUtils::reboot();
                    }
                });
                std::this_thread::sleep_for(std::chrono::seconds(30));
            }
        });
    }

private:
    std::vector<std::string> timeList_;
};