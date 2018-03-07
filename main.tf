provider "google" {
  credentials = "${file("/usr/local/Cellar/terraform/0.11.3/Terra/gcp-kube/gcp/terraform-test-env.json")}"
  project     = "${var.gce_project}"
  region      = "${var.gce_region}"
}

resource "google_compute_network" "newvpc" {
  name                    = "${var.vpc_name}"
  project                 = "${var.gce_project}"
  auto_create_subnetworks = "false"
}


resource "google_compute_subnetwork" "newsubnet" {
  name          = "subnet-${var.gce_region}"
  ip_cidr_range = "${var.vpc_cidr}"
  network       = "${google_compute_network.newvpc.self_link}"
  region        = "${var.gce_region}"
}

resource "google_container_cluster" "k8scluster" {
  name               = "${var.env}-kubernetes-cluster"
  zone               = "${var.gce_region}-a"
  initial_node_count = 1

  additional_zones = [
  "${var.gce_region}-b",
  "${var.gce_region}-c",
  ]

  master_auth {
    username = "${var.kubernetes_username}"
    password = "${var.kubernetes_password}"
  }

  network = "${google_compute_network.newvpc.self_link}"
  subnetwork = "${google_compute_subnetwork.newsubnet.name}"

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels {
      env = "${var.env}"
    }

    tags = ["networktag1", "networktag2"]
  }
}

resource "google_sql_database_instance" "master" {
  region      = "${var.gce_region}"
  name = "db-${var.env}"
  database_version = "${var.dbversion}"
  settings {
    tier = "${var.dbsize}"
  }
}

resource "google_sql_user" "users" {
  name     = "${var.dbusername}"
  instance = "${google_sql_database_instance.master.name}"
  host     = "${var.dbhost}"
  password = "${var.dbpassword}"
}

resource "google_pubsub_topic" "pubsub_topic" {
  name = "${var.topic}"
}

resource "google_pubsub_subscription" "pubsub_subscription" {
  name  = "${var.subscription}"
  topic = "${google_pubsub_topic.pubsub_topic.name}"
}

resource "google_compute_instance" "bastion" {
  name         = "${var.env}-bastion"
  machine_type = "n1-standard-1"
  zone         = "${var.gce_region}-a"

  tags = ["bastion"]

  boot_disk {
    initialize_params {
      image = "ubuntu-1604-xenial-v20180222"
    }
  }

  network_interface {
    subnetwork       = "${google_compute_subnetwork.newsubnet.self_link}"

    access_config {
      // Ephemeral IP
    }
  }

  metadata {
    env = "${var.env}"
    host = "bastion"
  }

  service_account {
    scopes = []
  }
}
