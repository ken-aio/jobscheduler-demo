
tmpdir = Chef::Config[:file_cache_path]

execute "service postgresql-9.2 initdb -D #{node['postgresql']['dir']} -U 'postgres' --no-locale" do
  not_if { File.exist?("#{node['postgresql']['dir']}/PG_VERSION") }
end

template "#{node['postgresql']['dir']}/pg_hba.conf" do
  source "pg_hba.conf.erb"
  owner "postgres"
  group "postgres"
  mode 0600
  only_if { File.exist?("#{node['postgresql']['dir']}/pg_hba.conf") }
end

template "#{node['postgresql']['dir']}/postgresql.conf" do
  source "postgresql.conf.erb"
  owner "postgres"
  group "postgres"
  mode 0600
  only_if { File.exist?("#{node['postgresql']['dir']}/postgresql.conf") }
end

script "change factory.ini" do
  interpreter "bash"
  user "root"
  code <<-EOH
    cd "#{Chef::Config[:file_cache_path]}"
    ruby -pe '$_.gsub!("PGPORT=5432", "PGPORT=#{node['postgresql']['port']}")' /etc/init.d/postgresql-9.2 > tmp
    cp -f tmp /etc/init.d/postgresql-9.2
  EOH
end

service "postgresql-9.2" do
  service_name "postgresql-9.2"
  supports :restart => true, :status => true, :reload => true
  action [:enable, :restart]
end

