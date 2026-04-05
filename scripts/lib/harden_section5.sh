#!/usr/bin/env bash
# CIS Section 5 hardening: Encryption (TLS)

CERTS_DIR="${CERTS_DIR:-/opt/cis/certs}"
KEYSTORE_PASS="${KEYSTORE_PASS:-cassandra-keystore}"

_gen_tls_certs() {
  local node_ip
  node_ip="${NODE_IP:-$(hostname -I 2>/dev/null | awk '{print $1}' || echo '127.0.0.1')}"
  info "[CIS 5] Generating TLS certificates for node $node_ip..."
  sudo mkdir -p "$CERTS_DIR"

  # CA (only generate if not present — shared across nodes)
  if [ ! -f "$CERTS_DIR/ca.key" ]; then
    sudo openssl genrsa -out "$CERTS_DIR/ca.key" 4096 2>/dev/null
    sudo openssl req -x509 -new -nodes -key "$CERTS_DIR/ca.key" -sha256 -days 3650 \
      -out "$CERTS_DIR/ca.crt" \
      -subj "/C=VN/ST=HCM/O=CIS-Cassandra/CN=CIS-CA" 2>/dev/null
    success "  CA certificate generated: $CERTS_DIR/ca.crt"
  else
    info "  CA certificate already exists — reusing"
  fi

  # Node key + cert (only regenerate if cert is missing or expired within 30 days)
  local regen_node=false
  if [ ! -f "$CERTS_DIR/node.crt" ]; then
    regen_node=true
  elif ! openssl x509 -checkend $((30*86400)) -noout \
        -in "$CERTS_DIR/node.crt" 2>/dev/null; then
    info "  Node certificate expires within 30 days — regenerating"
    regen_node=true
  fi

  if $regen_node; then
    sudo openssl genrsa -out "$CERTS_DIR/node.key" 2048 2>/dev/null
    sudo openssl req -new -key "$CERTS_DIR/node.key" \
      -out "$CERTS_DIR/node.csr" \
      -subj "/C=VN/ST=HCM/O=CIS-Cassandra/CN=${node_ip}" 2>/dev/null
    sudo openssl x509 -req -in "$CERTS_DIR/node.csr" \
      -CA "$CERTS_DIR/ca.crt" -CAkey "$CERTS_DIR/ca.key" \
      -CAcreateserial -out "$CERTS_DIR/node.crt" -days 365 -sha256 2>/dev/null

    # PKCS12 → JKS keystore (remove old alias first to avoid conflict)
    sudo openssl pkcs12 -export \
      -in "$CERTS_DIR/node.crt" -inkey "$CERTS_DIR/node.key" \
      -out "$CERTS_DIR/node.p12" -name cassandra \
      -passout "pass:${KEYSTORE_PASS}" 2>/dev/null
    # Delete existing alias if present to ensure clean import
    sudo keytool -delete -alias cassandra \
      -keystore "$CERTS_DIR/keystore.jks" \
      -storepass "${KEYSTORE_PASS}" 2>/dev/null || true
    sudo keytool -importkeystore \
      -deststorepass "${KEYSTORE_PASS}" -destkeypass "${KEYSTORE_PASS}" \
      -destkeystore "$CERTS_DIR/keystore.jks" \
      -srckeystore "$CERTS_DIR/node.p12" -srcstoretype PKCS12 \
      -srcstorepass "${KEYSTORE_PASS}" -alias cassandra -noprompt 2>/dev/null

    # JKS truststore (delete old CARoot first if exists)
    sudo keytool -delete -alias CARoot \
      -keystore "$CERTS_DIR/truststore.jks" \
      -storepass "${KEYSTORE_PASS}" 2>/dev/null || true
    sudo keytool -import -trustcacerts -alias CARoot \
      -file "$CERTS_DIR/ca.crt" \
      -keystore "$CERTS_DIR/truststore.jks" \
      -storepass "${KEYSTORE_PASS}" -noprompt 2>/dev/null

    sudo chown -R cassandra:cassandra "$CERTS_DIR" 2>/dev/null || true
    success "  Keystore:   $CERTS_DIR/keystore.jks"
    success "  Truststore: $CERTS_DIR/truststore.jks"
  else
    info "  Node certificate valid — reusing existing keystore"
  fi
}

apply_5_1() {
  local yaml="${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}"
  info "[CIS 5.1] Enabling inter-node encryption..."
  if $DRY_RUN; then
    info "  [dry-run] Would set internode_encryption: all and configure keystore/truststore"
    return
  fi
  _gen_tls_certs
  # Set internode_encryption inside server_encryption_options block
  if grep -qi "internode_encryption:" "$yaml" 2>/dev/null; then
    sudo sed -i 's/^[[:space:]]*internode_encryption:.*/    internode_encryption: all/' "$yaml"
  else
    # Add inside server_encryption_options block if it exists
    if grep -q "server_encryption_options:" "$yaml" 2>/dev/null; then
      sudo sed -i "/server_encryption_options:/a\\    internode_encryption: all" "$yaml"
    else
      printf '\nserver_encryption_options:\n    internode_encryption: all\n' \
        | sudo tee -a "$yaml" > /dev/null
    fi
  fi
  # Set keystore/truststore using awk (avoids /^[^ ]/ range closing on comments)
  sudo awk -v ks="${CERTS_DIR}/keystore.jks" -v kp="${KEYSTORE_PASS}" \
           -v ts="${CERTS_DIR}/truststore.jks" \
    '
    /^server_encryption_options:/ { in_block=1 }
    in_block && /^[^ #]/ && !/^server_encryption_options:/ { in_block=0 }
    in_block {
      if (/[[:space:]]keystore_password:/) { sub(/keystore_password:.*/, "keystore_password: " kp) }
      else if (/[[:space:]]keystore:/)     { sub(/keystore:.*/, "keystore: " ks) }
      else if (/[[:space:]]truststore_password:/) { sub(/truststore_password:.*/, "truststore_password: " kp) }
      else if (/[[:space:]]truststore:/)   { sub(/truststore:.*/, "truststore: " ts) }
    }
    { print }
    ' "$yaml" | sudo tee "$yaml.tmp" > /dev/null && sudo mv "$yaml.tmp" "$yaml"
  success "[CIS 5.1] Inter-node encryption enabled. Restart required."
}

apply_5_2() {
  local yaml="${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}"
  info "[CIS 5.2] Enabling client-to-node encryption..."
  if $DRY_RUN; then
    info "  [dry-run] Would enable client_encryption_options.enabled: true"
    return
  fi
  if grep -A10 "client_encryption_options:" "$yaml" 2>/dev/null | grep -qi "enabled: true"; then
    info "  [CIS 5.2] Client encryption already enabled"
    return
  fi
  sudo awk -v ks="${CERTS_DIR}/keystore.jks" -v kp="${KEYSTORE_PASS}" \
    '
    /^client_encryption_options:/ { in_block=1 }
    in_block && /^[^ #]/ && !/^client_encryption_options:/ { in_block=0 }
    in_block {
      if (/enabled: false/)                { sub(/enabled: false/, "enabled: true") }
      if (/[[:space:]]keystore_password:/) { sub(/keystore_password:.*/, "keystore_password: " kp) }
      else if (/[[:space:]]keystore:/)     { sub(/keystore:.*/, "keystore: " ks) }
    }
    { print }
    ' "$yaml" | sudo tee "$yaml.tmp" > /dev/null && sudo mv "$yaml.tmp" "$yaml"
  success "[CIS 5.2] Client encryption enabled. Restart required."
}

harden_section_5() {
  apply_5_1
  apply_5_2
}
