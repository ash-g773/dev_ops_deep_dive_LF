output "http_server_public_ips" {
  value = { for k, pip in azurerm_public_ip.http_server_pips : k => pip.ip_address }
}

# NEW CONFIG
output "lb_public_ip" {
  value = azurerm_public_ip.lb_pip.ip_address
}