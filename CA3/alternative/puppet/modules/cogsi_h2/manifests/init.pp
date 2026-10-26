# H2 in server mode on db. Replaces the Ansible role h2.
class cogsi_h2 (
  Integer $port = lookup('cogsi::h2_port'),
  String $data_group = lookup('cogsi::developers_group'),
  String $app_ip = lookup('cogsi::hosts')['app'],
  String $db_ip = lookup('cogsi::hosts')['db'],
  String $db_name = lookup('cogsi::db_name'),
  String $db_user = lookup('cogsi::db_user'),
  Sensitive[String] $db_password = Sensitive(lookup('cogsi::db_password')),
  String $version = '2.4.240',
  String $sha1 = '686180ad33981ad943fdc0ab381e619b2c2fdfe5',
) {
  $jar = "/opt/h2/h2-${version}.jar"
  $data_dir = '/var/lib/h2'

  package { 'openjdk-21-jre-headless':
    ensure => installed,
  }

  file { '/opt/h2':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Downloaded only when missing or when the checksum does not match.
  file { $jar:
    ensure         => file,
    source         => "https://repo1.maven.org/maven2/com/h2database/h2/${version}/h2-${version}.jar",
    checksum       => 'sha1',
    checksum_value => $sha1,
    owner          => 'root',
    group          => 'root',
    mode           => '0644',
  }

  user { 'h2':
    ensure     => present,
    system     => true,
    home       => $data_dir,
    shell      => '/usr/sbin/nologin',
    groups     => [$data_group],
    membership => minimum,
  }

  file { $data_dir:
    ensure  => directory,
    owner   => 'h2',
    group   => $data_group,
    mode    => '2770',
    require => User['h2'],
  }

  file { '/etc/systemd/system/h2.service':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('cogsi_h2/h2.service.epp', {
      'jar' => $jar, 'port' => $port, 'data_dir' => $data_dir, 'group' => $data_group,
    }),
  }

  exec { 'h2 daemon-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
    subscribe   => File['/etc/systemd/system/h2.service'],
  }

  service { 'h2':
    ensure    => running,
    enable    => true,
    subscribe => [File[$jar], File['/etc/systemd/system/h2.service'], Exec['h2 daemon-reload']],
    require   => [Package['openjdk-21-jre-headless'], File[$data_dir]],
  }

  cogsi_common::ufw_rule { "allow from ${app_ip} to ${db_ip} port ${port} proto tcp": }

  # Health check: credentials in a root-only file read by the check script.
  file { '/etc/h2-health.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => Sensitive("H2_JAR=${jar}\nH2_URL=jdbc:h2:tcp://127.0.0.1:${port}/./${db_name}\nH2_USER=${db_user}\nH2_PASSWORD=${db_password.unwrap}\nH2_VERSION=${version}\n"),
  }

  file { '/usr/local/sbin/h2-health':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0750',
    source => 'puppet:///modules/cogsi_h2/h2-health',
  }

  # The check is the "unless" of a command that always fails: when H2 answers,
  # nothing runs and nothing is reported as changed; when it does not, the run
  # fails. A plain exec would run, and be reported as a change, on every run.
  exec { 'h2 health check':
    command => '/bin/echo "H2 did not answer SELECT H2VERSION()" >&2; /bin/false',
    unless  => '/usr/local/sbin/h2-health',
    require => [Service['h2'], File['/etc/h2-health.conf', '/usr/local/sbin/h2-health']],
    provider => shell,
  }
}
