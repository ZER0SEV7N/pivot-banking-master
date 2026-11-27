# =====================================================================
# 2-load-secrets.ps1
# Carga los secretos bancarios dentro de HashiCorp Vault (secret/pivot-bank)
# =====================================================================

$env:VAULT_ADDR = "http://127.0.0.1:8200"
$env:VAULT_TOKEN = "pivot-bank-dev-token-2026"

Write-Host "Loading Pivot Banking AES-256 & JWT Secrets into HashiCorp Vault..." -ForegroundColor Cyan

vault kv put secret/pivot-bank `
    aes-secret-key="UGl2b3RCYW5rU2VjcmV0S2V5MjAyNlNlY3VyZUFfMjU2" `
    jwt-secret-key="UGl2b3RCYW5rSldUU2lnbmluZ1NlY3JldEtleTIwMjZTaGExMjM0NTY3ODkw" `
    jwt-expiration-ms="3600000"

Write-Host "Verifying stored secrets in secret/pivot-bank:" -ForegroundColor Green
vault kv get secret/pivot-bank