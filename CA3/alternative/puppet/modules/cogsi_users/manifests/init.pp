# The developers group and devuser on app and db. Replaces the Ansible role
# users. The password hash is Sensitive: Puppet redacts it from logs and
# reports.
class cogsi_users (
  String $group = lookup('cogsi::developers_group'),
  String $devuser = lookup('cogsi::devuser'),
  Sensitive[String] $password_hash = Sensitive(lookup('cogsi::devuser_password_hash')),
) {
  group { $group:
    ensure => present,
  }

  user { $devuser:
    ensure     => present,
    shell      => '/bin/bash',
    managehome => true,
    groups     => [$group],
    membership => minimum,
    password   => $password_hash,
    require    => Group[$group],
  }
}
