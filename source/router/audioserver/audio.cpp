// audio.cpp
#include <iostream>
#include <string>
#include <vector>
#include <thread>
#include <chrono>
#include "audio.hpp"
#include "AudioPlayUtils.hpp"
#include "MqttConfig.hpp"
#include "CustomAudio.hpp"
#include "spdlog/spdlog.h"
#include "spdlog/sinks/rotating_file_sink.h"
#include "spdlog/sinks/stdout_color_sinks.h"

Audio::Audio() : volume(50) {}

void Audio::play(const std::string& file) {
    std::cout << "Playing audio file: " << file << std::endl;
}

void Audio::stop() {
    std::cout << "Stopping audio playback" << std::endl;
}

int Audio::getVolume() const {
    return volume;
}

void Audio::setVolume(int vol) {
    volume = vol;
}

class AudioServer {
public:
    AudioServer() = default;
    ~AudioServer() {
        stop();
    }

    void start() {
        loadConfig();
        loadCustomAudioFiles();
        // Additional initialization can be placed here

        running = true;
        server_thread = std::thread(&AudioServer::run, this);
        spdlog::info("AudioServer started");
    }

    void stop() {
        running = false;
        if (server_thread.joinable()) {
            server_thread.join();
        }
        spdlog::info("AudioServer stopped");
    }

private:
    void loadConfig() {
        MqttConfig config;
        if (!config.load_file()) {
            spdlog::error("Failed to load MQTT config");
        } else {
            request_topic = config.get_request_topic();
            publish_topic = config.get_publish_topic();
            spdlog::info("MQTT config loaded. Request topic: {}, Publish topic: {}", 
                         request_topic, publish_topic);
        }
    }

    void loadCustomAudioFiles() {
        if (customAudioManager.loadFromFile("add_column_custom_audio_file.json")) {
            spdlog::info("Custom audio files loaded successfully");
        } else {
            spdlog::error("Failed to load custom audio files");
        }
    }

    void run() {
        while (running) {
            // Main server loop
            spdlog::debug("Server running...");
            std::this_thread::sleep_for(std::chrono::seconds(1));
        }
    }

    // 处理自定义音频播放请求的方法
    void handleCustomAudioPlayRequest(const std::string& fileName) {
        const CustomAudio* audio = customAudioManager.findAudioByName(fileName);
        if (audio) {
            spdlog::info("Playing custom audio: {} (Type: {}, Size: {} bytes)", 
                         audio->fileName, audio->type, audio->size);
            // 这里添加实际的音频播放逻辑
        } else {
            spdlog::warn("Custom audio file '{}' not found", fileName);
        }
    }

    std::string request_topic;
    std::string publish_topic;
    std::thread server_thread;
    bool running = false;
    CustomAudioManager customAudioManager;
};

void initializeLogging() {
    auto console_sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
    auto file_sink = std::make_shared<spdlog::sinks::rotating_file_sink_mt>("logs/audioserver.log", 1024 * 1024 * 10, 3);

    spdlog::sinks_init_list sink_list = {file_sink, console_sink};
    auto logger = std::make_shared<spdlog::logger>("multi_sink", sink_list.begin(), sink_list.end());
    
    spdlog::set_default_logger(logger);
    spdlog::set_level(spdlog::level::debug); // Set global log level to debug
    spdlog::flush_on(spdlog::level::debug); // Flush log on every debug statement
}

int main() {
    initializeLogging();
    spdlog::info("Application started");

    AudioServer server;
    server.start();

    spdlog::info("Server will run for 10 seconds");
    std::this_thread::sleep_for(std::chrono::seconds(10));  // Run for 10 seconds

    server.stop();
    spdlog::info("Application finished");
    return 0;
}

// By GST ARMV8 GCC13.2 audio.cpp
