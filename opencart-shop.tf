
/* resource "time_sleep" "wait_60_seconds" {
  create_duration = "120s"
} */

#Create Opencart VM-------------------------------------
resource "yandex_compute_instance" "opencart-vm" {
  name     = "opencartshop2"
  hostname = "opencartshop2"
  zone     = var.zone
  platform_id = var.platform_id

  resources {
    cores  = var.cores
    memory = var.memory
  }

  boot_disk {
    initialize_params {
      image_id = var.opencart_image_id
      size     = var.disk_size
      type     = var.disk_type
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.keycloaksubnet[0].id
    nat       = var.nat
  }

  metadata = {
  user-data = "${data.template_file.cloud_init_lin.rendered}"
  serial-port-enable = 1
  
}
  
}

/* resource "null_resource" "previous" {
  depends_on = [time_sleep.wait_60_seconds]
  #Command to see default mysql credentials
  provisioner "local-exec" {
    #command = "ssh -i pt_key.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null yc-user@${yandex_compute_instance.opencart-vm.network_interface.0.nat_ip_address} sudo cat /root/default_passwords.txt"
    command = "ssh -i pt_key.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null yc-user@${yandex_compute_instance.opencart-vm.network_interface.0.nat_ip_address} cat /tmp/default_passwords.txt" 
  }
} */

data "template_file" "cloud_init_lin" {
  template = file("init/opencart-install.yaml")
   vars =  {
        ssh_key = "${chomp(tls_private_key.ssh.public_key_openssh)}"
    }
}
#Create ssh key
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "pt_key.pem"
  file_permission = "0600"
}

output "after_install" {
  value = "to finish your installation of opencart follow instrucions https://cloud.yandex.ru/docs/solutions/internet-store/opencart#configure-opencart . You can view your default_passwords.txt file by putting this command ssh -i pt_key.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null yc-user@${yandex_compute_instance.opencart-vm.network_interface.0.nat_ip_address} cat /tmp/default_passwords.txt"
}
