v_port = '3306'
v_replication_user = 'repl_user'
v_replication_pass = 'repl_pass'
v_master_host = '10.0.11.20'
v_root_pass = 'password'

mysql_config 'replication_slave' do
  instance 'slave'
  source 'replication-slave.erb'
  variables(server_id: '103', mysql_instance: 'slave')
  notifies :restart, 'mysql_service[slave]', :immediately
  action :create
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
