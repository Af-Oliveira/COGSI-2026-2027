# =============================================================================
# site.pp - COGSI CA3 / Alternative (Puppet, masterless)
# -----------------------------------------------------------------------------
# One node definition per tier, as the plays of the Ansible site.yml. Vagrant
# runs `puppet apply` on each machine; Puppet picks the block whose name
# matches the machine.
#
# Unlike an Ansible play, the resources are not applied in the order they are
# written: Puppet builds a dependency graph, so every order that matters is
# declared with require, before, notify, subscribe or the arrows below.
# =============================================================================

node /^db/ {
  include cogsi_common
  include cogsi_users
  include cogsi_pam
  include cogsi_h2

  Class['cogsi_common'] -> Class['cogsi_users'] -> Class['cogsi_h2']
}

node /^app/ {
  include cogsi_common
  include cogsi_users
  include cogsi_pam
  include cogsi_bookstore

  Class['cogsi_common'] -> Class['cogsi_users'] -> Class['cogsi_bookstore']
}

node /^proxy/ {
  include cogsi_common
  include cogsi_nginx

  Class['cogsi_common'] -> Class['cogsi_nginx']
}
