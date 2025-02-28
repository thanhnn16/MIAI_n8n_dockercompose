#!/bin/bash
# Script cài đặt và thiết lập n8n với Docker và Nginx

# Hàm đợi khóa apt được giải phóng
wait_for_apt() {
  echo "Đang đợi khóa apt được giải phóng..."
  while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    echo "Đang đợi tiến trình apt khác kết thúc..."
    sleep 5
  done
  echo "Khóa apt đã được giải phóng, tiếp tục cài đặt..."
}

# Hàm kiểm tra NVIDIA driver
check_nvidia_driver() {
  echo "Kiểm tra NVIDIA driver..."
  if command -v nvidia-smi &> /dev/null; then
    nvidia_output=$(nvidia-smi 2>&1)
    if echo "$nvidia_output" | grep -q "NVIDIA-SMI has failed"; then
      echo "⚠️ Phát hiện vấn đề với NVIDIA driver. Đang thực hiện khắc phục..."
      
      # Cập nhật package lists
      wait_for_apt && sudo apt-get update -y
      
      # Kiểm tra phiên bản driver hiện tại
      driver_version=$(ubuntu-drivers devices | grep "recommended" | awk '{print $3}' | cut -d'-' -f2)
      if [ -z "$driver_version" ]; then
        driver_version="550" # Mặc định nếu không tìm thấy
      fi
      
      echo "Đang cài đặt lại NVIDIA driver phiên bản $driver_version..."
      wait_for_apt && sudo apt-get install -y --reinstall nvidia-driver-$driver_version
      
      echo "Kiểm tra và tải kernel module NVIDIA..."
      if ! lsmod | grep -q nvidia; then
        echo "Tải kernel module NVIDIA..."
        sudo modprobe nvidia
      fi
      
      echo "Kiểm tra lại NVIDIA driver..."
      nvidia-smi
      
      echo "⚠️ Nếu vẫn gặp vấn đề với NVIDIA driver, vui lòng khởi động lại hệ thống và chạy lại script."
    else
      echo "✅ NVIDIA driver hoạt động bình thường."
    fi
  else
    echo "⚠️ Không tìm thấy NVIDIA driver. Đang cài đặt..."
    wait_for_apt && sudo apt-get update -y
    wait_for_apt && sudo apt-get install -y ubuntu-drivers-common
    
    # Tìm driver được khuyến nghị
    driver_version=$(ubuntu-drivers devices | grep "recommended" | awk '{print $3}' | cut -d'-' -f2)
    if [ -z "$driver_version" ]; then
      driver_version="550" # Mặc định nếu không tìm thấy
    fi
    
    echo "Đang cài đặt NVIDIA driver phiên bản $driver_version..."
    wait_for_apt && sudo apt-get install -y nvidia-driver-$driver_version
    
    echo "⚠️ Vui lòng khởi động lại hệ thống sau khi cài đặt hoàn tất để NVIDIA driver có hiệu lực."
  fi
}

echo "--------- 🟢 Bắt đầu clone repository -----------"
git clone https://github.com/thanhnn16/MIAI_n8n_dockercompose.git
mv MIAI_n8n_dockercompose n8n
cd n8n
cp .env.example .env
echo "--------- 🔴 Hoàn thành clone repository -----------"

echo "--------- 🟢 Bắt đầu cài đặt Docker -----------"
wait_for_apt && sudo apt update -y
wait_for_apt && sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
apt-cache policy docker-ce
wait_for_apt && sudo apt install -y docker-ce
echo "--------- 🔴 Hoàn thành cài đặt Docker -----------"

echo "--------- 🟢 Bắt đầu cài đặt Docker Compose -----------"
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
echo "--------- 🔴 Hoàn thành cài đặt Docker Compose -----------"

echo "--------- 🟢 Kiểm tra và cài đặt NVIDIA driver -----------"
check_nvidia_driver
echo "--------- 🔴 Hoàn thành kiểm tra NVIDIA driver -----------"

