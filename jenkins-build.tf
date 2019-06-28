

resource "azurerm_public_ip" "jenkins_build" {
	name = "${var.prefix}-publicip-jenkins-build"
	location = "${azurerm_resource_group.main.location}"	
	resource_group_name = "${azurerm_resource_group.main.name}"
	allocation_method = "Dynamic"
	domain_name_label = "jenkins-build-${formatdate("DDMMYYhhmmss", timestamp())}"

}

resource "azurerm_network_security_group" "jenkins_build" {
	name = "${var.prefix}-nsg-jenkins-build"
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
                name = "Jenkins-Server"
                priority = "500"
                direction = "Inbound"
                access = "Allow"
                protocol = "Tcp"
                source_port_range = "*"
                destination_port_range = "8080"
                source_address_prefix = "*"
                destination_address_prefix = "*"
        }
}



resource "azurerm_network_interface" "jenkins_build" {
	name = "${var.prefix}-nic-jenkins-build"
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
	network_security_group_id = "${azurerm_network_security_group.jenkins_build.id}"
	
	ip_configuration {
		name = "testconfiguration1"
		subnet_id = "${azurerm_subnet.internal.id}"
		private_ip_address_allocation = "Dynamic"
		public_ip_address_id = "${azurerm_public_ip.jenkins_build.id}"
		
	}
}

resource "azurerm_virtual_machine" "jenkins_build" {
	name = "${var.prefix}-vm-jenkins-build"
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
	network_interface_ids = ["${azurerm_network_interface.jenkins_build.id}"]
	vm_size = "Standard_B1s"


	storage_image_reference {
		publisher = "Canonical"
		offer = "UbuntuServer"
		sku = "16.04-LTS"
		version = "latest"
	}

	storage_os_disk {
		name = "buildos"
		caching = "ReadWrite"
		create_option = "FromImage"
		managed_disk_type = "Standard_LRS"

	}

	os_profile {
		computer_name = "jenkins-build"
		admin_username = "jenkinsbuild"
		admin_password = "password123"
	}

	os_profile_linux_config {
		disable_password_authentication = true
		ssh_keys {
			path = "/home/jenkinsbuild/.ssh/authorized_keys"
			key_data = "${file("/home/ferdinand/.ssh/id_rsa.pub")}"		
		}
	}

	tags = {
		environment = "staging"
	}

	provisioner "remote-exec"{
		inline = [
			"sudo apt update",
			"sudo apt install -y default-jdk"
			]

		connection {
			type = "ssh"
			user = "jenkinsbuild"
			private_key = file("/home/ferdinand/.ssh/id_rsa")
			host = "${azurerm_public_ip.jenkins_build.fqdn}"
		}
	}	
}

