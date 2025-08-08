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
#include <fstream>
#include <map>
#include <atomic>
#include <mutex>
#include <netinet/tcp.h>
#include <sstream>
#include <errno.h>

#define BOUNDARY "frame"

// Parámetros del modelo (valores por defecto)
std::string MODEL_CONFIG = "cfg/yolov4-tiny.cfg";
std::string MODEL_WEIGHTS = "yolov4-tiny.weights";
std::string MODEL_NAMES = "cfg/coco.names";

struct DetectionConfig {
    std::map<int, bool> enabled;
    
    bool isEnabled(int classId) const {
        auto it = enabled.find(classId);
        return it == enabled.end() || it->second;
    }
};

// Estructura para configuración avanzada de cámara
struct CameraSettings {
    std::string quality = "medium";
    std::string resolution = "720p";
    int jpegQuality = 75;
    bool detectionEnabled = true;
    bool showBoundingBoxes = true;
    bool showLabels = true;
    bool showConfidence = true;
    double minConfidence = 0.5;
    
    // Obtener resolución en píxeles
    void getResolution(int& width, int& height) const {
        if (resolution == "480p") {
            width = 854; height = 480;
        } else if (resolution == "720p") {
            width = 1280; height = 720;
        } else if (resolution == "1080p") {
            width = 1920; height = 1080;
        } else { // original
            width = 0; height = 0; // No redimensionar
        }
    }
    
    // Obtener límite máximo de resolución para evitar problemas de rendimiento
    void getMaxResolution(int& maxWidth, int& maxHeight) const {
        if (quality == "ultra") {
            maxWidth = 2560; maxHeight = 1440; // Límite en 1440p para ultra
        } else if (quality == "high") {
            maxWidth = 1920; maxHeight = 1080; // Límite en 1080p para high
        } else {
            maxWidth = 1280; maxHeight = 720; // Límite en 720p para medium/low
        }
    }
};

// Estado global para la detección
struct DetectionState {
    std::atomic<bool> network_loaded{false};
    std::atomic<bool> detection_enabled{false};
    Darknet::NetworkPtr net;
    std::vector<std::string> class_names;
    std::mutex mutex;
    std::chrono::steady_clock::time_point start_time;
};

DetectionConfig loadDetectionConfig(const std::string& configFile);
CameraSettings loadCameraSettings(int cameraId);
void load_network_thread(DetectionState& state, const std::string& camera_name, const CameraSettings& settings);
void stream_camera(int port, const std::string& rtsp_url, const std::string& camera_name, const DetectionConfig& config, const CameraSettings& settings);

int main(int argc, char* argv[]) {
    if (argc < 4) {
        std::cerr << "Uso: " << argv[0] << " <puerto> <rtsp_url> <nombre_camara> [config_file] [model_cfg] [model_weights] [model_names]" << std::endl;
        return 1;
    }
    
    int port = std::stoi(argv[1]);
    std::string rtsp_url = argv[2];
    std::string camera_name = argv[3];
    
    // Extraer ID de cámara del nombre del archivo de configuración
    int cameraId = 1; // Por defecto
    if (argc >= 5) {
        std::string configPath = argv[4];
        size_t pos = configPath.find("camera_");
        if (pos != std::string::npos) {
            pos += 7; // Longitud de "camera_"
            size_t end = configPath.find("_", pos);
            if (end != std::string::npos) {
                cameraId = std::stoi(configPath.substr(pos, end - pos));
            }
        }
    }
    
    DetectionConfig config;
    if (argc >= 5) {
        config = loadDetectionConfig(argv[4]);
    }
    
    // Cargar configuración avanzada
    CameraSettings settings = loadCameraSettings(cameraId);
    
    // Cargar parámetros del modelo si se proporcionan
    if (argc >= 6) {
        MODEL_CONFIG = argv[5];
    }
    if (argc >= 7) {
        MODEL_WEIGHTS = argv[6];
    }
    if (argc >= 8) {
        MODEL_NAMES = argv[7];
    }
    
    std::cout << "Usando modelo: " << MODEL_CONFIG << std::endl;
    std::cout << "Pesos: " << MODEL_WEIGHTS << std::endl;
    std::cout << "Nombres: " << MODEL_NAMES << std::endl;
    
    stream_camera(port, rtsp_url, camera_name, config, settings);
    
    return 0;
}

