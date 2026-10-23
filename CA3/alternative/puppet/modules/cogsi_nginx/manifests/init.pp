# Nginx on proxy. Replaces the Ansible role nginx.
class cogsi_nginx (
  Integer $app_port = lookup('cogsi::app_port'),
) {
  package { 'nginx':
    ensure => installed,
  }

  file { '/etc/nginx/sites-available/bookstore':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('cogsi_nginx/bookstore.conf.epp', { 'upstream' => "app:${app_port}" }),
    require => Package['nginx'],
  }

  file { '/etc/nginx/sites-enabled/bookstore':
    ensure => link,
    target => '/etc/nginx/sites-available/bookstore',
  }

  file { '/etc/nginx/sites-enabled/default':
    ensure  => absent,
    require => Package['nginx'],
  }

  # The reload validates the configuration first: a broken site fails the run
  # instead of being loaded.
  service { 'nginx':
    ensure    => running,
    enable    => true,
    restart   => '/usr/sbin/nginx -t && /usr/bin/systemctl reload nginx',
    subscribe => File['/etc/nginx/sites-available/bookstore', '/etc/nginx/sites-enabled/bookstore', '/etc/nginx/sites-enabled/default'],
  }

  cogsi_common::ufw_rule { 'allow 80/tcp': }

  file { '/usr/local/sbin/proxy-health':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/cogsi_nginx/proxy-health',
  }

  exec { 'proxy health check':
    command  => '/bin/echo "Nginx does not return the Bookstore response" >&2; /bin/false',
    unless   => "/usr/local/sbin/proxy-health http://127.0.0.1 http://app:${app_port}",
    provider => shell,
    require  => [Service['nginx'], File['/usr/local/sbin/proxy-health']],
  }
}
