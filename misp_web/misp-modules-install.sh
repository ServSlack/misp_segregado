#!/bin/bash

# Instalar pacotes necessários
sudo apt install git libpq5 libjpeg-dev tesseract-ocr libpoppler-cpp-dev imagemagick virtualenv libopencv-dev zbar-tools libzbar0 libzbar-dev libfuzzy-dev libcaca-dev python3.12-venv -y

# Clonar o repositório misp-modules
sudo git clone https://github.com/MISP/misp-modules.git /usr/local/src/misp-modules
cd /usr/local/src/misp-modules

# Atualizar submódulos
sudo git submodule update --init

# Criar e ativar ambiente virtual:
sudo -u www-data python3 -m venv /var/www/MISP/venv

# Ajustar permissões do diretório venv
sudo chown -R www-data:www-data /var/www/MISP/venv

# Executar comandos dentro do ambiente virtual
sudo -u www-data /bin/bash -c '
    source /var/www/MISP/venv/bin/activate && \
    pip install poetry && \
    poetry install --with unstable && \
    pip install pyonyphe ODTReader && \
    deactivate
'

# Corrigir uso de funções descontinuadas
sudo sed -i 's/datetime.utcfromtimestamp(0)/datetime.fromtimestamp(0, datetime.UTC)/' /var/www/MISP/venv/lib/python3.12/site-packages/pytz/tzinfo.py

# Criar o arquivo de unidade systemd
sudo bash -c 'cat <<EOL > /etc/systemd/system/misp-modules.service
[Unit]
Description=MISP modules
[Service]
Type=simple
User=www-data
Group=www-data
ExecStart=/var/www/MISP/venv/bin/misp-modules -l 127.0.0.1 -s
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOL'

# Habilitar e iniciar o serviço misp-modules
sudo systemctl daemon-reload
sudo systemctl enable --now misp-modules
sudo systemctl start misp-modules
sudo systemctl status misp-modules

# Enable Workflow, Action and Enrichment Modules: ( Only Enable if MISP Modules is Enabled before )
sudo -Hu www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_services_enable" true
sudo -Hu www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Action_services_enable" true
sudo -Hu www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Workflow_enable" true
#
# Enable Import x Export Modules
sudo -Hu www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Import_services_enable" true
sudo -Hu www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Export_services_enable" true

echo "Instalação dos MISP Modules concluída e serviço iniciado."

