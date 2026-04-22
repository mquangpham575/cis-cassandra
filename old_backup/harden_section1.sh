#!/usr/bin/env bash
# CIS Section 1 hardening: Installation and Updates

apply_1_1() {
  info "[CIS 1.1] Ensuring cassandra user and group exist..."
  if $DRY_RUN; then
    info "  [dry-run] Would create cassandra user/group (uid=2000, gid=2000)"
    return
  fi
  if ! getent group cassandra &>/dev/null; then
    sudo groupadd -g 2000 cassandra
    success "  Created group cassandra (gid=2000)"
  else
    info "  Group cassandra already exists"
  fi
  if ! getent passwd cassandra &>/dev/null; then
    sudo useradd -u 2000 -g cassandra -d /var/lib/cassandra -s /bin/false cassandra
    success "  Created user cassandra (uid=2000)"
  else
    info "  User cassandra already exists"
  fi
}

apply_1_5() {
  info "[CIS 1.5] Ensuring Cassandra directories are owned by cassandra user..."
  if $DRY_RUN; then
    info "  [dry-run] Would chown /var/lib/cassandra /var/log/cassandra /etc/cassandra to cassandra:cassandra"
    return
  fi
  for dir in /var/lib/cassandra /var/log/cassandra /etc/cassandra; do
    if [ -d "$dir" ]; then
      sudo chown -R cassandra:cassandra "$dir"
      success "  Ownership set: $dir"
    else
      info "  Directory not found (skipping): $dir"
    fi
  done
}

apply_1_6() {
  info "[CIS 1.6] Configuring NTP (chrony)..."
  if $DRY_RUN; then
    info "  [dry-run] Would install chrony and enable NTP sync"
    return
  fi
  if ! command -v chronyd &>/dev/null && ! command -v ntpd &>/dev/null; then
    sudo apt-get install -y chrony &>/dev/null \
      || sudo yum install -y chrony &>/dev/null \
      || warn "  Could not install chrony — install manually"
  fi
  if command -v chronyd &>/dev/null; then
    sudo systemctl enable --now chrony 2>/dev/null || true
  fi
  timedatectl status 2>/dev/null | grep -E 'NTP|synchronized' || true
  success "[CIS 1.6] NTP configuration complete"
}

harden_section_1() {
  apply_1_1
  apply_1_5
  apply_1_6
}
