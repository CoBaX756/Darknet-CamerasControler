# Multi-Camera Detection System with YOLO

[🇪🇸 Versión en Español](README.md)

Complete real-time object detection system with support for multiple RTSP cameras using YOLOv4-tiny and Darknet.

## Features

- 🎯 Real-time object detection with YOLOv4-tiny
- 📹 Dynamic management of multiple RTSP cameras
- 🔌 REST API for camera control
- 🖥️ Web interface for stream visualization
- 📝 Detailed logging system
- ⚙️ Flexible configuration via JSON files

## Project Structure

```
Deteccion/
├── src/                    # Source code
│   ├── server/            # Node.js API server
│   │   └── api_server.js
│   └── frontend/          # Web interface
│       ├── panel.html
│       └── stream_viewer.html
├── config/                # Configuration files
│   ├── cameras_config.json
│   ├── models_config.json
│   └── detection_config.json
├── darknet/               # YOLO framework (not included)
├── models/                # Detection models
├── logs/                  # Log files
├── scripts/               # Utility scripts
└── docs/                  # Full documentation
    └── README.md
```

## System Requirements

- Ubuntu 20.04+ / Debian 10+ / macOS 11+ / Windows 10+
- Node.js 14.0 or higher
- Python 3.8 or higher
- CMake 3.18 or higher
- GCC/G++ 9.0 or higher (Linux/Mac) or Visual Studio 2019+ (Windows)
- OpenCV 4.0+ (optional, for visualization)
- CUDA 11.0+ (optional, for NVIDIA GPU acceleration)

## Quick Installation

### Option 1: Automatic Script (Recommended)

```bash
# Clone the repository
git clone https://github.com/CoBaX756/Darknet-CamerasControler.git
cd Darknet-CamerasControler

# Run installation script
chmod +x install.sh
./install.sh
```

### Option 2: Manual Installation

1. **Install system dependencies:**
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install -y build-essential cmake git pkg-config
   sudo apt-get install -y libopencv-dev python3-opencv
   sudo apt-get install -y nodejs npm
   
   # macOS
   brew install cmake opencv node
   ```

2. **Install Node.js dependencies:**
   ```bash
   npm install
   ```

3. **Install Python dependencies:**
   ```bash
   pip3 install -r requirements.txt
   ```

4. **Compile Darknet:**
   ```bash
   cd darknet
   mkdir build && cd build
   cmake ..
   make -j$(nproc)
   cd ../..
   ```

5. **Download YOLOv4-tiny model (if not included):**
   ```bash
   # The yolov4-tiny.weights file is already included
   # If you need to download it again:
   # wget https://github.com/AlexeyAB/darknet/releases/download/darknet_yolo_v4_pre/yolov4-tiny.weights -O darknet/yolov4-tiny.weights
   ```

## Usage

### Start the system

```bash
# Start API server
node src/server/api_server.js

# Or use the startup script
./scripts/start.sh
```

### Access the web interface

Open in browser:
- Control panel: `http://localhost:3000/src/frontend/panel.html` or `http://localhost:3000`
- Stream viewer: `http://localhost:3000/src/frontend/stream_viewer.html`

### Stop the system

```bash
./scripts/stop.sh
```

## Configuration

### Configure RTSP cameras

Edit `config/cameras_config.json`:

```json
{
  "cameras": [
    {
      "id": "camera_1",
      "name": "Main Camera",
      "rtsp_url": "rtsp://user:password@192.168.1.100:554/stream",
      "enabled": true
    }
  ]
}
```

### Adjust detection parameters

Edit `config/detection_config.json`:

```json
{
  "confidence_threshold": 0.5,
  "nms_threshold": 0.4,
  "input_width": 416,
  "input_height": 416
}
```

## REST API

### Main endpoints

- `GET /api/cameras` - List all cameras
- `POST /api/cameras/start/:id` - Start detection on camera
- `POST /api/cameras/stop/:id` - Stop detection on camera
- `GET /api/detections/:id` - Get detections from a camera

See [docs/API_EXAMPLES.md](docs/API_EXAMPLES.md) for more details.

## Troubleshooting

### Error: "darknet: command not found"

```bash
cd darknet
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
cd ../..
```

### Error: "Cannot find module 'express'"

```bash
npm install
```

### OpenCV error in Python

```bash
# Ubuntu/Debian
sudo apt-get install python3-opencv

# Or with pip
pip3 install opencv-python
```

## Full Documentation

See [docs/README.md](docs/README.md) for detailed information about:
- Advanced configuration
- Model customization
- Integration with other systems
- Performance optimization

## Contributing

Contributions are welcome! Please:

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Important note:** This project uses Darknet (Hank.ai fork) which is licensed under Apache License 2.0. The `darknet/` directory is not included in this repository and must be downloaded separately. See [SETUP_DARKNET.md](SETUP_DARKNET.md) for more information.

## Support

If you encounter any issues or have questions:
- Open an issue on GitHub
- Check the [full documentation](docs/README.md)
- Review the [API examples](docs/API_EXAMPLES.md)