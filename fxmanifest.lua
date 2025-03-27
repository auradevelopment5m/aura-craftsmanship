fx_version 'cerulean'

game "gta5"
discord "https://discord.gg/BFkm24SApz"
repository 'https://github.com/auradevelopment5m/aura-craftsmanship'
author "Aura Development"
version '1.0'

lua54 'yes'

client_script {
  'client/**',
}

server_script {
  "server/**",
}

shared_script {
  "config.lua",
  '@ox_lib/init.lua',
}

files {
  'locales/*.json'
}