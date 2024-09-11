#pragma once

#include "utils.h"
#include "AudioPlayStatus.hpp"

class Relay {
public:
    ~Relay() = default;

    Relay(const Relay &) = delete;

    Relay &operator=(const Relay &) = delete;

    static Relay &getInstance() {
        static Relay instance;
        return instance;
    }

    int saveToJson() {
        json j;
        j["gpioStatus"] = state;
        j["gpioModel"] = gpioModel;
        std::ofstream o(filePath);
        o << std::setw(4) << j << std::endl;
        o.close();
        return 0;
    }

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
        }
        catch (json::parse_error &ex) {
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
