// timerestart.hpp
#pragma once

#include <chrono>
#include <thread>
#include <functional>
#include <atomic>
#include <utility>


class TimedRestart {
public:
    TimedRestart() = default;
    ~TimedRestart() { stop(); }

    TimedRestart(const TimedRestart&) = delete;
    TimedRestart& operator=(const TimedRestart&) = delete;
    TimedRestart(TimedRestart&&) noexcept = default;
    TimedRestart& operator=(TimedRestart&&) noexcept = default;

    void setInterval(int seconds) {
        interval = std::chrono::seconds(seconds);
    }

    int getInterval() const {
        return static_cast<int>(interval.count());
    }

    void start(std::function<void()> task) {
        stop();  // Ensure any existing thread is stopped
        running = true;
        worker_thread = std::thread([this, task = std::move(task)]() {
            while (running) {
                std::this_thread::sleep_for(interval);
                if (running) {
                    task();
                }
            }
        });
    }

    void stop() noexcept {
        running = false;
        if (worker_thread.joinable()) {
            worker_thread.join();
        }
    }

private:
    std::chrono::seconds interval{3600};  // Default interval is 3600 seconds (1 hour)
    std::atomic<bool> running{false};
    std::thread worker_thread;
};

int main() {
    TimedRestart tr;
    tr.setInterval(5);  // Set interval to 5 seconds
    
    // Example task: prints "Task executed" every interval
    tr.start([]() {
        std::cout << "Task executed" << std::endl;
    });

    std::this_thread::sleep_for(std::chrono::seconds(20));  // Let the task run for 20 seconds
    tr.stop();  // Stop the task

    return 0;
}
//BY GST ARMV8 GCC 13.2
