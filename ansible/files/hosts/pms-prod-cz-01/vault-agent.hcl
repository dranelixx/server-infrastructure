exit_after_auth = false
pid_file = "/run/vault-agent.pid"

vault {
  address = "https://vault-prod-cz-01.getinn.top:8443"
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path   = "/etc/vault.d/role-id"
      secret_id_file_path = "/etc/vault.d/secret-id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink "file" {
    config = {
      path = "/etc/vault.d/.vault-token"
      mode = 0600
    }
  }
}

# Template for WhatsApp Bot (runs via cron, no restart needed)
template {
  source      = "/etc/vault.d/templates/whatsapp-bot.env.ctmpl"
  destination = "/srv/whatsapp-automation/config/.env"
  perms       = "0640"
  command     = "setfacl -m u:3001:r /srv/whatsapp-automation/config/.env"
}

# Template for ImageMaid
template {
  source      = "/etc/vault.d/templates/imagemaid.env.ctmpl"
  destination = "/srv/imagemaid/config/.env"
  perms       = "0640"
  command     = "setfacl -m u:3003:r /srv/imagemaid/config/.env && docker restart imagemaid 2>/dev/null || true"
}

# Template for Plex Auto Languages
template {
  source      = "/etc/vault.d/templates/plex-auto-languages.env.ctmpl"
  destination = "/srv/plex-auto-languages/config/.env"
  perms       = "0640"
  command     = "setfacl -m u:3004:r /srv/plex-auto-languages/config/.env && docker restart plex-auto-languages 2>/dev/null || true"
}

# Template for Kometa
template {
  source      = "/etc/vault.d/templates/kometa.yml.ctmpl"
  destination = "/srv/kometa/config/config.yml"
  perms       = "0640"
  command     = "setfacl -m u:3002:r /srv/kometa/config/config.yml && docker restart kometa 2>/dev/null || true"
}

# Template for PlexTraktSync (watch mode auto-reloads config)
template {
  source      = "/etc/vault.d/templates/plex-trakt-sync-servers.yml.ctmpl"
  destination = "/srv/plex-trakt-sync/config/servers.yml"
  perms       = "0640"
  command     = "setfacl -m u:3006:r /srv/plex-trakt-sync/config/servers.yml"
}

# Template for Varken
template {
  source      = "/etc/vault.d/templates/varken.ini.ctmpl"
  destination = "/srv/varken/varken.ini"
  perms       = "0640"
  command     = "setfacl -m u:3007:r /srv/varken/varken.ini && docker restart varken_app 2>/dev/null || true"
}

# Template for Overlay Reset (runs manually, no restart needed)
template {
  source      = "/etc/vault.d/templates/overlay-reset.env.ctmpl"
  destination = "/srv/overlay-reset/.env"
  perms       = "0640"
  command     = "setfacl -m u:3005:r /srv/overlay-reset/.env"
}
