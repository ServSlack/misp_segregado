#!/bin/bash

# Atualizar a lista de pacotes
sudo apt update

# Instalar o ClamAV e o daemon do ClamAV
sudo apt install -y clamav clamav-daemon

# Parar o serviço do ClamAV para atualizar as definições de vírus
sudo systemctl stop clamav-freshclam

# Atualizar as definições de vírus
sudo freshclam

# Reiniciar o serviço do ClamAV
sudo systemctl start clamav-freshclam

# Habilitar o serviço do ClamAV para iniciar automaticamente no boot
sudo systemctl disable clamav-freshclam
sudo systemctl enable clamav-daemon

# Verificar se o comando crontab está instalado
if ! command -v crontab &> /dev/null
then
    echo "crontab could not be found, installing..."
    sudo apt install -y cron
fi

# Adicionar tarefa ao crontab para parar, atualizar e iniciar o ClamAV 3 vezes ao dia
(crontab -l 2>/dev/null; echo "0 0,8,16 * * * systemctl stop clamav-freshclam && /usr/bin/freshclam && systemctl start clamav-freshclam && sudo -Hu www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_clamav_enabled" "true" && sudo -Hu www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_clamav_connection" "unix:///var/run/clamav/clamd.ctl" && sudo -Hu www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.attachment_scan_module" "clamav"") | crontab -

sudo systemctl restart clamav-daemon
#
echo "Instalação, configuração e agendamento do ClamAV concluídos com sucesso!"

