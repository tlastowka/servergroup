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

cookbook_file '/tmp/create_superuser.sql' do
 source 'create_superuser.sql'
 owner 'root'
 group 'root'
 mode '644'
 action :create
end

cookbook_file '/tmp/create_repl_user.sql' do
 source 'create_repl_user.sql'
 owner 'root'
 group 'root'
 mode '644'
 action :create
end

cookbook_file '/tmp/create_sakila.sql' do
 source 'create_sakila.sql'
 owner 'root'
 group 'root'
 mode '644'
 action :create
end

mysql_service 'master' do
  port v_port
  version v_mysql_version
  initial_root_password v_root_pass
  action [:create, :start]
end

mysql_config 'master_logging' do
  instance 'master'
  variables(mysql_instance: 'master')
  source 'logging.erb'
  notifies :restart, 'mysql_service[master]'
  action :create
end


bash 'create super user' do
  code <<-EOF
  /usr/bin/mysql -u root -h 127.0.0.1 -P #{Shellwords.escape(v_port)} -p#{Shellwords.escape(v_root_pass)} -D mysql < /tmp/create_superuser.sql
  EOF
  not_if "/usr/bin/mysql -u root -h 127.0.0.1 -P #{Shellwords.escape(v_port)} -p#{Shellwords.escape(v_root_pass)} -e 'select User,Host from mysql.user' | grep '^#{Shellwords.escape(v_super_user)}$"
  action :run
end

bash 'create replication user' do
  code <<-EOF
  /usr/bin/mysql -u root -h 127.0.0.1 -P #{Shellwords.escape(v_port)} -p#{Shellwords.escape(v_root_pass)} -D mysql < /tmp/create_repl_user.sql
  EOF
  not_if "/usr/bin/mysql -u root -h 127.0.0.1 -P #{Shellwords.escape(v_port)} -p#{Shellwords.escape(v_root_pass)} -e 'select User,Host from mysql.user' | grep '^#{Shellwords.escape(v_replication_user)}$"
  action :run
end

mysql_config 'replication_master' do
  instance 'master'
  version v_mysql_version
  source 'replication-master.erb'
  variables(server_id: '1', mysql_instance: 'master')
  notifies :restart, 'mysql_service[master]', :immediately
  action :create
end


bash 'load_sakila' do
	code <<-EOF
	/usr/bin/wget http://downloads.mysql.com/docs/sakila-db.tar.gz -O /tmp/sakila-db.tar.gz
	sleep 1
	/bin/tar zxvf /tmp/sakila-db.tar.gz -C /tmp/
	sleep 1
	/usr/bin/mysql -u root -h 127.0.0.1 -P #{Shellwords.escape(v_port)} -p#{Shellwords.escape(v_root_pass)} < /tmp/create_sakila.sql
	/usr/bin/mysql -u root -h 127.0.0.1 -P #{Shellwords.escape(v_port)} -p#{Shellwords.escape(v_root_pass)} sakila < /tmp/sakila-db/sakila-schema.sql
	/usr/bin/mysql -u root -h 127.0.0.1 -P #{Shellwords.escape(v_port)} -p#{Shellwords.escape(v_root_pass)} sakila < /tmp/sakila-db/sakila-data.sql
  	EOF
	not_if "/usr/bin/mysql -u root -h 127.0.0.1 -P #{Shellwords.escape(v_port)} -p#{Shellwords.escape(v_root_pass)} -e 'SHOW DATABASES;' | grep '^sakila$' "
  
	action :run
end

