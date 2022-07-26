data "yandex_compute_image" "vm_image" {
  family = var.image_family
} 

data "yandex_compute_image" "ws_image" {
  family = "opensuse-15-3"
} 


#Create AD VM
 
resource "yandex_compute_instance" "keycloak" {
  name     = var.keycloak_name
  hostname = var.keycloak_name
  zone     = var.zone
  platform_id = var.platform_id

  resources {
    cores  = var.cores
    memory = var.memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.vm_image.id
      size     = 30
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.keycloaksubnet[0].id
    nat       = var.nat
  }

  metadata = {
    user-data = templatefile("${path.module}/init/kc-install.yml",
    {
      ssh_key = "${chomp(tls_private_key.ssh.public_key_openssh)}"
      DomainFQDN = var.domain_fqdn
      KC_REALM = var.kc_realm
      KC_VER = var.kc_ver
      KC_PORT = var.kc_port
      KC_ADM_USER = var.kc_adm_user
      KC_ADM_PASS = var.kc_adm_pass
      PG_DB_HOST = yandex_mdb_postgresql_cluster.pg_cluster.host.0.fqdn
      PG_DB_NAME = var.pg_db_name
      PG_DB_USER = var.pg_db_user
      PG_DB_PASS = var.pg_db_pass
    }
    )
  }

  timeouts {
    create = var.timeout_create
    delete = var.timeout_delete
  }

  depends_on = [
    local_file.private_key,
    yandex_mdb_postgresql_cluster.pg_cluster,
    yandex_mdb_postgresql_database.pg_db
  ]
}

# Create Workstation

resource "yandex_compute_instance" "ws" {
  name     = var.ws_name
  hostname = var.ws_name
  zone     = var.zone
  platform_id = var.platform_id

  resources {
    cores  = var.cores
    memory = var.memory
  }

  boot_disk {
    initialize_params {
      image_id = "fd8evbta74pa6pir36uk" #data.yandex_compute_image.ws_image.id
      size     = 30
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.keycloaksubnet[0].id
    nat       = var.nat
  }

  metadata = {
    user-data = templatefile("${path.module}/init/ws-install.yml",
    {
      ssh_key = "${chomp(tls_private_key.ssh.public_key_openssh)}"
      DomainFQDN=var.domain_fqdn
      KC_ADM_PASS=var.kc_adm_pass
      DNS_IP=yandex_compute_instance.keycloak.network_interface.0.ip_address
      KC_NAME=var.keycloak_name
      KC_PORT=var.kc_port
    }
    )
  }

  timeouts {
    create = var.timeout_create
    delete = var.timeout_delete
  }

  depends_on = [
    local_file.private_key,
    yandex_mdb_postgresql_cluster.pg_cluster,
    yandex_mdb_postgresql_database.pg_db
  ]
}

output "keycloak_name" {
  value = yandex_compute_instance.keycloak.name
}

output "keycloak_address" {
  value = yandex_compute_instance.keycloak.network_interface.0.nat_ip_address
}

output "ws_name" {
  value = yandex_compute_instance.ws.name
}

output "ws_address" {
  value = yandex_compute_instance.ws.network_interface.0.nat_ip_address
}

output "public_key" {
  value = chomp(tls_private_key.ssh.public_key_openssh)
}