# Script para instalação automatizada do ZABBIX 5 e MySQL 8 no Debian 10
# Script formulado em 18/05/2021


# CORREÇÃO DE PATH (Necessário para que os caminhos da instalação sejam corretamente identificados)
export PATH="/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin:/usr/local/sbin:/usr/games"


# INSTALAÇÃO DOS REPOSITÓRIOS ATUAIS

# Instalação do OpenPGP
apt-get install sudo gnupg -y

#Configuração dos parâmetros em tempo de execução
set -e

# DOWNLOAD Repositório MYSQL
wget http://repo.mysql.com/mysql-apt-config_0.8.15-1_all.deb
 
# INSTALAÇÃO DO MYSQL
dpkg -i mysql-apt-config_0.8.15-1_all.deb

# ADICIONANDO CHAVES AVANÇADAS AO OpenPGP
apt-key adv --keyserver keys.gnupg.net --recv-keys 8C718D3B5072E1F5

# ATUALIZANDO O SISTEMA
apt-get update
apt-get -y full-upgrade

# DOWNLOAD ZABBIX 5.0
wget https://repo.zabbix.com/zabbix/5.0/debian/pool/main/z/zabbix-release/zabbix-release_5.0-1%2Bbuster_all.deb

# INSTALAÇÃO DO MYSQL
apt-get install -y mysql-community-server

# INSTALAÇÃO DO ZABBIX
dpkg -i zabbix-release_5.0-1+buster_all.deb

# ATUALIZANDO O SISTEMA
apt-get update

# BLOCO DA VERSÃO 8.0 DO MYSQL
MYSQL_VERSION=8.0
MYSQL_PASSWD=Senha123! # ALTERE ESSA SENHA DO ROOT!!
ZABBIX_PASSWD=Z@bbix123 # ALTERE ESSA SENHA DO USUÁRIO ZABBIX!!
[ -z "${MYSQL_PASSWD}" ] && MYSQL_PASSWD=mysql
[ -z "${ZABBIX_PASSWD}" ] && ZABBIX_PASSWD=zabbix

# BLOCO DE INSTALAÇÃO DO ZABBIX 5 COM O MYSQL 8
zabbix_server_install()
{
	cat <<EOF | sudo debconf-set-selections mysql-server-${MYSQL_VERSION} mysql-server/root_password password ${MYSQL_PASSWD} mysql-server-${MYSQL_VERSION} mysql-server/root_password_again password ${MYSQL_PASSWD} 
	EOF

  	sudo apt install -y zabbix-server-mysql zabbix-frontend-php php-mysql libapache2-mod-php vim zabbix-apache-conf

# DEFININDOO O TIME ZONE PARA O DO SISTEMA ONDE ESTÁ SENDO INSTALADO

  	timezone=$(cat /etc/timezone)
  	sudo sed -e 's/^post_max_size = .*/post_max_size = 16M/g' \
       		-e 's/^max_execution_time = .*/max_execution_time = 300/g' \
       		-e 's/^max_input_time = .*/max_input_time = 300/g' \
       		-e "s:^;date.timezone =.*:date.timezone = \"${timezone}\":g" \
       		-i /etc/php/7.3/apache2/php.ini

# BLOCO DE CRIAÇÃO E CONFIGURAÇÃO DO BANCO DE DADOS  	
  	
  	cat <<EOF | mysql -uroot -p${MYSQL_PASSWD}
	create database zabbix character set utf8 collate utf8_bin;
	use mysql;
	create user 'zabbix'@'localhost' identified by '${ZABBIX_PASSWD}';
	ALTER USER 'zabbix'@'localhost' IDENTIFIED WITH mysql_native_password BY '${ZABBIX_PASSWD}';
	GRANT ALL ON zabbix.* to 'zabbix'@'localhost';
	flush privileges;
	exit
	EOF

  	zcat /usr/share/doc/zabbix-server-mysql/create.sql.gz |mysql -uroot -p${MYSQL_PASSWD} zabbix;

  	sudo sed -e 's/# ListenPort=.*/ListenPort=10051/g' \
       		-e "s/# DBPassword=.*/DBPassword=${ZABBIX_PASSWD}/g" \
       		-i /etc/zabbix/zabbix_server.conf
       		
# PREENCHE O AQUIVO ZABBIZ.CONF.PHP

	cat <<EOF | sudo tee /etc/zabbix/zabbix.conf.php
	<?php
	
	// Arquivo de configuração do Zabbix.
	
	global \$DB;
	\$DB['TYPE']     = 'MYSQL';
	\$DB['SERVER']   = 'localhost';		//substituir pelo hostname do servidor, se for o caso
	\$DB['PORT']     = '0'; 		//porta padrão
	\$DB['DATABASE'] = 'zabbix';		
	\$DB['USER']     = 'zabbix';		//alterar conforme necessidade
	\$DB['PASSWORD'] = '${ZABBIX_PASSWD}';

	// Schema name. Used for IBM DB2 and PostgreSQL.
	
	\$DB['SCHEMA'] = '';
	\$ZBX_SERVER      = 'localhost';
	\$ZBX_SERVER_PORT = '10051';
	\$ZBX_SERVER_NAME = '';
	\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
	?>
	EOF

  	sudo a2enmod ssl				# MÓDULO APACHE
  	sudo a2ensite default-ssl			# HABILITA A PLATAFORMA DENTRO DO APACHE
	sudo systemctl enable apache2 zabbix-server	# INICIA O APACHE2 E O SERVIDOR ZABBIX
	sudo systemctl restart apache2 zabbix-server	# REINICIA O APACHE2 E O SERVIDOR ZABBIX
}

# INSTALAÇÃO DO SERVIÇO AGENTE ZABBIX
zabbix_agent_install()
{
	sudo apt install -y zabbix-agent
	sudo sed -e "s/^Hostname=.*/Hostname=localhost/g" \	#HOSTNAME UTILIZADO EM CONFIGURAÇÃO > HOSTS > CRIAR HOST
       		-i /etc/zabbix/zabbix_agentd.conf
  	sudo systemctl enable zabbix-agent
}

# FUNÇÃO DE INSTALAÇÃO DOS SERVIÇOS ZABBIX 
zabbix_main()
{
  zabbix_server_install
  zabbix_agent_install
}

zabbix_main
