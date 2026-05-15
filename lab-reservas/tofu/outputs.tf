# =============================================================================
# outputs.tf — Datos útiles de salida
# =============================================================================

output "profiles" {
  description = "Perfiles creados"
  value       = [for p in incus_profile.node : p.name]
}

output "containers" {
  description = "Contenedores gestionados"
  value       = [for c in incus_instance.node : c.name]
}