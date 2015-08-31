mysql_service 'master1' do
	version '5.6'
	port '3306'
	data_dir '/data_master1'
	initial_root_password 'password'
	instance 'master1'
	bind_address '0.0.0.0'
	action [:create, :start]
end

mysql_service 'slave1' do
	version '5.6'
	port '3307'
	data_dir 'data_slave1'
	initial_root_password 'password'
	instance 'slave1'
	bind_address '0.0.0.0'
	action [:create, :start]
end

