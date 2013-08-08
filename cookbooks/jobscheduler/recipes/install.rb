#
# Cookbook Name:: jobscheduler
# Recipe:: default
#
# Copyright 2013, sova 
#
# All rights reserved - Do Not Redistribute
#

tmp_dir = Chef::Config[:file_cache_path]
js_file = "jobscheduler.1.5.3192"
js_file_archive = "jobscheduler_linux-x64.1.5.3192.tar.gz" 
js_start_shell = "/etc/init.d/jobscheduler"
scheduler_home = "/opt/sos-berlin.com/jobscheduler/scheduler"
scheduler_data = "/home/scheduler/sos-berlin.com/jobscheduler/scheduler"
java_file = "jre-7u25-linux-x64.tar.gz"

# jobschedulerインストール有無の確認
if File.exists?("#{js_start_shell}") then
  log "JobScheduler module is already downloaded. This step is skipped."
else
  log "JobScheduler module is installing now."

  group "scheduler" do
    action :create
  end

  user "scheduler" do
    comment "JobScheduler User"
    gid "scheduler"
    home "/home/scheduler"
    shell "/bin/bash"
    system true
    supports :manage_home=>true
    action :create
  end

  execute "echo 'scheduler ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers" do
    only_if { `grep -c 'scheduler ALL=(ALL) NOPASSWD:ALL' /etc/sudoers`.to_i == 0 }
  end

  # install java 64bit
  cookbook_file "#{tmp_dir}/#{java_file}" do
    mode 0755
    owner "root"
    group "root"
  end
 
  execute "install java 64bit" do
    command "tar -zxf #{tmp_dir}/#{java_file} -C /home/scheduler/"
    not_if { File.exists?("/home/scheduler/jre1.7.0_25/bin") } 
  end

  # jobschedulerのインストール開始
  remote_file "#{tmp_dir}/#{js_file_archive}" do
    source "http://sourceforge.net/projects/jobscheduler/files/jobscheduler_linux-x64.1.5.3192.tar.gz/download"
    owner "root"
    group "root"
  end

  execute "tar -zxf" do
    command "tar -zxf #{tmp_dir}/#{js_file_archive} -C #{tmp_dir}"
    only_if { ::File.exists?("#{tmp_dir}/#{js_file_archive}")}
  end

  template "#{tmp_dir}/#{js_file}/jobscheduler_install.xml" do 
    source "jobscheduler_install.xml.erb"
    backup false
    owner "scheduler"
    group "scheduler"
    mode 0644
  end

  cookbook_file "#{tmp_dir}/#{js_file}/setup.sh" do
    mode 0755
    owner "scheduler"
    group "scheduler"
  end

  execute "psql -c \"create user #{node.jobscheduler.engine.database.dbuser} with encrypted password '#{node.jobscheduler.engine.database.dbpassword}' nocreatedb nocreateuser\" -h 127.0.0.1 -p #{node.jobscheduler.engine.database.dbport} -d postgres -U postgres -w" do
    action :run
    user "postgres"
    only_if { `su - postgres -c "psql -At -c \\"select count(*) from pg_user where usename='#{node.jobscheduler.engine.database.dbuser}'\\" -h 127.0.0.1 -p #{node.jobscheduler.engine.database.dbport} -d postgres -U postgres -w"`.to_i == 0 }
  end

  execute "psql -c \"alter user #{node.jobscheduler.engine.database.dbuser} set standard_conforming_strings = off\" -h 127.0.0.1 -p #{node.jobscheduler.engine.database.dbport} -d postgres -U postgres -w" do
    action :run
    user "postgres"
  end

  execute "psql -c \"alter user #{node.jobscheduler.engine.database.dbuser} set bytea_output = 'escape'\" -h 127.0.0.1 -p #{node.jobscheduler.engine.database.dbport} -d postgres -U postgres -w" do
    action :run
    user "postgres"
  end

  execute "psql -c \"create database #{node.jobscheduler.engine.database.dbname} owner #{node.jobscheduler.engine.database.dbuser}\" -h 127.0.0.1 -p #{node.jobscheduler.engine.database.dbport} -d postgres -U postgres -w" do
    action :run
    user "postgres"
    only_if { `su - postgres -c "psql -At -c \\"select count(*) from pg_database where datname='#{node.jobscheduler.engine.database.dbname}'\\" -h 127.0.0.1 -p #{node.jobscheduler.engine.database.dbport} -d postgres -U postgres -w"`.to_i == 0 }
  end

  script "install jobscheduler" do
    interpreter "bash"
    user "root"
    code <<-EOH
      cd "#{tmp_dir}/#{js_file}"
      sudo -u scheduler ./setup.sh jobscheduler_install.xml
    EOH
  end

  cookbook_file "#{scheduler_home}/lib/com.sos.hibernate_pgsql.jar" do
    mode 0644
    owner "root"
    group "root"
  end

  script "change factory.ini" do
    interpreter "bash"
    user "root"
    code <<-EOH
      cd "#{tmp_dir}"
      ruby -pe '$_.gsub!("class_path              = ", "class_path              = ${SCHEDULER_HOME}/lib/com.sos.hibernate_pgsql.jar:")' #{scheduler_data}/config/factory.ini > tmp.ini
      cp -f tmp.ini #{scheduler_data}/config/factory.ini
      rm -f tmp.ini
    EOH
  end

  script "change scheduler.xml" do
    interpreter "bash"
    user "root"
    code <<-EOH
      cd "#{tmp_dir}"
      ruby -pe '$_.gsub!("<plugins>", "<!-- <plugins>")' #{scheduler_data}/config/scheduler.xml > tmp.xml
      ruby -pe '$_.gsub!("</plugins>", "</plugins> -->")' tmp.xml > tmp2.xml
      cp -f tmp2.xml #{scheduler_data}/config/scheduler.xml
      rm -f tmp*.xml
    EOH
  end

  script "change jobscheduler.sh" do
    interpreter "bash"
    user "root"
    code <<-EOH
      cd "#{tmp_dir}"
      sed -e 's/test "$USER" = "$SCHEDULER_USER"/# test "$USER" = "$SCHEDULER_USER"/' #{scheduler_home}/bin/jobscheduler.sh > tmp.sh
      cp -f tmp.sh #{scheduler_home}/bin/jobscheduler.sh
      rm -f tmp.sh
    EOH
  end

  link "/etc/init.d/jobscheduler" do
    to "#{scheduler_home}/bin/jobscheduler.sh"
    link_type :symbolic
  end

  service "jobscheduler" do
    action [:enable , :start]
  end

  delfile = ["#{java_file}", "#{js_file_archive}"]

  delfile.each do |f|
    file "#{tmp_dir}/#{f}" do
      action :delete
      only_if { File.exists?("#{tmp_dir}/#{f}") }
    end
  end

  directory "#{tmp_dir}/#{js_file}" do
    action :delete
    recursive true
    only_if { File.exists?("#{tmp_dir}/#{js_file}") }
  end

end
