// clientthread.hpp
#pragma once

#include <nlohmann/json.hpp>
#include <vector>
#include <string>
#include <memory>

// 声明前置声明，以减少头文件依赖
class CSThread;
class CSocket;

// 客户端线程类
class ClientThread {
public:
    ClientThread();
    void start();
    void stop();
    bool getIsRunning() const;
    void run();

private:
    bool isRunning;
};

// 客户端线程派生类，继承自 CSThread
class CClientThread : public CSThread {
public:
    CClientThread() = default;
    ~CClientThread() override = default;

    // 禁用拷贝和移动操作
    CClientThread(const CClientThread&) = delete;
    CClientThread& operator=(const CClientThread&) = delete;
    CClientThread(CClientThread&&) = delete;
    CClientThread& operator=(CClientThread&&) = delete;

    // 重写虚函数
    [[nodiscard]] bool InitInstance() override;
    [[nodiscard]] bool ExitInstance() override;

    // 设置客户端
    void SetClient(std::shared_ptr<CSocket> pClient) { m_pClient = std::move(pClient); }

    // 处理请求
    [[nodiscard]] int do_req(std::string_view buf, std::shared_ptr<CSocket> pClient);
    [[nodiscard]] int do_verify(std::string_view buf) const;
    [[nodiscard]] int do_str_req();
    [[nodiscard]] int do_str_verify(std::string_view buf, std::shared_ptr<CSocket> pClient) const;

private:
    // 检查和生成数据
    [[nodiscard]] bool Check(const unsigned char* szBuf) const;
    [[nodiscard]] bool Gen(unsigned char* szBuf) const; // ensure the buffer size is 1024 Bytes

    std::shared_ptr<CSocket> m_pClient;
    nlohmann::json m_json;
    std::vector<std::string> m_str;
};

// By GST ARMV8 GCC13.2 clientthread.hpp
