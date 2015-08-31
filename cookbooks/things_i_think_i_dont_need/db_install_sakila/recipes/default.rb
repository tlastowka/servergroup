root_pass = 'password'
db_name = 'sakila'
bash 'load_sakila' do
	code <<-EOF
	/bin/rm -rf /tmp/sakila
	/bin/mkdir -p /tmp/sakila
	/usr/bin/wget http://downloads.mysql.com/docs/sakila-db.tar.gz -O /tmp/sakila/sakila-db.tar.gz
	/bin/tar zxvf /tmp/sakila/sakila-db.tar.gz -C /tmp/sakila/
	/usr/bin/mysql -u root -h 127.0.0.1 -P 3306 -p#{Shellwords.escape(root_pass)} -D mysql -e "CREATE DATABASE sakila;"
	/usr/bin/mysql -u root -h 127.0.0.1 -P 3306 -p#{Shellwords.escape(root_pass)} -D sakila < /tmp/sakila/sakila-db/sakila-schema.sql
	/usr/bin/mysql -u root -h 127.0.0.1 -P 3306 -p#{Shellwords.escape(root_pass)} -D sakila < /tmp/sakila/sakila-db/sakila-data.sql
  	EOF
	not_if "/usr/bin/mysql -u root -h 127.0.0.1 -P 3306 -p#{Shellwords.escape(root_pass)} -e 'SHOW DATABASES;' | grep #{Shellwords.escape(db_name)}"
  
	action :run
end