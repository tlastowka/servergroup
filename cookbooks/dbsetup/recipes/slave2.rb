require 'shellwords'

# variables
v_root_pass = 'password'
v_mysql_version = '5.6'
v_port = '3306'
v_replication_pass = 'repl_pass'
v_master_host = '10.0.11.20'


v_db_sakila = 'sakila'
v_super_user = 'super'
v_super_pass = 'superpass'
v_replication_user = 'repl_user'
v_replication_pass = 'repl_pass'
v_range = '10.0.11.%'




mysql_service 'slave' do
  port v_port
  version v_mysql_version
  initial_root_password v_root_pass
  action [:create, :start]
end

mysql_config 'replication_slave' do
  instance 'slave'
  version v_mysql_version
  source 'replication-slave.erb'
  variables(server_id: '102', mysql_instance: 'slave')
  notifies :restart, 'mysql_service[slave]', :immediately
  action :create
end

# take a dump
bash 'create /root/dump.sql' do
  user 'root'
  code <<-EOF
    mysqldump \
    -h #{Shellwords.escape(v_master_host)} \
    -u #{Shellwords.escape(v_super_user)}\
    --protocol=tcp \
    -p#{Shellwords.escape(v_super_pass)} \
    --skip-lock-tables \
    --single-transaction \
    --flush-logs \
    --hex-blob \
    --master-data=2 \
    -A \ > /root/dump.sql;
   EOF
  not_if { ::File.exist?('/root/dump.sql') }
  action :run
end






bash 'stash position in /root/position' do
  user 'root'
  code <<-EOF
    head /root/dump.sql -n80 \
    | grep 'MASTER_LOG_POS' \
    | awk '{ print $6 }' \
    | cut -f2 -d '=' \
    | cut -f1 -d';' \
    > /root/position
  EOF
  not_if "/usr/bin/test -e /root/position"
  action :run
end

# import dump into slave
bash 'slave import' do
  user 'root'
  code "/usr/bin/mysql -u root -h 127.0.0.1 -P #{Shellwords.escape(v_port)} -p#{Shellwords.escape(v_root_pass)} < /root/dump.sql"
  not_if "/usr/bin/mysql -u root -h 127.0.0.1 -P #{Shellwords.escape(v_port)} -p#{Shellwords.escape(v_root_pass)} -e 'select User,Host from mysql.user' | grep repl"
  action :run
end

bash 'start_replication' do
  user 'root'
  code <<-EOF
  /usr/bin/printf " CHANGE MASTER TO MASTER_HOST='%s', MASTER_USER='%s', MASTER_PASSWORD='%s', MASTER_PORT=%s, MASTER_LOG_POS=%s; START SLAVE;" \
  "#{Shellwords.escape(v_master_host)}" \
  "#{Shellwords.escape(v_replication_user)}" \
  "#{Shellwords.escape(v_replication_pass)}" \
  "#{Shellwords.escape(v_port)}" \
  `cat /root/position` \
  | /usr/bin/mysql -u root -h 127.0.0.1 -P #{Shellwords.escape(v_port)} -p#{Shellwords.escape(v_root_pass)}
  EOF
  not_if "/usr/bin/mysql -u root -h 127.0.0.1 -P #{Shellwords.escape(v_port)} -p#{Shellwords.escape(v_root_pass)} -e 'SHOW SLAVE STATUS\G' | grep Slave_IO_State"
  action :run
end


