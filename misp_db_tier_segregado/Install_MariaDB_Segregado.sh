#!/bin/bash

# Função para exibir o status
print_status() {
    echo -e "\e[1;32m[STATUS]\e[0m $1"
}

# Função para exibir notificações
print_notification() {
    echo -e "\e[1;34m[INFO]\e[0m $1"
    echo "[INFO] $1" >> install_MISP_DB.txt
}

# Função para verificar erros
error_check() {
    if [ $? -ne 0 ]; then
        echo -e "\e[1;31m[ERRO]\e[0m $1"
        exit 1
    fi
}

# Configurações
MISP_WEB_DIR="/var/www/MISP"
logfile="/var/log/misp_install.log"

# Configurações do Banco de Dados
DBHOST='localhost'
DBUSER_ADMIN='root'
DBPASSWORD_ADMIN="$(openssl rand -base64 32)" # Gera uma senha aleatória
DBNAME='misp'
DBPORT='3306'
DBUSER_MISP='misp'
DBPASSWORD_MISP="$(openssl rand -base64 32)"

# Instalação do MariaDB Server
print_status "Instalando MariaDB Server..."
sudo apt-get update
sudo apt-get install -y mariadb-server
error_check "Erro ao instalar o MariaDB Server."

# Atualizar senha do usuário root no MariaDB
print_status "Atualizando senha do usuário root no MariaDB..."
sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DBPASSWORD_ADMIN}';" &>> $logfile
error_check "Erro ao atualizar a senha do usuário root."

DBUSER_ADMIN_STRING="-u root"
DBPASSWORD_ADMIN_STRING="-p${DBPASSWORD_ADMIN}"

DBUSER_MISP_STRING="-u ${DBUSER_MISP}"
DBPASSWORD_MISP_STRING="-p${DBPASSWORD_MISP}"

DBHOST_STRING=''
if [ "$DBHOST" != "localhost" ]; then
    DBHOST_STRING="-h ${DBHOST}"
fi

DBPORT_STRING=''
if [ "$DBPORT" != 3306 ]; then
    DBPORT_STRING="--port ${DBPORT}"
fi

DBCONN_ADMIN_STRING="${DBPORT_STRING} ${DBHOST_STRING} ${DBUSER_ADMIN_STRING} ${DBPASSWORD_ADMIN_STRING}"
DBCONN_MISP_STRING="${DBPORT_STRING} ${DBHOST_STRING} ${DBUSER_MISP_STRING} ${DBPASSWORD_MISP_STRING}"

print_status "Criando banco de dados e usuário para MISP e importando o esquema básico do MISP..."

sudo mysql $DBCONN_ADMIN_STRING -e "CREATE DATABASE ${DBNAME};" &>> $logfile
error_check "Erro ao criar o banco de dados ${DBNAME}."

sudo mysql $DBCONN_ADMIN_STRING -e "CREATE USER '${DBUSER_MISP}'@'%' IDENTIFIED BY '${DBPASSWORD_MISP}';" &>> $logfile
error_check "Erro ao criar o usuário ${DBUSER_MISP}."

sudo mysql $DBCONN_ADMIN_STRING -e "GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER_MISP}'@'%';" &>> $logfile
error_check "Erro ao conceder privilégios ao usuário ${DBUSER_MISP}."

sudo mysql $DBCONN_ADMIN_STRING -e "FLUSH PRIVILEGES;" &>> $logfile
error_check "Erro ao atualizar privilégios."

# Baixar e importar o schema do MISP
curl -o /tmp/MYSQL.sql https://raw.githubusercontent.com/MISP/MISP/2.4/INSTALL/MYSQL.sql
error_check "Erro ao baixar o schema do MISP."

sudo mariadb -u ${DBUSER_MISP} -p${DBPASSWORD_MISP} ${DBNAME} < /tmp/MYSQL.sql
error_check "Erro ao importar o esquema de banco de dados do MISP."

