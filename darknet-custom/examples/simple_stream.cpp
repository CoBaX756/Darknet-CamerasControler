#include "darknet.hpp"
#include <opencv2/opencv.hpp>
#include <iostream>
#include <thread>
#include <vector>
#include <string>
#include <netinet/in.h>
#include <unistd.h>
#include <chrono>
#include <cstring>

#define BOUNDARY "frame"

void stream_camera(int port, const std::string& rtsp_url, const std::string& camera_name);

int main(int argc, char* argv[]) {
    if (argc < 4) {
        std::cerr << "Uso: " << argv[0] << " <puerto> <rtsp_url> <nombre_camara>" << std::endl;
        return 1;
    }
    
    int port = std::stoi(argv[1]);
    std::string rtsp_url = argv[2];
    std::string camera_name = argv[3];
    
    stream_camera(port, rtsp_url, camera_name);
    
    return 0;
}

void stream_camera(int port, const std::string& rtsp_url, const std::string& camera_name) {
    try {
        std::cout << "[" << camera_name << "] Iniciando en puerto " << port << std::endl;
        
        // Cargar red neuronal con configuración por defecto
        const char* args[] = {
            "simple_stream",
            "cfg/coco.names",
            "cfg/yolov4-tiny.cfg",
            "yolov4-tiny.weights"
        };
        
        char* mutable_args[4];
        for (int i = 0; i < 4; i++) {
            mutable_args[i] = const_cast<char*>(args[i]);
        }
        
        Darknet::Parms parms = Darknet::parse_arguments(4, mutable_args);
        Darknet::NetworkPtr net = Darknet::load_neural_network(parms);
        std::cout << "[" << camera_name << "] Red neuronal cargada" << std::endl;
        
        // Crear socket servidor
        int server_fd = socket(AF_INET, SOCK_STREAM, 0);
        if (server_fd < 0) {
            throw std::runtime_error("Error creando socket");
        }
        
        int opt = 1;
        setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, sizeof(opt));
        
        sockaddr_in address{};
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = INADDR_ANY;
        address.sin_port = htons(port);
        
        if (bind(server_fd, (struct sockaddr*)&address, sizeof(address)) < 0) {
            close(server_fd);
            throw std::runtime_error("Error en bind puerto " + std::to_string(port));
        }
        
        listen(server_fd, 5);
        std::cout << "[" << camera_name << "] Servidor escuchando en puerto " << port << std::endl;
        
        while (true) {
            int client_sock = accept(server_fd, nullptr, nullptr);
            if (client_sock < 0) continue;
            
            // Leer solicitud HTTP
            char buffer[1024] = {0};
            read(client_sock, buffer, sizeof(buffer));
            
            // Enviar cabecera HTTP
            std::string header = "HTTP/1.0 200 OK\r\n"
                               "Server: YOLO-Stream\r\n"
                               "Connection: close\r\n"
                               "Cache-Control: no-cache\r\n"
                               "Access-Control-Allow-Origin: *\r\n"
                               "Content-Type: multipart/x-mixed-replace; boundary=" BOUNDARY "\r\n\r\n";
            
            send(client_sock, header.c_str(), header.size(), MSG_NOSIGNAL);
            
            // Abrir stream RTSP
            cv::VideoCapture cap(rtsp_url, cv::CAP_FFMPEG);
            if (!cap.isOpened()) {
                std::cerr << "[" << camera_name << "] Error abriendo RTSP" << std::endl;
                close(client_sock);
                continue;
            }
            
            cap.set(cv::CAP_PROP_BUFFERSIZE, 1);
            std::cout << "[" << camera_name << "] Cliente conectado" << std::endl;
            
            // Configurar JPEG
            std::vector<int> jpeg_params = {cv::IMWRITE_JPEG_QUALITY, 80};
            
            cv::Mat frame;
            int frame_count = 0;
            auto last_time = std::chrono::steady_clock::now();
            
            while (cap.read(frame)) {
                if (frame.empty()) continue;
                
                // Redimensionar si es muy grande
                cv::Mat process_frame;
                if (frame.cols > 1280 || frame.rows > 720) {
                    double scale = std::min(1280.0/frame.cols, 720.0/frame.rows);
                    cv::resize(frame, process_frame, cv::Size(), scale, scale);
                } else {
                    process_frame = frame;
                }
                
                // Hacer detección
                try {
                    Darknet::predict_and_annotate(net, process_frame);
                } catch (...) {
                    // Ignorar errores de detección
                }
                
                // Codificar a JPEG
                std::vector<uchar> jpeg_buf;
                if (!cv::imencode(".jpg", process_frame, jpeg_buf, jpeg_params)) continue;
                
                // Enviar frame
                std::string frame_header = "--" BOUNDARY "\r\n"
                                         "Content-Type: image/jpeg\r\n"
                                         "Content-Length: " + std::to_string(jpeg_buf.size()) + "\r\n\r\n";
                
                if (send(client_sock, frame_header.c_str(), frame_header.size(), MSG_NOSIGNAL) < 0) break;
                if (send(client_sock, jpeg_buf.data(), jpeg_buf.size(), MSG_NOSIGNAL) < 0) break;
                if (send(client_sock, "\r\n", 2, MSG_NOSIGNAL) < 0) break;
                
                frame_count++;
                
                // Mostrar FPS
                auto now = std::chrono::steady_clock::now();
                if (std::chrono::duration_cast<std::chrono::seconds>(now - last_time).count() >= 1) {
                    std::cout << "[" << camera_name << "] FPS: " << frame_count << std::endl;
                    frame_count = 0;
                    last_time = now;
                }
                
                std::this_thread::sleep_for(std::chrono::milliseconds(30));
            }
            
            cap.release();
            close(client_sock);
            std::cout << "[" << camera_name << "] Cliente desconectado" << std::endl;
        }
        
        Darknet::free_neural_network(net);
        close(server_fd);
    }
    catch (const std::exception& e) {
        std::cerr << "[" << camera_name << "] Error: " << e.what() << std::endl;
    }
}