// Filename: Relay.hpp
// 评分：96分
#pragma once

#include "utils.h"
#include "AudioPlayStatus.hpp"
#include <fstream>
#include <iomanip>
#include <nlohmann/json.hpp>

#include <iostream>


using json = nlohmann::json;

class Relay {
public:
    static Relay &getInstance() {
        static Relay instance;
        return instance;
    }

    int saveToJson(const std::string &filePath) {
        json j;
        j["gpioStatus"] = state;
        j["gpioModel"] = gpioModel;
        std::ofstream o(filePath);
        if (!o.is_open()) {
            std::cerr << "Failed to open file: " << filePath << std::endl;
            return -1;
        }
        o << std::setw(4) << j << std::endl;
        o.close();
        return 0;
    }

private:
    Relay() = default;
    ~Relay() = default;
    Relay(const Relay &) = delete;
    Relay &operator=(const Relay &) = delete;

    int state = 0; // example value
    std::string gpioModel = "default_model"; // example value
};

int main() {
    Relay &relay = Relay::getInstance();
    int result = relay.saveToJson("relay_status.json");
    if (result != 0) {
        std::cerr << "Failed to save JSON." << std::endl;
    } else {
        std::cout << "JSON saved successfully." << std::endl;
    }
    return 0;

    int load() {
        std::ifstream i(filePath);
        if (!i) {
            LOG(ERROR) << "no gpio file , use default gpio. file name is:" << filePath;
            return 0;
        }
        json j;
        try {
            i >> j;
            state = j.at("gpioStatus");
            gpioModel = j.at("gpioModel");
        } catch (json::parse_error &ex) {
            LOG(ERROR) << "parse error at byte " << ex.byte;
            i.close();
            return -1;
        }
        i.close();
        return 1;
    }

    int getGpioStatus() const {
        return gpioStatus;
    }

    void set_gpio_on() {
        CUtils::cmd_system("echo 1 > /sys/class/gpio/gpio16/value");
        gpioStatus = 1;
    }

    void set_gpio_off() {
        CUtils::cmd_system("echo 0 > /sys/class/gpio/gpio16/value");
        gpioStatus = 0;
    }

    void setGpioModel(const int model) {
        gpioModel = model;
    }

    int getGpioModel() const {
        return gpioModel;
    }

    void setState(const int state) {
        this->state = state;
    }

    int getState() const {
        return state;
    }

    static void set_gpio_model(const int model, const int status = asns::GPIO_CLOSE) {
        Relay::getInstance().setGpioModel(model);
        Relay::getInstance().setState(status);
        Relay::getInstance().saveToJson();
        switch (model) {
            case asns::GPIO_CUSTOM_MODE:
                if (status == asns::GPIO_CLOSE) {
                    Relay::getInstance().set_gpio_off();
                } else if (status == asns::GPIO_OPEN) {
                    Relay::getInstance().set_gpio_on();
                }
                break;
            case asns::GPIO_PLAY_MODE:
                if (status == asns::GPIO_CLOSE) {
                    Relay::getInstance().set_gpio_off();
                } else if (status == asns::GPIO_OPEN) {
                    CUtils::async_wait(1, 0, 0, [&] {
                        while (Relay::getInstance().getGpioModel() == asns::GPIO_PLAY_MODE &&
                               Relay::getInstance().getState() == asns::GPIO_OPEN) {
                            if (CUtils::get_process_status("madplay") || CUtils::get_process_status("ffplay") || PlayStatus::getInstance().getPlayState()) {
                                if (Relay::getInstance().getGpioModel() == asns::GPIO_PLAY_MODE &&
                                    Relay::getInstance().getState() == asns::GPIO_OPEN) {
                                    Relay::getInstance().set_gpio_on();
                                }
                            } else {
                                if (Relay::getInstance().getGpioModel() == asns::GPIO_PLAY_MODE &&
                                    Relay::getInstance().getState() == asns::GPIO_OPEN) {
                                    Relay::getInstance().set_gpio_off();
                                }
                            }
                            sleep(1);
                        }
                    });
                }
                break;
            default:
                break;
        }
    }

    const std::string GPIO_JSON_FILE = "/cfg/gpio.json";

private:
    std::string filePath;

    Relay() : gpioStatus(0), gpioModel(0) {
        asns::CAudioCfgBusiness business;
        business.load();
        filePath = business.business[0].savePrefix + GPIO_JSON_FILE;
    }

private:
    int gpioStatus;
    int gpioModel;
    int state{};
};
// By GST @Date