DetectionConfig loadDetectionConfig(const std::string& configFile) {
    DetectionConfig config;
    
    try {
        std::ifstream file(configFile);
        if (!file.is_open()) {
            std::cerr << "No se pudo abrir archivo de configuración: " << configFile << std::endl;
            return config;
        }
        
        std::string json_str((std::istreambuf_iterator<char>(file)),
                            std::istreambuf_iterator<char>());
        
        // Simple JSON parsing
        size_t pos = 0;
        
        // Primero buscar "enabledClasses" (formato nuevo como array)
        pos = json_str.find("\"enabledClasses\"");
        if (pos != std::string::npos) {
            pos = json_str.find("[", pos);
            if (pos != std::string::npos) {
                size_t end = json_str.find("]", pos);
                std::string enabled_array = json_str.substr(pos + 1, end - pos - 1);
                
                // Parse array values
                int idx = 0;
                size_t value_pos = 0;
                while (value_pos < enabled_array.length()) {
                    // Skip whitespace
                    while (value_pos < enabled_array.length() && 
                           (enabled_array[value_pos] == ' ' || 
                            enabled_array[value_pos] == '\n' || 
                            enabled_array[value_pos] == '\t')) {
                        value_pos++;
                    }
                    
                    if (value_pos >= enabled_array.length()) break;
                    
                    // Check for true/false
                    if (enabled_array.substr(value_pos, 4) == "true") {
                        config.enabled[idx] = true;
                        value_pos += 4;
                    } else if (enabled_array.substr(value_pos, 5) == "false") {
                        config.enabled[idx] = false;
                        value_pos += 5;
                    }
                    
                    // Skip to next value (after comma)
                    size_t comma_pos = enabled_array.find(",", value_pos);
                    if (comma_pos != std::string::npos) {
                        value_pos = comma_pos + 1;
                        idx++;
                    } else {
                        break;
                    }
                }
            }
        } else {
            // Buscar sección "enabled" (formato antiguo como objeto)
            pos = json_str.find("\"enabled\"");
            if (pos != std::string::npos) {
                pos = json_str.find("{", pos);
                if (pos != std::string::npos) {
                    size_t end = json_str.find("}", pos);
                    std::string enabled_section = json_str.substr(pos + 1, end - pos - 1);
                    
                    size_t idx_pos = 0;
                    while ((idx_pos = enabled_section.find("\"", idx_pos)) != std::string::npos) {
                        size_t idx_end = enabled_section.find("\"", idx_pos + 1);
                        if (idx_end != std::string::npos) {
                            std::string idx_str = enabled_section.substr(idx_pos + 1, idx_end - idx_pos - 1);
                            int idx = std::stoi(idx_str);
                            
                            size_t bool_pos = enabled_section.find(":", idx_end);
                            if (bool_pos != std::string::npos) {
                                bool value = enabled_section.find("true", bool_pos) != std::string::npos;
                                config.enabled[idx] = value;
                            }
                        }
                        idx_pos = idx_end + 1;
                    }
                }
            }
        }
        
    } catch (const std::exception& e) {
        std::cerr << "Error cargando configuración de detección: " << e.what() << std::endl;
    }
    
    return config;
}

