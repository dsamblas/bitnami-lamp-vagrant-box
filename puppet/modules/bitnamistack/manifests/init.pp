class bitnamistack inherits bitnamistack::params {

    include mysql::params

    # template vars
    $stack_full_path = $bitnamistack::params::stack_full_path
    $dbuserpass = $mysql::params::dbuserpass


    file { 'answer_file':
        path => '/tmp/answer_file',
        ensure => present,
        content => template('bitnamistack/answer_file.erb'),
    }
    exec {
      "upgrade-swap-1":
        command =>"swapoff -a",
        subscribe => File['answer_file']

    }
  exec {
    "upgrade-swap-2":
      command =>"dd if=/dev/zero of=/mnt/swap.0 bs=1024 count=2148576",
      subscribe => Exec['upgrade-swap-1']

  }
  exec {
    "upgrade-swap-3":
      command =>"mkswap /mnt/swap.0",
      subscribe => Exec['upgrade-swap-2']

  }
  exec {
    "upgrade-swap-4":
      command =>'echo "/mnt/swap.0 swap swap defaults 0 0" >> /etc/fstab',
      subscribe => Exec['upgrade-swap-3']

  }
  exec {
    "enable-swap":
      command =>'swapon -a -e || /bin/true',
      subscribe => Exec['upgrade-swap-4']

  }
    exec {
        "bitnami-lampstack":
          command => "wget -P /home/vagrant $bitnamistack::params::download_install_path",
          creates => "/home/vagrant/$bitnamistack::params::install_file",
          subscribe => Exec['enable-swap']
    }

    exec {
        "make-executable":
        command => "chmod +x /home/vagrant/$bitnamistack::params::install_file",
        subscribe => Exec['bitnami-lampstack']
    }

    exec {
        "install":
        command => "/home/vagrant/$bitnamistack::params::install_file --optionfile /tmp/answer_file",
        subscribe => Exec['make-executable'],
        creates => "$bitnamistack::params::stack_full_path/ctlscript.sh",
        logoutput => "on_failure",
        timeout     => 6800,
        returns => [0,1],
    }

    exec { "stop-lamp":
        command => "/home/vagrant/lampstack/ctlscript.sh stop",
        subscribe => Exec['install']
    }

    file { "phpmyadmin-conf":
        path => "$bitnamistack::params::stack_full_path/apps/phpmyadmin/conf/phpmyadmin.conf",
        content => template('bitnamistack/phpmyadmin.conf.erb'),
        subscribe => Exec['stop-lamp'],
        ensure => present
    }

    file { "httpd-conf":
        path => "$bitnamistack::params::stack_full_path/apache2/conf/httpd.conf",
        content => template('bitnamistack/httpd.conf.erb'),
        subscribe => Exec['stop-lamp'],
        ensure => present
    }

    exec {
        "start-up":
        command => "/home/vagrant/lampstack/ctlscript.sh start",
        subscribe => File['phpmyadmin-conf'],
    }


}