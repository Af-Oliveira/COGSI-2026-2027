# One ufw rule, written as the arguments of the ufw command
# (for example "allow 22/tcp"). Puppet has no ufw resource type, so the rule is
# an exec made idempotent by "unless": it runs only when ufw does not already
# have the rule.
define cogsi_common::ufw_rule (
  String $rule = $title,
) {
  if $rule =~ /^default (allow|deny|reject) (incoming|outgoing)$/ {
    # ufw stores the default policies in /etc/default/ufw with iptables names:
    # incoming/outgoing -> INPUT/OUTPUT, allow/deny/reject -> ACCEPT/DROP/REJECT.
    $chain = { 'incoming' => 'INPUT', 'outgoing' => 'OUTPUT' }[$2]
    $target = { 'allow' => 'ACCEPT', 'deny' => 'DROP', 'reject' => 'REJECT' }[$1]
    $check = "/usr/bin/grep -qx 'DEFAULT_${chain}_POLICY=\"${target}\"' /etc/default/ufw"
  } else {
    $check = "/usr/sbin/ufw show added | /usr/bin/grep -qxF 'ufw ${rule}'"
  }

  # user is explicit: resource defaults declared in the calling class (for
  # example Exec { user => 'bookstore' }) would otherwise apply here too.
  exec { "ufw ${rule}":
    command => "/usr/sbin/ufw ${rule}",
    user    => 'root',
    unless  => $check,
    require => Package['ufw'],
  }
}