print_status "Movendo e configurando arquivos de configuração PHP do MISP..."

# Configurações de otimização do MariaDB
export num_cpu=$(cat /proc/cpuinfo | grep processor | wc -l | awk '{print int($1 * 0.90)}')
export innodb_buffer_pool_instances=$num_cpu
export ram_70=$(free -h | grep Mem | awk '{print $2}' | tr -d "Gi" | awk '{print int($1 * 0.7)}')
export innodb_buffer_pool_size=$ram_70
export max_connections=$((num_cpu * 10))

cat <<EOF > /etc/mysql/mariadb.conf.d/50-server.cnf
[mariadbd]
performance_schema=ON
performance-schema-instrument='stage/%=ON'
performance-schema-consumer-events-stages-current=ON
performance-schema-consumer-events-stages-history=ON
performance-schema-consumer-events-stages-history-long=ON

# === Configurações Requeridas ===
basedir                         = /usr
bind_address                    = 0.0.0.0
datadir                         = /var/lib/mysql
max_allowed_packet              = 256M
max_connect_errors              = 1000000
pid_file                        = /var/run/mysqld/mysqld.pid
port                            = 3306
socket                          = /run/mysqld/mysqld.sock
secure_file_priv                = /var/lib/mysql
tmpdir                          = /tmp
user                            = mysql

# Desativar links simbólicos é recomendado para prevenir riscos de segurança
symbolic-links = 0
log-error = /var/log/mysql/mysqld.log
pid-file = /var/run/mysqld/mysqld.pid

# === Configurações InnoDB ===
default_storage_engine          = InnoDB
innodb_buffer_pool_instances    = ${innodb_buffer_pool_instances}
innodb_buffer_pool_size         = ${innodb_buffer_pool_size}G
innodb_file_per_table           = 1
innodb_flush_log_at_trx_commit  = 2
innodb_flush_method             = O_DIRECT
innodb_log_buffer_size          = 64M
innodb_log_file_size            = 2G
innodb_stats_on_metadata        = 0
innodb_read_io_threads          = ${num_cpu}
innodb_write_io_threads         = ${num_cpu}
innodb_io_capacity              = 4000
innodb_io_capacity_max          = 8000

# === Configurações de Conexão ===
max_connections                 = ${max_connections}
back_log                        = 512
thread_cache_size               = ${num_cpu}
thread_stack                    = 192K

# === Configurações de Buffer ===
innodb_sort_buffer_size         = 2M
join_buffer_size                = 4M
read_buffer_size                = 3M
read_rnd_buffer_size            = 4M
sort_buffer_size                = 4M

# === Configurações de Tabela ===
table_definition_cache          = 40000
table_open_cache                = 40000
open_files_limit                = 32768
max_heap_table_size             = 256M
tmp_table_size                  = 256M

# === Configurações de Pesquisa ===
ft_min_word_len                 = 3

# === Configurações de Logging ===
log_bin                         = ON
binlog_format                   = ROW
expire_logs_days                = 7
log_error                       = /var/log/mysql/mysqld.log
log_queries_not_using_indexes   = ON
long_query_time                 = 1
slow_query_log                  = OFF
slow_query_log_file             = /var/log/mysql/slow.log
EOF

# Reiniciar serviço MariaDB para aplicar as mudanças
sudo systemctl restart mariadb

# Exibir as variáveis criadas durante a execução do script
print_notification "As credenciais padrão do administrador são:"
print_notification "DBUSER_ADMIN: root"
print_notification "DBPASSWORD_ADMIN: ${DBPASSWORD_ADMIN}"

print_notification "As credenciais do banco de dados MISP são:"
print_notification "DBNAME: ${DBNAME}"
print_notification "DBUSER_MISP: ${DBUSER_MISP}"
print_notification "DBPASSWORD_MISP: ${DBPASSWORD_MISP}"

echo "Instalação do MariaDB e configuração de tunning concluídos com sucesso!"