echo "--------- 🟢 Bắt đầu cài đặt NVIDIA support cho Docker -----------"
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
| sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
| sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
| sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
wait_for_apt && sudo apt-get update -y
wait_for_apt && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
echo "--------- 🔴 Hoàn thành cài đặt NVIDIA support cho Docker -----------"

echo "--------- 🟢 Bắt đầu cài đặt Nginx -----------"
wait_for_apt && sudo apt update -y
wait_for_apt && sudo apt install -y nginx
echo "--------- 🔴 Hoàn thành cài đặt Nginx -----------"

echo "--------- 🟢 Bắt đầu cài đặt Snap -----------"
wait_for_apt && sudo apt install -y snapd
echo "--------- 🔴 Hoàn thành cài đặt Snap -----------"

echo "--------- 🟢 Bắt đầu cấu hình Nginx cho n8n -----------"
# Kiểm tra xem thư mục nginx/n8n có tồn tại không
if [ -d "./nginx/n8n" ]; then
    # Copy file cấu hình từ thư mục nginx/n8n vào /etc/nginx/sites-available
    sudo cp ./nginx/n8n /etc/nginx/sites-available/n8n
    # Tạo symbolic link từ sites-available đến sites-enabled
    sudo ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
    # Kiểm tra cấu hình nginx
    sudo nginx -t
    # Khởi động lại nginx
    sudo systemctl restart nginx
else
    echo "Thư mục nginx/n8n không tồn tại, tạo file cấu hình Nginx mặc định cho n8n"
    cat > ./n8n_nginx_config << 'EOL'
server {
    listen 80;
    server_name n8n.autoreel.io.vn;

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOL
    sudo cp ./n8n_nginx_config /etc/nginx/sites-available/n8n
    sudo ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl restart nginx
    # Xóa file tạm
    rm ./n8n_nginx_config
fi
echo "--------- 🔴 Hoàn thành cấu hình Nginx cho n8n -----------"

echo "--------- 🟢 Bắt đầu cài đặt Certbot -----------"
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot
echo "--------- 🔴 Hoàn thành cài đặt Certbot -----------"

echo "--------- 🟢 Bắt đầu thiết lập SSL với Certbot -----------"
# Chạy certbot để lấy chứng chỉ SSL, chế độ tự động
sudo certbot --nginx --non-interactive --agree-tos --redirect \
    --staple-ocsp --email admin@autoreel.io.vn -d n8n.autoreel.io.vn
echo "--------- 🔴 Hoàn thành thiết lập SSL với Certbot -----------"

echo "--------- 🟢 Bắt đầu build Docker Compose -----------"
cd ~/n8n
echo "Đang build các container..."
sudo docker-compose build
echo "Build hoàn tất!"
echo "--------- 🔴 Hoàn thành build Docker Compose -----------"

echo "--------- 🟢 Khởi động n8n với Docker Compose -----------"
echo "Đang khởi động các container..."
sudo docker-compose up -d
echo "Các container đã được khởi động thành công!"
echo "--------- 🔴 n8n đã được khởi động -----------"

echo "--------- 🟢 Dọn dẹp các file tạm -----------"
# Xóa các file tạm và cache không cần thiết
cd ~
sudo apt-get clean -y
sudo apt-get autoremove -y
echo "--------- 🔴 Hoàn thành dọn dẹp -----------"

echo "Cài đặt hoàn tất! Truy cập n8n tại https://n8n.autoreel.io.vn"
echo ""
echo "Nếu bạn gặp vấn đề với NVIDIA driver, vui lòng thử các bước sau:"
echo "1. Khởi động lại hệ thống: sudo reboot"
echo "2. Sau khi khởi động lại, kiểm tra trạng thái driver: nvidia-smi"
echo "3. Nếu vẫn gặp vấn đề, chạy lại script này hoặc cài đặt thủ công driver NVIDIA"