CameraSettings loadCameraSettings(int cameraId) {
    CameraSettings settings;
    
    try {
        std::string settingsFile = "/home/xabi/Documentos/Deteccion/logs/camera_" + std::to_string(cameraId) + "_settings.json";
        std::ifstream file(settingsFile);
        
        if (!file.is_open()) {
            std::cout << "Usando configuración por defecto (no se encontró " << settingsFile << ")" << std::endl;
            return settings;
        }
        
        std::string json_str((std::istreambuf_iterator<char>(file)),
                            std::istreambuf_iterator<char>());
        
        // Parser JSON simple
        auto findValue = [&json_str](const std::string& key) -> std::string {
            size_t pos = json_str.find("\"" + key + "\"");
            if (pos == std::string::npos) return "";
            
            pos = json_str.find(":", pos);
            if (pos == std::string::npos) return "";
            pos++;
            
            // Saltar espacios
            while (pos < json_str.length() && (json_str[pos] == ' ' || json_str[pos] == '\t')) pos++;
            
            if (json_str[pos] == '"') {
                // String value
                pos++;
                size_t end = json_str.find("\"", pos);
                if (end != std::string::npos) {
                    return json_str.substr(pos, end - pos);
                }
            } else {
                // Number or boolean
                size_t end = json_str.find_first_of(",}", pos);
                if (end != std::string::npos) {
                    std::string value = json_str.substr(pos, end - pos);
                    // Eliminar espacios
                    value.erase(value.find_last_not_of(" \n\r\t") + 1);
                    return value;
                }
            }
            return "";
        };
        
        std::string quality = findValue("quality");
        if (!quality.empty()) settings.quality = quality;
        
        std::string resolution = findValue("resolution");
        if (!resolution.empty()) settings.resolution = resolution;
        
        std::string jpegQuality = findValue("jpegQuality");
        if (!jpegQuality.empty()) settings.jpegQuality = std::stoi(jpegQuality);
        
        std::string detectionEnabled = findValue("detectionEnabled");
        if (!detectionEnabled.empty()) settings.detectionEnabled = (detectionEnabled == "true");
        
        std::string showBoundingBoxes = findValue("showBoundingBoxes");
        if (!showBoundingBoxes.empty()) settings.showBoundingBoxes = (showBoundingBoxes == "true");
        
        std::string showLabels = findValue("showLabels");
        if (!showLabels.empty()) settings.showLabels = (showLabels == "true");
        
        std::string showConfidence = findValue("showConfidence");
        if (!showConfidence.empty()) settings.showConfidence = (showConfidence == "true");
        
        std::string minConfidence = findValue("minConfidence");
        if (!minConfidence.empty()) settings.minConfidence = std::stod(minConfidence);
        
        std::cout << "Configuración cargada:" << std::endl;
        std::cout << "  - Calidad: " << settings.quality << std::endl;
        std::cout << "  - Resolución: " << settings.resolution << std::endl;
        std::cout << "  - JPEG: " << settings.jpegQuality << "%" << std::endl;
        std::cout << "  - Detección: " << (settings.detectionEnabled ? "Activada" : "Desactivada") << std::endl;
        if (settings.detectionEnabled) {
            std::cout << "  - Mostrar cajas: " << (settings.showBoundingBoxes ? "Sí" : "No") << std::endl;
            std::cout << "  - Mostrar etiquetas: " << (settings.showLabels ? "Sí" : "No") << std::endl;
            std::cout << "  - Mostrar confianza: " << (settings.showConfidence ? "Sí" : "No") << std::endl;
            std::cout << "  - Confianza mínima: " << (settings.minConfidence * 100) << "%" << std::endl;
        }
        
    } catch (const std::exception& e) {
        std::cerr << "Error cargando configuración avanzada: " << e.what() << std::endl;
    }
    
    return settings;
}

