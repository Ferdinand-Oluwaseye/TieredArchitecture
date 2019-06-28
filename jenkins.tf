

resource "azurerm_public_ip" "jenkins" {
	name = "${var.prefix}-publicip-jenkins"
	location = "${azurerm_resource_group.main.location}"	
	resource_group_name = "${azurerm_resource_group.main.name}"
	allocation_method = "Dynamic"
	domain_name_label = "jenkins-${formatdate("DDMMYYhhmmss", timestamp())}"

}

resource "azurerm_network_security_group" "jenkins" {
	name = "${var.prefix}-nsg-jenkins"
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



resource "azurerm_network_interface" "jenkins" {
	name = "${var.prefix}-nic-jenkins"
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
	network_security_group_id = "${azurerm_network_security_group.jenkins.id}"
	
	ip_configuration {
		name = "testconfiguration1"
		subnet_id = "${azurerm_subnet.internal.id}"
		private_ip_address_allocation = "Dynamic"
		public_ip_address_id = "${azurerm_public_ip.jenkins.id}"
		
	}
}

resource "azurerm_virtual_machine" "jenkins" {
	name = "${var.prefix}-jenkins"
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
	network_interface_ids = ["${azurerm_network_interface.jenkins.id}"]
	vm_size = "Standard_B1s"


	storage_image_reference {
		publisher = "Canonical"
		offer = "UbuntuServer"
		sku = "16.04-LTS"
		version = "latest"
	}

	storage_os_disk {
		name = "jenkinsos"
		caching = "ReadWrite"
		create_option = "FromImage"
		managed_disk_type = "Standard_LRS"

	}

	os_profile {
		computer_name = "jenkins"
		admin_username = "jenkins"
		admin_password = "password123"
	}

	os_profile_linux_config {
		disable_password_authentication = true
		ssh_keys {
			path = "/home/jenkins/.ssh/authorized_keys"
			key_data = "${file("/home/ferdinand/.ssh/id_rsa.pub")}"		
		}
	}

	tags = {
		environment = "staging"
	}

	provisioner "remote-exec"{
		inline = [
			"sudo apt update",
			"sudo apt install -y jq",
			"mkdir myrepo", 
			"cd myrepo", 
			"git clone https://github.com/Ferdinand-Oluwaseye/jenkins-scripts", 
			"cd jenkins-scripts",
		 	"./jenkinsInstall.sh"
			]

		connection {
			type = "ssh"
			user = "jenkins"
			private_key = file("/home/ferdinand/.ssh/id_rsa")
			host = "${azurerm_public_ip.jenkins.fqdn}"
		}
	}	
}
