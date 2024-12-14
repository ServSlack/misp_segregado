
# Modo de uso Script de instalação segregada do MISP:

Efetue clone do projeto nos dois hosts WEB e DB, sendo a primeira execução no Banco de Dados.

# Execute o procedimento abaixo no servidor onde será instalado e configurado o Banco de Dados:

git clone https://github.com/ServSlack/misp_segregado
cd misp_segregado
chmod +x misp_db/Install_MariaDB_Segregado.sh
./Install_MariaDB_Segregado.sh

Concluido a instalação copie o resultado de " DBPASSWORD_MISP " e salve em arquivo texto para instalação do MISP_WEB.

# Execute o procedimento abaixo no servidor onde será instalado e configurado MISP_WEB:

git clone https://github.com/ServSlack/misp_segregado
cd misp_segregado/misp_web
vim INSTALL.ubuntu2404.sh

# Para perfeita execução do script é necessária alteração das variáveis abaixo:
DBHOST – Substitua com o nome ou IP do servidor de banco de dados.
DBPASSWORD_MISP - Substitua com o valor gerado no script ( Install_MariaDB_Segregado.sh )

chmod +x *.sh
./INSTALL.ubuntu2404.sh

# Após a conclusão do processo de instalação as informações mínimas de acesso ao ambiente serão exibidas e as demais pode ser encontradas em " /var/log/misp_settings.txt "
cat /var/log/misp_settings.txt
