resource "azurerm_public_ip" "python_server" {
	name = "${var.prefix}-publicip-python-server"
	location = "${azurerm_resource_group.main.location}"	
	resource_group_name = "${azurerm_resource_group.main.name}"
	allocation_method = "Dynamic"
	domain_name_label = "python-${formatdate("DDMMYYhhmmss", timestamp())}"

}

resource "azurerm_network_security_group" "python_server" {
	name = "${var.prefix}-nsg-python-server"
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
	
	security_rule {
		name = "SSH"
		priority = "400"
		direction = "Inbound"
		access = "Allow"
		protocol = "Tcp"
		source_port_range = "*"
		destination_port_range = "22"
		source_address_prefix = "*"
		destination_address_prefix = "*"
	}

	security_rule {
                name = "Python-Server"
                priority = "500"
                direction = "Inbound"
                access = "Allow"
                protocol = "Tcp"
                source_port_range = "*"
                destination_port_range = "8000"
                source_address_prefix = "*"
                destination_address_prefix = "*"
        }
}



resource "azurerm_network_interface" "python_server" {
	name = "${var.prefix}-nic-python-server"
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
	network_security_group_id = "${azurerm_network_security_group.python_server.id}"
	
	ip_configuration {
		name = "testconfiguration1"
		subnet_id = "${azurerm_subnet.internal.id}"
		private_ip_address_allocation = "Dynamic"
		public_ip_address_id = "${azurerm_public_ip.python_server.id}"
		
	}
}

resource "azurerm_virtual_machine" "python_server" {
	name = "${var.prefix}-vm-python-server"
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
	network_interface_ids = ["${azurerm_network_interface.python_server.id}"]
	vm_size = "Standard_B1s"


	storage_image_reference {
		publisher = "Canonical"
		offer = "UbuntuServer"
		sku = "16.04-LTS"
		version = "latest"
	}

	storage_os_disk {
		name = "pythonos"
		caching = "ReadWrite"
		create_option = "FromImage"
		managed_disk_type = "Standard_LRS"

	}

	os_profile {
		computer_name = "python-server"
		admin_username = "pythonuser"
		admin_password = "password123"
	}

	os_profile_linux_config {
		disable_password_authentication = true
		ssh_keys {
			path = "/home/pythonuser/.ssh/authorized_keys"
			key_data = "${file("/home/ferdinand/.ssh/id_rsa.pub")}"		
		}
	}

	tags = {
		environment = "staging"
	}

	provisioner "remote-exec"{
		inline = [
			"sudo apt update"
			]

		connection {
			type = "ssh"
			user = "pythonuser"
			private_key = file("/home/ferdinand/.ssh/id_rsa")
			host = "${azurerm_public_ip.python_server.fqdn}"
		}
	}	
}