void load_network_thread(DetectionState& state, const std::string& camera_name, const CameraSettings& settings) {
    std::cout << "[" << camera_name << "] Iniciando carga de red neuronal en segundo plano..." << std::endl;
    
    try {
        // Cargar red neuronal con los parámetros del modelo
        const char* args[] = {
            "simple_stream",
            MODEL_NAMES.c_str(),
            MODEL_CONFIG.c_str(),
            MODEL_WEIGHTS.c_str()
        };
        
        char* mutable_args[4];
        for (int i = 0; i < 4; i++) {
            mutable_args[i] = const_cast<char*>(args[i]);
        }
        
        Darknet::Parms parms = Darknet::parse_arguments(4, mutable_args);
        Darknet::NetworkPtr net = Darknet::load_neural_network(parms);
        
        // Cargar nombres de clases
        std::vector<std::string> class_names;
        std::ifstream names_file(MODEL_NAMES);
        std::string line;
        while (std::getline(names_file, line)) {
            if (!line.empty()) {
                class_names.push_back(line);
            }
        }
        
        // Actualizar estado
        {
            std::lock_guard<std::mutex> lock(state.mutex);
            state.net = net;
            state.class_names = class_names;
            state.network_loaded = true;
        }
        
        auto load_time = std::chrono::steady_clock::now() - state.start_time;
        auto seconds = std::chrono::duration_cast<std::chrono::seconds>(load_time).count();
        std::cout << "[" << camera_name << "] Red neuronal cargada en " << seconds << " segundos" << std::endl;
        
        // Solo activar detección si está habilitada en la configuración
        if (settings.detectionEnabled) {
            // Esperar 2 segundos adicionales antes de activar detección
            std::this_thread::sleep_for(std::chrono::seconds(2));
            state.detection_enabled = true;
            std::cout << "[" << camera_name << "] Detección activada" << std::endl;
        } else {
            std::cout << "[" << camera_name << "] Detección deshabilitada por configuración" << std::endl;
        }
        
    } catch (const std::exception& e) {
        std::cerr << "[" << camera_name << "] Error cargando red neuronal: " << e.what() << std::endl;
    }
}

