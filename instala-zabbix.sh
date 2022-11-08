#!/bin/sh

# Copyright (C) 2022 Fácil Tecnologia
# Arquivo       | instalazabbix.sh
# Descrição     | Instala o Zabbix versão 6.0 no Ubuntu 22.04 e Debian 11

# Autoria       | Jomar Nascimento (jomar.nascimento@faciltecnologia.com.br)
# Revisão       | Jomar Nascimento (jomar.nascimento@faciltecnologia.com.br)
# Data crĩação  | 04/11/2022
# Data revisão  | 08/11/2022
# Versão        | 1.1
#===================================================================================#
#                                      Tutorial                                     #
#===================================================================================#
### TUTORIAL:
#
# bash instala-zabbix.sh
# OBS.: Para executar esse script, é necessário executar como root 

#===================================================================================#
#                                      Funções                                      #
#===================================================================================#
# Verifica se o usuário é root
function sou_root(){
	! (( ${EUID:-0} || $(id -u) ))
}

# Imprime mensagem de erro em vermelho
# Uso: erro "mensagem personalizada de erro"
function erro() {
	echo -e "${REDB}● ${@}${RESET}"
	exit 1
}

#===================================================================================#
#                                     Principal                                     #
#===================================================================================#
sou_root || erro "É necessário executar como root!"
inicia_duracao

# Correção de PATH
export PATH="/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin:/usr/local/sbin:/usr/games"

# Instala o repositório do Zabbix
wget https://repo.zabbix.com/zabbix/6.0/debian/pool/main/z/zabbix-release/zabbix-release_6.0-4%2Bdebian11_all.deb
dpkg -i zabbix-release_6.0-4+debian11_all.deb
apt-get update

# Instala o postgresql
CHECKPG=$(apt list --installed postgresql | grep -E "postgresql" | cut -d/ -f1) > /dev/null
if [ $CHECKPG == 'postgresql' ]; then
	echo -e " ●  O postgresql já está instalado..."
else
	apt-get install -y postgresql postgresql-contrib
fi

# Instala o Zabbix server, frontend, agent
apt-get install -y zabbix-server-pgsql zabbix-frontend-php php7.4-pgsql zabbix-apache-conf zabbix-sql-scripts zabbix-agent

# Cria o banco de dados inicial
sudo -u postgres createuser --pwprompt zabbix
sudo -u postgres createdb -O zabbix zabbix

# Importa o esquema inicial e dados
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql zabbix

# Configuração da senha do zabbix
sed -i.BKP "s/\#\ DBPassword=/DBPassword=zabbix123./g" /etc/zabbix/zabbix_server.conf

# Configuração de local do apache
sed -i.BKP "s/\#\ php_value\ date.timezone\ Europe\/Riga/php_value date.timezone America\/Recife/g" /etc/apache2/conf-available/zabbix.conf

# Reinicia o servidor Zabbix e os processos agentes e adiciona à inicialização do sistema
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2
