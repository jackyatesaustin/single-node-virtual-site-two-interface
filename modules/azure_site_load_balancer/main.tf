data "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

data "azurerm_resources" "network_interfaces" {
  type                = "Microsoft.Network/networkInterfaces"
  resource_group_name = var.resource_group_name
}

data "azurerm_network_interface" "ce" {
  for_each = {
    for nic in data.azurerm_resources.network_interfaces.resources :
    nic.name => nic
  }

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
}

data "azurerm_subnet" "inside" {
  for_each = {
    for subnet_name in data.azurerm_virtual_network.this.subnets :
    subnet_name => subnet_name
  }

  name                 = each.value
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = data.azurerm_virtual_network.this.resource_group_name
}

locals {
  subnet_ids_by_cidr = {
    for name, subnet in data.azurerm_subnet.inside :
    one(subnet.address_prefixes) => subnet.id
    if length(subnet.address_prefixes) == 1
  }

  inside_subnet_id  = lookup(local.subnet_ids_by_cidr, var.inside_subnet_cidr, null)
  outside_subnet_id = lookup(local.subnet_ids_by_cidr, var.outside_subnet_cidr, null)

  discovered_inside_private_ips = distinct(flatten([
    for nic in data.azurerm_network_interface.ce : [
      for ip_config in nic.ip_configuration :
      ip_config.private_ip_address
      if ip_config.private_ip_address != null && ip_config.subnet_id == local.inside_subnet_id
    ]
  ]))

  discovered_outside_private_ips = distinct(flatten([
    for nic in data.azurerm_network_interface.ce : [
      for ip_config in nic.ip_configuration :
      ip_config.private_ip_address
      if ip_config.private_ip_address != null && ip_config.subnet_id == local.outside_subnet_id
    ]
  ]))

  inside_backend_addresses  = length(var.internal_backend_ips) > 0 ? sort(distinct(var.internal_backend_ips)) : sort(local.discovered_inside_private_ips)
  outside_backend_addresses = length(var.public_backend_ips) > 0 ? sort(distinct(var.public_backend_ips)) : sort(local.discovered_outside_private_ips)
}

resource "azurerm_public_ip" "public" {
  count = var.public_lb_enabled ? 1 : 0

  name                = var.public_ip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.public_frontend_domain_name
}

resource "azurerm_lb" "public" {
  count = var.public_lb_enabled ? 1 : 0

  name                = var.public_lb_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = var.public_frontend_name
    public_ip_address_id = azurerm_public_ip.public[0].id
  }
}

resource "azurerm_lb" "internal" {
  count = var.internal_lb_enabled ? 1 : 0

  name                = var.internal_lb_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = var.internal_frontend_name
    subnet_id                     = local.inside_subnet_id
    private_ip_address_allocation = var.internal_frontend_private_ip == null ? "Dynamic" : "Static"
    private_ip_address            = var.internal_frontend_private_ip
  }
}

resource "azurerm_lb_backend_address_pool" "public" {
  count = var.public_lb_enabled ? 1 : 0

  name            = "${var.site_key}-public-backend-pool"
  loadbalancer_id = azurerm_lb.public[0].id
}

resource "azurerm_lb_backend_address_pool" "internal" {
  count = var.internal_lb_enabled ? 1 : 0

  name            = "${var.site_key}-internal-backend-pool"
  loadbalancer_id = azurerm_lb.internal[0].id
}

resource "azurerm_lb_backend_address_pool_address" "public" {
  for_each = var.public_lb_enabled ? {
    for index, ip in local.outside_backend_addresses :
    "${var.site_key}-outside-${index}" => ip
  } : {}

  name                    = each.key
  backend_address_pool_id = azurerm_lb_backend_address_pool.public[0].id
  virtual_network_id      = data.azurerm_virtual_network.this.id
  ip_address              = each.value
}

resource "azurerm_lb_backend_address_pool_address" "internal" {
  for_each = var.internal_lb_enabled ? {
    for index, ip in local.inside_backend_addresses :
    "${var.site_key}-inside-${index}" => ip
  } : {}

  name                    = each.key
  backend_address_pool_id = azurerm_lb_backend_address_pool.internal[0].id
  virtual_network_id      = data.azurerm_virtual_network.this.id
  ip_address              = each.value
}

resource "azurerm_lb_probe" "public" {
  count = var.public_lb_enabled ? 1 : 0

  name            = "${var.site_key}-public-probe"
  loadbalancer_id = azurerm_lb.public[0].id
  port            = var.probe_port
}

resource "azurerm_lb_probe" "internal" {
  count = var.internal_lb_enabled ? 1 : 0

  name            = "${var.site_key}-internal-probe"
  loadbalancer_id = azurerm_lb.internal[0].id
  port            = var.probe_port
}

resource "azurerm_lb_rule" "public" {
  count = var.public_lb_enabled ? 1 : 0

  name                           = "${var.site_key}-public-${var.listener_port}"
  loadbalancer_id                = azurerm_lb.public[0].id
  protocol                       = "Tcp"
  frontend_port                  = var.listener_port
  backend_port                   = var.listener_port
  frontend_ip_configuration_name = var.public_frontend_name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.public[0].id]
  probe_id                       = azurerm_lb_probe.public[0].id
}

resource "azurerm_lb_rule" "internal" {
  count = var.internal_lb_enabled ? 1 : 0

  name                           = "${var.site_key}-internal-${var.listener_port}"
  loadbalancer_id                = azurerm_lb.internal[0].id
  protocol                       = "Tcp"
  frontend_port                  = var.listener_port
  backend_port                   = var.listener_port
  frontend_ip_configuration_name = var.internal_frontend_name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.internal[0].id]
  probe_id                       = azurerm_lb_probe.internal[0].id
}
