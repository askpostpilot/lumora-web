# 🔐 EXACT .ENV LINES FOR API KEYS

## After deployment, edit `/opt/solyntra/.env` and replace these EXACT lines:

### Canva API Keys
```
CANVA_API_KEY=### FILL_ME_IN ###
CANVA_CLIENT_ID=### FILL_ME_IN ###
CANVA_CLIENT_SECRET=### FILL_ME_IN ###
```

### Supabase Configuration
```
SUPABASE_URL=### FILL_ME_IN ###
SUPABASE_ANON_KEY=### FILL_ME_IN ###
SUPABASE_SERVICE_KEY=### FILL_ME_IN ###
```

### OpenAI Configuration
```
OPENAI_API_KEY=### FILL_ME_IN ###
OPENAI_ORG_ID=### FILL_ME_IN ### (optional)
```

## How to Update:
1. SSH into your VPS: `ssh root@your-vps-ip`
2. Edit the file: `nano /opt/solyntra/.env`
3. Replace `### FILL_ME_IN ###` with your actual keys
4. Save and restart: `cd /opt/solyntra && docker compose restart`

## Verification:
Run `/opt/solyntra/verify-deployment.sh` to check if all keys are configured properly.