# Baseline of every machine: packages, host names and the firewall.
# Replaces the Ansible role common.
class cogsi_common (
  Hash[String, String] $hosts = lookup('cogsi::hosts'),
) {
  package { ['curl', 'netcat-openbsd', 'ufw', 'acl', 'python3']:
    ensure => installed,
  }

  file { '/etc/hosts':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('cogsi_common/hosts.epp', { 'hosts' => $hosts }),
  }

  # SSH stays open: Vagrant manages the machines through it.
  cogsi_common::ufw_rule { 'default deny incoming': }
  cogsi_common::ufw_rule { 'default allow outgoing': }
  cogsi_common::ufw_rule { 'allow 22/tcp': }

  exec { 'enable ufw':
    command => '/usr/sbin/ufw --force enable',
    unless  => '/usr/sbin/ufw status | /usr/bin/grep -q "Status: active"',
    require => [Package['ufw'], Cogsi_common::Ufw_rule['allow 22/tcp']],
  }
}
