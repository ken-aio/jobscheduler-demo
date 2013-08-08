
rpmfile = "pgdg-centos92-9.2-6.noarch.rpm"
rpmuri = "http://yum.postgresql.org/9.2/redhat/rhel-6-x86_64/pgdg-centos92-9.2-6.noarch.rpm"
tmpdir = "#{Chef::Config[:file_cache_path]}"

# downloading postgresql rpm
remote_file "#{tmpdir}/#{rpmfile}" do
  source rpmuri
  mode "0644"
  action :create
end

package "#{tmpdir}/#{rpmfile}" do
  provider Chef::Provider::Package::Rpm
  source "#{tmpdir}/#{rpmfile}"
  action :install
end

%w{
  postgresql92
  postgresql92-devel
  postgresql92-contrib
  postgresql92-server
}.each do |pkg|
  package pkg do
    action :install 
  end
end

user "postgres" do
  home "/var/lib/pgsql"
  password "$6$MGoYL01M$9d2ZYc.oILhg0zuroyrDx.GyPqn4dL9QVl55b9fokLPNKp8sd6DxdmuReuW1yDOx6SnDhn4sBUmFNlxrxtZKN."
  action :create
  only_if { `getent passwd | grep -e "^postgres" | wc -l`.to_i == 0 }
end

execute "echo \"export PGDATA=/var/lib/pgsql/9.2/data PATH=/usr/pgsql-9.2/bin/:$PATH\" >> /var/lib/pgsql/.bash_profile" do
  action :run
  user "postgres"
  only_if { File.exists?("/var/lib/pgsql/.bash_profile") && `cat /var/lib/pgsql/.bash_profile | grep PGDATA | grep PATH | wc -l`.to_i == 0 }
end

execute "echo \"export LD_LIBRARY_PATH=/usr/pgsql-9.2/lib\" >> /var/lib/pgsql/.bash_profile" do
  action :run
  user "postgres"
  only_if { File.exists?("/var/lib/pgsql/.bash_profile") && `cat /var/lib/pgsql/.bash_profile | grep LD_LIBRARY_PATH | wc -l`.to_i == 0 }
end
