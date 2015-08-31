require 'shellwords'

# variables
v_root_pass = 'password'
v_mysql_version = '5.6'
v_port = '3306'


v_db_sakila = 'sakila'
v_super_user = 'super'
v_super_pass = 'superpass'
v_replication_user = 'repl_user'
v_replication_pass = 'repl_pass'
v_range = '10.0.11.%'


mysql_service 'master' do
  port v_port
  version v_mysql_version
  initial_root_password v_root_pass
  action [:create, :start]
end

mysql_config 'replication_master' do
  instance 'master'
  version v_mysql_version
  source 'replication-master.erb'
  variables(server_id: '1', mysql_instance: 'master')
  notifies :restart, 'mysql_service[master]', :immediately
  action :create
end

bash 'create super user' do
  code <<-EOF
  /usr/bin/mysql -u root -h 127.0.0.1 -P 3306 -p#{Shellwords.escape(v_root_pass)} -D mysql -e "CREATE USER '#{Shellwords.escape(v_super_user)}'@'#{v_range}' IDENTIFIED BY '#{Shellwords.escape(v_super_pass)}';"
  /usr/bin/mysql -u root -h 127.0.0.1 -P 3306 -p#{Shellwords.escape(v_root_pass)} -D mysql -e "GRANT ALL PRIVILEGES ON *.* TO '#{Shellwords.escape(v_super_user)}'@'#{v_range}';"
  EOF
  not_if "/usr/bin/mysql -u root -h 127.0.0.1 -P 3306 -p#{Shellwords.escape(v_root_pass)} -e 'select User,Host from mysql.user' | grep '^#{Shellwords.escape(v_super_user)}$"
  action :run
end

bash 'create replication user' do
  code <<-EOF
  /usr/bin/mysql -u root -h 127.0.0.1 -P 3306 -p#{Shellwords.escape(v_root_pass)} -D mysql -e "CREATE USER '#{Shellwords.escape(v_replication_user)}'@'#{v_range}' IDENTIFIED BY '#{Shellwords.escape(v_replication_pass)}';"
  /usr/bin/mysql -u root -h 127.0.0.1 -P 3306 -p#{Shellwords.escape(v_root_pass)} -D mysql -e "GRANT REPLICATION SLAVE ON *.* TO '#{Shellwords.escape(v_replication_user)}'@'#{v_range}';"
  EOF
  not_if "/usr/bin/mysql -u root -h 127.0.0.1 -P 3306 -p#{Shellwords.escape(v_root_pass)} -e 'select User,Host from mysql.user' | grep '^#{Shellwords.escape(v_replication_user)}$"
  action :run
end

bash 'load_sakila' do
	user 'root'
	code <<-EOF
	/usr/bin/wget http://downloads.mysql.com/docs/sakila-db.tar.gz -O /root/sakila-db.tar.gz
	sleep 5
	/bin/tar zxvf /root/sakila-db.tar.gz -C /root/
	sleep 5
	/usr/bin/mysql -u root -h 127.0.0.1 -P 3306 -p#{Shellwords.escape(v_root_pass)} -D mysql -e "CREATE DATABASE #{Shellwords.escape(v_db_sakila)};"
	/usr/bin/mysql -u root -h 127.0.0.1 -P 3306 -p#{Shellwords.escape(v_root_pass)} -D #{Shellwords.escape(v_db_sakila)} < /root/sakila-db/sakila-schema.sql
	/usr/bin/mysql -u root -h 127.0.0.1 -P 3306 -p#{Shellwords.escape(v_root_pass)} -D #{Shellwords.escape(v_db_sakila)} < /root/sakila-db/sakila-data.sql
  	EOF
	not_if "/usr/bin/mysql -u root -h 127.0.0.1 -P 3306 -p#{Shellwords.escape(v_root_pass)} -e 'SHOW DATABASES;' | grep '^#{Shellwords.escape(v_db_sakila)}$'"
  
	action :run
end

