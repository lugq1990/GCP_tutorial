// There are some command that we would use most is:
// 1. terrarform init(init cloud provider);
// 2. terraform refresh(Tf view => real world)
// 3. terraform plan (real world => desired world)
// 4. terraform apply (desired world => real world)
// 5. terraform destroy (delete resources)

// for windows terraform error: https://github.com/terraform-providers/terraform-provider-google/issues/4856#issuecomment-566159527
// set GOOGLE_PROJECT=cloudtutorial-282707

// when create resource with error timeout shakehand that's network problem... I have to say in office always face this problem: retry until work...

// whole configuration about GCP could be found here: https://www.terraform.io/docs/providers/google/index.html


// we could define as many resources as we want. this is just a GCE
resource "google_compute_instance" "default" {
  name         = "vm-terraform"
  machine_type = "f1-micro"
  zone         = "us-central1-a"

  tags = ["terraform-vm"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  // we have to provide with this parameter
  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  // this shell will start first after the vm created.
  metadata_startup_script = "echo hi > /test.txt"
}

// let's create a firewall resource
resource "google_compute_firewall" "terraform-vm" {
  name = "allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports = ["80"]
  }
  // allow traffic from everywhere to instance with tag: terraform-vm
  source_ranges = ["0.0.0.0/0"]
  target_tags = ["terraform-vm"]
}

// this is to get the instance IP
output "ip" {
  value = "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}"
}

// let's try with bigquery dataset creation
// if we need to create dataset, we do should consider the `location` as it won't be changed
// and it do take sometime so that we could refresh dataset in console
// when create bigquery dataset if with access deny should check the location here: https://cloud.google.com/bigquery/docs/locations
resource "google_bigquery_dataset" "dataset" {
  dataset_id = "terraform_dataset"
  friendly_name = "test"
  description = "This dataset is created by terraform"
  location = "US"
}


// let's try to create a storage bucket
// will create a bucket with lifecycle
resource "google_storage_bucket" "auto-expire" {
  name = "auto-expire-bucket"
  location = "US"
  force_destroy = true

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = "3"  // this is days: Minimum age of an object in days to satisfy this condition
    }
  }
}

// let's try to create a Dataproc cluster with terraform
resource "google_dataproc_cluster" "my-cluster" {
  name = "my-cluster"
  region = "us-central1"

  cluster_config {
    master_config {
      num_instances = 1
      machine_type = "n1-standard-1"
      disk_config {
        boot_disk_size_gb = 15
      }
    }

    // as I face error: Error 400: Insufficient 'IN_USE_ADDRESSES' quota. Requested 3.0, available 2.0., badRequest
    // so here just set worker to 0
    // not set to 0 but just delete the GCE created manually
    worker_config {
      num_instances = 2
      machine_type = "n1-standard-1"
      disk_config {
        boot_disk_size_gb = 15
      }
    }

    // we could also define the preeptible worker
    preemptible_worker_config {
      num_instances = 0
    }

    // define the init actions to init stackdriver
    initialization_action {
      script = "gs://dataproc-initialization-actions/stackdriver/stackdriver.sh"
      timeout_sec = 500
    }
  }
}