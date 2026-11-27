# =====================================================================
# 1-start-vault.ps1
# Levanta HashiCorp Vault nativo en modo DEV en http://127.0.0.1:8200
# IMPORTANTE: Deja esta ventana abierta mientras trabajes.
# =====================================================================

$VAULT_TOKEN = "pivot-bank-dev-token-2026"

Write-Host "Iniciando HashiCorp Vault en modo DEV..." -ForegroundColor Cyan
C:\vault\vault.exe server -dev -dev-root-token-id="$VAULT_TOKEN" -dev-listen-address="127.0.0.1:8200"