provider "incus" {
  # Se conecta al socket local de Incus en el host WSL2
  # Requiere que tu usuario esté en el grupo incus
  generate_client_certificates = true
  accept_remote_certificate    = true
}
