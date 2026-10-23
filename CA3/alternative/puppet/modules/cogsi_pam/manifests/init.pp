# PAM password policy, history and lockout on app and db. Replaces the
# Ansible role pam: the same option files and pam-auth-update profiles.
class cogsi_pam {
  package { 'libpam-pwquality':
    ensure => installed,
  }

  file {
    default:
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644';
    '/etc/security/pwquality.conf':
      source  => 'puppet:///modules/cogsi_pam/pwquality.conf',
      require => Package['libpam-pwquality'];
    '/etc/security/pwhistory.conf':
      source => 'puppet:///modules/cogsi_pam/pwhistory.conf';
    '/etc/security/faillock.conf':
      source => 'puppet:///modules/cogsi_pam/faillock.conf';
    '/usr/share/pam-configs/pwhistory':
      source => 'puppet:///modules/cogsi_pam/pwhistory';
    '/usr/share/pam-configs/faillock':
      source => 'puppet:///modules/cogsi_pam/faillock';
    '/usr/share/pam-configs/faillock_notify':
      source => 'puppet:///modules/cogsi_pam/faillock_notify';
  }

  # pam-auth-update regenerates /etc/pam.d/common-*; it runs only when a module
  # is missing from the stack, or when a profile changed (subscribe).
  exec { 'pam-auth-update':
    command   => '/usr/sbin/pam-auth-update --package --enable pwhistory faillock faillock_notify',
    unless    => '/usr/bin/grep -q "pam_faillock.so preauth" /etc/pam.d/common-auth && /usr/bin/grep -q "pam_faillock.so authfail" /etc/pam.d/common-auth && /usr/bin/grep -q pam_faillock.so /etc/pam.d/common-account && /usr/bin/grep -q pam_pwhistory.so /etc/pam.d/common-password && /usr/bin/grep -q pam_pwquality.so /etc/pam.d/common-password',
    subscribe => File['/usr/share/pam-configs/pwhistory', '/usr/share/pam-configs/faillock', '/usr/share/pam-configs/faillock_notify'],
    require   => Package['libpam-pwquality'],
  }
}
