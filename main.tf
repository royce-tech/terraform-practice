terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "mtc-rg" {
  name     = "mtc-resources"
  location = "Australia Central"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "mtc-vn" {
  name                = "mtc-network"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet" "mtc-subnet-1" {
  name                 = "mtc-subnet-1"
  address_prefixes     = ["10.123.1.0/24"]
  resource_group_name  = azurerm_resource_group.mtc-rg.name
  virtual_network_name = azurerm_virtual_network.mtc-vn.name
}

resource "azurerm_network_security_group" "mtc-sg-1" {
  name                = "mtc-sg-1"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  security_rule {
    name                       = "rule1"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet_network_security_group_association" "sub-sg-assoc1" {
  subnet_id                 = azurerm_subnet.mtc-subnet-1.id
  network_security_group_id = azurerm_network_security_group.mtc-sg-1.id
}

resource "azurerm_public_ip" "mtc-ip" {
  count               = 3
  name                = "mtc-ip${count.index}"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}


resource "azurerm_network_interface" "mtc-nic" {
  count               = 3
  name                = "mtc-nic${count.index}"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc-subnet-1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.mtc-ip[count.index].id}"


  }

  tags = {
    environment = "dev"
  }
}


resource "azurerm_linux_virtual_machine" "mtc-vm" {
  count                 = 3
  name                  = "linux-vm${count.index}"
  resource_group_name   = azurerm_resource_group.mtc-rg.name
  location              = azurerm_resource_group.mtc-rg.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.mtc-nic[count.index].id, ]

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/mtcazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  tags = {
    environment = "dev"
  }
}