# Step 5 — Troubleshooting Common Errors

---

## Error 1: Application not found in directory

```
AADSTS700016: Application with identifier '***' was not found in the directory 'Globant'
```

**Cause:** The `AZURE_CLIENT_ID` secret points to an App Registration that doesn't exist
in the tenant identified by `AZURE_TENANT_ID`.

**Fix:**
```bash
# Verify the app exists in the correct tenant
az login --tenant <AZURE_TENANT_ID>
az ad app show --id <AZURE_CLIENT_ID>

# If it errors, the app doesn't exist — go back to Step 1 and create it
# Make sure you're logged into the RIGHT tenant before creating
```

---

## Error 2: Subject claim mismatch

```
Error: AADSTS70021: No matching federated identity record found for presented assertion
```

**Cause:** The subject claim in the GitHub OIDC token doesn't match any federated credential in Azure.

**Fix:** Check what subject claim your workflow generates vs what Azure has configured.

```yaml
# Add this step to your workflow to print the actual subject claim
- name: Debug OIDC Token
  run: |
    TOKEN=$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
      "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange")
    echo $TOKEN | python3 -c "
    import sys, json, base64
    token = json.load(sys.stdin)['value']
    payload = token.split('.')[1]
    payload += '=' * (4 - len(payload) % 4)
    decoded = json.loads(base64.b64decode(payload))
    print('Subject:', decoded.get('sub'))
    print('Issuer:', decoded.get('iss'))
    "
```

Compare the printed `subject` with your Azure federated credential subject.

**Common mismatches:**

| Workflow has | Azure configured | Fix |
|---|---|---|
| `environment: production` | `ref:refs/heads/main` | Add env federated credential in Azure |
| No environment, branch=main | `environment:production` | Add branch federated credential in Azure |
| `environment: Production` | `environment:production` | Case mismatch — fix capitalisation |

---

## Error 3: Missing permissions (id-token)

```
Error: Not enough permissions to request an ID token
```

**Cause:** The workflow is missing `permissions: id-token: write`.

**Fix:** Add this to your workflow:

```yaml
permissions:
  id-token: write
  contents: read
```

---

## Error 4: Not all values are present

```
Login failed: Using auth-type: SERVICE_PRINCIPAL.
Not all values are present. Ensure 'client-id' and 'tenant-id' are supplied.
```

**Cause:** One or more secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) are missing or empty.

**Fix:**
```bash
# Check secrets are set (GitHub CLI)
gh secret list --repo YOUR_ORG/YOUR_REPO

# If using environments, check environment-level secrets too
gh secret list --repo YOUR_ORG/YOUR_REPO --env production
```

Also verify the `with:` block in your workflow references the secrets correctly:
```yaml
with:
  client-id: ${{ secrets.AZURE_CLIENT_ID }}        # not {{ secret.CLIENT_ID }}
  tenant-id: ${{ secrets.AZURE_TENANT_ID }}
  subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

---

## Error 5: Conditional Access / Location Policy

```
Continuous access evaluation resulted in challenge with result: InteractionRequired
and code: LocationConditionEvaluationSatisfied
```

**Cause:** Your organisation has a Conditional Access Policy requiring VPN or trusted network.
This affects CLI access, not GitHub Actions runners.

**Fix for CLI:** Connect to corporate VPN, then `az logout && az login`.

**Fix for GitHub Actions:** GitHub Actions runners are external IPs — your Azure AD admin
needs to either:
- Exclude the App Registration from Conditional Access policies
- Add GitHub Actions IP ranges to trusted locations

```bash
# Ask your Azure AD admin to check Conditional Access policies
# for the service principal used by GitHub Actions
az ad sp show --id <APP_CLIENT_ID> --query "appId"
```

---

## Error 6: Insufficient privileges to create App Registration

```
Insufficient privileges to complete the operation.
```

**Cause:** Your Azure AD account lacks the **Application Administrator** role.

**Fix:** Ask your Azure AD admin to either:
- Grant you the **Application Administrator** role temporarily
- Create the App Registration for you using the details from Step 1
- Run the setup script `scripts/01-create-app-registration.sh` themselves

---

## Verify Everything End-to-End

```bash
# 1. Check App Registration exists
az ad app show --id <AZURE_CLIENT_ID> --query "{name:displayName, id:appId}"

# 2. Check Federated Credentials
az ad app federated-credential list --id <AZURE_CLIENT_ID> -o table

# 3. Check Service Principal exists
az ad sp show --id <AZURE_CLIENT_ID> --query "{name:displayName, id:id}"

# 4. Check Role Assignments
az role assignment list --assignee <AZURE_CLIENT_ID> --all -o table

# 5. Check GitHub Secrets (GitHub CLI)
gh secret list --repo YOUR_ORG/YOUR_REPO
gh secret list --repo YOUR_ORG/YOUR_REPO --env production
```

---

## Still Stuck?

Run the verification script which checks all of the above automatically:

```bash
chmod +x scripts/02-verify-setup.sh
./scripts/02-verify-setup.sh
```
