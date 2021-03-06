provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_instance" "DevInstanceAWS" {
  count = "${var.instance_count}"
  instance_type = "${var.instance_type}"
  subnet_id = "${element(var.subnet_ids, count.index)}"
  ami = "${var.ami_id}"
  key_name = "${var.ssh_key_name}"
  tags {
    Name = "${var.instance_name}"
  }
  security_groups = "${var.security_groups}"
}

resource "null_resource" "ConfigureAnsibleLabelVariable" {
  provisioner "local-exec" {
    command = "echo [${var.dev_host_label}:vars] > ../hosts"
  }
  provisioner "local-exec" {
    command = "echo ansible_ssh_user=${var.ssh_user_name} >> ../hosts"
  }
  provisioner "local-exec" {
    command = "echo ansible_ssh_private_key_file=${var.ssh_key_path} >> ../hosts"
  }
  provisioner "local-exec" {
    command = "echo [${var.dev_host_label}] >> ../hosts"
  }
}

resource "null_resource" "ProvisionRemoteHostsIpToAnsibleHosts" {
  count = "${var.instance_count}"
  connection {
    type = "ssh"
    user = "${var.ssh_user_name}"
    host = "${element(aws_instance.DevInstanceAWS.*.public_ip, count.index)}"
    private_key = "${file("${var.ssh_key_path}")}"
  }
  provisioner "file" {
    source      = "bootstrap"
    destination = "/tmp/bootstrap"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap",
      "/tmp/bootstrap"
    ]
  }
  provisioner "local-exec" {
    command = "echo ${element(aws_instance.DevInstanceAWS.*.public_ip, count.index)} >> ../hosts"
  }
}

resource "null_resource" "ModifyApplyAnsiblePlayBook" {
  provisioner "local-exec" {
    command = "sed -i -e '/hosts:/ s/: .*/: ${var.dev_host_label}/' ../play.yml"   #change host label in playbook dynamically
  }

  provisioner "local-exec" {
    command = "sleep 10; ansible-playbook -i ../hosts ../play.yml"
  }
  depends_on = ["null_resource.ProvisionRemoteHostsIpToAnsibleHosts"]
}
