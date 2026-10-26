# The Bookstore on app. Replaces the Ansible role bookstore.
class cogsi_bookstore (
  Integer $app_port = lookup('cogsi::app_port'),
  Integer $h2_port = lookup('cogsi::h2_port'),
  String $app_group = lookup('cogsi::developers_group'),
  String $proxy_ip = lookup('cogsi::hosts')['proxy'],
  String $app_ip = lookup('cogsi::hosts')['app'],
  String $db_name = lookup('cogsi::db_name'),
  String $db_user = lookup('cogsi::db_user'),
  Sensitive[String] $db_password = Sensitive(lookup('cogsi::db_password')),
  String $repo_url = 'https://github.com/Af-Oliveira/COGSI-2026-2027.git',
  String $repo_branch = 'main',
) {
  $home = '/var/lib/bookstore'
  $src = "${home}/src"
  $project = "${src}/CA1/part2"
  $git = "/usr/bin/git -C ${src}"

  package { ['git', 'openjdk-21-jdk-headless']:
    ensure => installed,
  }

  user { 'bookstore':
    ensure     => present,
    system     => true,
    home       => $home,
    managehome => true,
    shell      => '/usr/sbin/nologin',
    groups     => [$app_group],
    membership => minimum,
  }

  # Puppet has no Git resource without an extra module (vcsrepo), so the
  # clone, the update and the build are execs guarded by creates/unless.
  Exec {
    user        => 'bookstore',
    environment => ["HOME=${home}"],
    timeout     => 1800,
    require     => [Package['git', 'openjdk-21-jdk-headless'], User['bookstore']],
  }

  exec { 'clone the group repository':
    command => "/usr/bin/git clone --quiet --depth 1 --branch ${repo_branch} ${repo_url} ${src}",
    creates => "${src}/.git",
  }

  exec { 'update the group repository':
    command => "${git} fetch --quiet --depth 1 origin ${repo_branch} && ${git} reset --quiet --hard FETCH_HEAD",
    unless  => "${git} fetch --quiet --depth 1 origin ${repo_branch} && test \"$(${git} rev-parse HEAD)\" = \"$(${git} rev-parse FETCH_HEAD)\"",
    provider => shell,
    require => Exec['clone the group repository'],
  }

  # The commit that produced the deployed jar is recorded next to it, so the
  # build runs only when the source changed.
  exec { 'build the jar':
    command  => "./gradlew --no-daemon --console=plain --quiet bootJar && find build/libs -name 'bookstore-*.jar' ! -name '*-plain.jar' -exec cp {} build/bookstore.jar \; && ${git} rev-parse HEAD > build/.built-rev",
    cwd      => $project,
    unless   => "test -f build/bookstore.jar && test \"$(cat build/.built-rev 2>/dev/null)\" = \"$(${git} rev-parse HEAD)\"",
    provider => shell,
    require  => Exec['update the group repository'],
  }

  file { '/opt/bookstore':
    ensure => directory,
    owner  => 'root',
    group  => $app_group,
    mode   => '0750',
  }

  file { '/opt/bookstore/bookstore.jar':
    ensure  => file,
    source  => "${project}/build/bookstore.jar",
    owner   => 'root',
    group   => $app_group,
    mode    => '0640',
    require => Exec['build the jar'],
  }

  file { '/etc/bookstore':
    ensure => directory,
    owner  => 'root',
    group  => 'bookstore',
    mode   => '0750',
  }

  file { '/etc/bookstore/application.properties':
    ensure    => file,
    owner     => 'root',
    group     => 'bookstore',
    mode      => '0640',
    content   => Sensitive(epp('cogsi_bookstore/application.properties.epp', {
      'db_host' => 'db', 'h2_port' => $h2_port, 'db_name' => $db_name,
      'db_user' => $db_user, 'db_password' => $db_password.unwrap, 'app_port' => $app_port,
    })),
    show_diff => false,
  }

  file { '/usr/local/bin/wait-for-port':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/cogsi_bookstore/wait-for-port',
  }

  file { '/etc/systemd/system/bookstore.service':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('cogsi_bookstore/bookstore.service.epp', { 'h2_port' => $h2_port }),
  }

  exec { 'bookstore daemon-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    user        => 'root',
    refreshonly => true,
    subscribe   => File['/etc/systemd/system/bookstore.service'],
  }

  service { 'bookstore':
    ensure    => running,
    enable    => true,
    subscribe => [
      File['/opt/bookstore/bookstore.jar', '/etc/bookstore/application.properties'],
      File['/usr/local/bin/wait-for-port', '/etc/systemd/system/bookstore.service'],
      Exec['bookstore daemon-reload'],
    ],
  }

  cogsi_common::ufw_rule { "allow from ${proxy_ip} to ${app_ip} port ${app_port} proto tcp": }

  file { '/usr/local/sbin/bookstore-health':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/cogsi_bookstore/bookstore-health',
  }

  exec { 'bookstore health check':
    command  => '/bin/echo "The Bookstore is not UP or /books returned no books" >&2; /bin/false',
    unless   => "/usr/local/sbin/bookstore-health http://127.0.0.1:${app_port}",
    user     => 'root',
    provider => shell,
    require  => [Service['bookstore'], File['/usr/local/sbin/bookstore-health']],
  }
}
