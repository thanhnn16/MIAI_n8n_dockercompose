# Fork from MIAI_n8n_dockercompose

```
curl -s -o install.sh https://raw.githubusercontent.com/thanhnn16/MIAI_n8n_dockercompose/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

```
docker compose --profile gpu-nvidia --profile localai --profile n8n up -d
```