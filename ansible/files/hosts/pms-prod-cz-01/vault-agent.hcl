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
}

# Template for WhatsApp Bot
template {
  source      = "/etc/vault.d/templates/whatsapp-bot.env.ctmpl"
  destination = "/srv/whatsapp-automation/config/.env"
  perms       = "0600"
  command     = "setfacl -m m::r /srv/whatsapp-automation/config/.env"
}

# Template for ImageMaid
template {
  source      = "/etc/vault.d/templates/imagemaid.env.ctmpl"
  destination = "/srv/imagemaid/config/.env"
  perms       = "0600"
  command     = "setfacl -m m::r /srv/imagemaid/config/.env"
}

# Template for Plex Auto Languages
template {
  source      = "/etc/vault.d/templates/plex-auto-languages.env.ctmpl"
  destination = "/srv/plex-auto-languages/config/.env"
  perms       = "0600"
  command     = "setfacl -m m::r /srv/plex-auto-languages/config/.env"
}

# Template for Kometa
template {
  source      = "/etc/vault.d/templates/kometa.yml.ctmpl"
  destination = "/srv/kometa/config/config.yml"
  perms       = "0640"
  command     = "docker restart kometa 2>/dev/null || true"
}

# Template for PlexTraktSync
template {
  source      = "/etc/vault.d/templates/plex-trakt-sync-servers.yml.ctmpl"
  destination = "/srv/plex-trakt-sync/config/servers.yml"
  perms       = "0640"
}