void stream_camera(int port, const std::string& rtsp_url, const std::string& camera_name, const DetectionConfig& config, const CameraSettings& settings) {
    try {
        std::cout << "[" << camera_name << "] Iniciando en puerto " << port << std::endl;
        
        // Estado de detección
        DetectionState detection_state;
        detection_state.start_time = std::chrono::steady_clock::now();
        
        // Iniciar carga de red neuronal en thread separado (solo si detección está habilitada)
        if (settings.detectionEnabled) {
            std::thread network_loader(load_network_thread, std::ref(detection_state), camera_name, settings);
            network_loader.detach();
        }
        
        // Crear socket servidor
        int server_fd = socket(AF_INET, SOCK_STREAM, 0);
        if (server_fd < 0) {
            throw std::runtime_error("Error creando socket");
        }
        
        int opt = 1;
        setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, sizeof(opt));
        
        // Configurar TCP_NODELAY para menor latencia
        setsockopt(server_fd, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));
        
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
            
            // Configurar TCP_NODELAY en el socket del cliente tambi\u00e9n
            int nodelay = 1;
            setsockopt(client_sock, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
            
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
            
            // Abrir stream RTSP inmediatamente
            cv::VideoCapture cap;
            
            // Configurar para conexión rápida
            cap.set(cv::CAP_PROP_FOURCC, cv::VideoWriter::fourcc('H', '2', '6', '4'));
            cap.set(cv::CAP_PROP_BUFFERSIZE, 1);
            
            std::cout << "[" << camera_name << "] Conectando a RTSP (sin esperar detección)..." << std::endl;
            cap.open(rtsp_url, cv::CAP_FFMPEG);
            
            if (!cap.isOpened()) {
                std::cerr << "[" << camera_name << "] Error abriendo RTSP" << std::endl;
                
                std::string error_msg = "HTTP/1.0 503 Service Unavailable\r\n"
                                      "Content-Type: text/plain\r\n\r\n"
                                      "Error: No se pudo conectar a la cámara\r\n";
                send(client_sock, error_msg.c_str(), error_msg.size(), MSG_NOSIGNAL);
                
                close(client_sock);
                continue;
            }
            
            // Configurar resolución según settings
            int target_width, target_height;
            settings.getResolution(target_width, target_height);
            
            if (target_width > 0 && target_height > 0) {
                cap.set(cv::CAP_PROP_FRAME_WIDTH, target_width);
                cap.set(cv::CAP_PROP_FRAME_HEIGHT, target_height);
            }
            
            cap.set(cv::CAP_PROP_BUFFERSIZE, 0);  // Sin buffer para menor latencia
            cap.set(cv::CAP_PROP_FPS, 30);
            
            // Obtener resolución real
            int actual_width = cap.get(cv::CAP_PROP_FRAME_WIDTH);
            int actual_height = cap.get(cv::CAP_PROP_FRAME_HEIGHT);
            std::cout << "[" << camera_name << "] Resolución: " << actual_width << "x" << actual_height << std::endl;
            std::cout << "[" << camera_name << "] Cliente conectado - Stream iniciado" << std::endl;
            
            // Configurar JPEG con calidad según settings
            std::vector<int> jpeg_params = {cv::IMWRITE_JPEG_QUALITY, settings.jpegQuality};
            
            // Buffer para controlar el envío
            const int BUFFER_SIZE = 256 * 1024; // 256KB buffer
            
            cv::Mat frame;
            int frame_count = 0;
            auto last_time = std::chrono::steady_clock::now();
            bool detection_active = false;
            
            while (cap.read(frame)) {
                if (frame.empty()) continue;
                
                // Redimensionar según configuración de resolución
                cv::Mat process_frame;
                int target_width, target_height;
                settings.getResolution(target_width, target_height);
                
                // Aplicar límite máximo para evitar congelamiento
                int maxWidth, maxHeight;
                settings.getMaxResolution(maxWidth, maxHeight);
                
                bool needsResize = false;
                double scale = 1.0;
                
                // Si hay resolución objetivo específica
                if (target_width > 0 && target_height > 0) {
                    scale = std::min((double)target_width/frame.cols, (double)target_height/frame.rows);
                    needsResize = true;
                }
                // Si excede el límite máximo
                else if (frame.cols > maxWidth || frame.rows > maxHeight) {
                    scale = std::min((double)maxWidth/frame.cols, (double)maxHeight/frame.rows);
                    needsResize = true;
                }
                
                if (needsResize && scale < 1.0) {
                    cv::resize(frame, process_frame, cv::Size(), scale, scale);
                } else {
                    process_frame = frame;
                }
                
                // Crear versión reducida para detección (más rápida)
                cv::Mat detection_frame;
                double scale_factor = 1.0;
                if (detection_state.detection_enabled && detection_active && process_frame.cols > 640) {
                    double scale = 640.0 / process_frame.cols;
                    cv::resize(process_frame, detection_frame, cv::Size(), scale, scale);
                    scale_factor = (double)process_frame.cols / detection_frame.cols;
                } else {
                    detection_frame = process_frame;
                }
                
                // Mostrar estado de detección solo si está habilitada
                if (settings.detectionEnabled) {
                    if (!detection_state.network_loaded) {
                        cv::putText(process_frame, "Cargando deteccion...", 
                            cv::Point(10, 30), cv::FONT_HERSHEY_SIMPLEX, 
                            0.7, cv::Scalar(0, 255, 255), 2);
                    } else if (!detection_state.detection_enabled) {
                        cv::putText(process_frame, "Iniciando deteccion...", 
                            cv::Point(10, 30), cv::FONT_HERSHEY_SIMPLEX, 
                            0.7, cv::Scalar(0, 255, 0), 2);
                    } else if (!detection_active) {
                        detection_active = true;
                        std::cout << "[" << camera_name << "] Detección activa en stream" << std::endl;
                    }
                }
                
                // Hacer detección solo si está lista y habilitada
                if (settings.detectionEnabled && detection_state.detection_enabled && detection_active) {
                    try {
                        std::lock_guard<std::mutex> lock(detection_state.mutex);
                        if (detection_state.net) {
                            Darknet::Predictions predictions = Darknet::predict(detection_state.net, detection_frame);
                            
                            for (const auto& pred : predictions) {
                                if (pred.best_class >= 0 && pred.best_class < detection_state.class_names.size()) {
                                    if (!config.isEnabled(pred.best_class)) {
                                        continue;
                                    }
                                    
                                    float confidence = pred.prob.at(pred.best_class);
                                    
                                    // Verificar confianza mínima
                                    if (confidence < settings.minConfidence) {
                                        continue;
                                    }
                                    
                                    std::string class_name = detection_state.class_names[pred.best_class];
                                    
                                    // Escalar rectángulo al tamaño del frame original
                                    cv::Rect scaled_rect(
                                        pred.rect.x * scale_factor,
                                        pred.rect.y * scale_factor,
                                        pred.rect.width * scale_factor,
                                        pred.rect.height * scale_factor
                                    );
                                    
                                    // Dibujar caja si está habilitado
                                    if (settings.showBoundingBoxes) {
                                        cv::rectangle(process_frame, scaled_rect, cv::Scalar(0, 255, 0), 2);
                                    }
                                    
                                    // Preparar etiqueta
                                    if (settings.showLabels || settings.showConfidence) {
                                        std::string label;
                                        if (settings.showLabels) {
                                            label = class_name;
                                        }
                                        if (settings.showConfidence) {
                                            if (settings.showLabels) label += " ";
                                            label += std::to_string(int(confidence * 100)) + "%";
                                        }
                                        
                                        if (!label.empty()) {
                                            int baseline;
                                            cv::Size label_size = cv::getTextSize(label, cv::FONT_HERSHEY_SIMPLEX, 0.5, 1, &baseline);
                                            
                                            cv::rectangle(process_frame, 
                                                cv::Point(scaled_rect.x, scaled_rect.y - label_size.height - 10),
                                                cv::Point(scaled_rect.x + label_size.width, scaled_rect.y),
                                                cv::Scalar(0, 255, 0), cv::FILLED);
                                            
                                            cv::putText(process_frame, label,
                                                cv::Point(scaled_rect.x, scaled_rect.y - 5),
                                                cv::FONT_HERSHEY_SIMPLEX, 0.5, cv::Scalar(0, 0, 0), 1);
                                        }
                                    }
                                }
                            }
                        }
                    } catch (const std::exception& e) {
                        // Ignorar errores de detección
                    }
                }
                
                // Codificar a JPEG
                std::vector<uchar> jpeg_buf;
                if (!cv::imencode(".jpg", process_frame, jpeg_buf, jpeg_params)) continue;
                
                // Enviar frame con control de flujo
                std::string frame_header = "--" BOUNDARY "\r\n"
                                         "Content-Type: image/jpeg\r\n"
                                         "Content-Length: " + std::to_string(jpeg_buf.size()) + "\r\n\r\n";
                
                if (send(client_sock, frame_header.c_str(), frame_header.size(), MSG_NOSIGNAL) < 0) break;
                
                // Enviar datos de una vez para mínima latencia
                if (send(client_sock, jpeg_buf.data(), jpeg_buf.size(), MSG_NOSIGNAL) < 0) break;
                
                if (send(client_sock, "\r\n", 2, MSG_NOSIGNAL) < 0) break;
                
                frame_count++;
                
                // Mostrar FPS
                auto now = std::chrono::steady_clock::now();
                if (std::chrono::duration_cast<std::chrono::seconds>(now - last_time).count() >= 1) {
                    std::cout << "[" << camera_name << "] FPS: " << frame_count 
                             << (detection_active ? " (con detección)" : " (sin detección)") << std::endl;
                    frame_count = 0;
                    last_time = now;
                }
            }
            
            cap.release();
            close(client_sock);
            std::cout << "[" << camera_name << "] Cliente desconectado" << std::endl;
        }
        
        close(server_fd);
    }
    catch (const std::exception& e) {
        std::cerr << "[" << camera_name << "] Error: " << e.what() << std::endl;
    }
}