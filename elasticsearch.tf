resource "aws_security_group" "allow_elk" {
  name = "allow_elk"
  description = "All elasticsearch traffic"
  #vpc_id = "${aws_vpc.main.id}"

  # elasticsearch port
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = var.CIDR
  }

  # logstash port
  ingress {
    from_port   = 5043
    to_port     = 5044
    protocol    = "tcp"
    cidr_blocks = var.CIDR
  }

  # kibana ports
  ingress {
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = var.CIDR
  }

  # ssh
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.CIDR
  }

  # outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
}

resource "aws_instance" "elk" {
  ami           = var.AMI
  instance_type = var.TYPE
  key_name      = var.key
  availability_zone = var.availability_zone
  vpc_security_group_ids = [
    aws_security_group.allow_elk.id,
  ]
  user_data = data.template_file.installation_template.rendered
  tags = {
    Name = "Backend - Magento"
  }
  provisioner "file" {
    content      = "network.bind_host: 0.0.0.0"
    destination   = "/tmp/elasticsearch.yml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host     = self.public_ip
      private_key = var.private_key
    }
  }

  provisioner "file" {
    content       = "server.host: 0.0.0.0"
    destination   = "/tmp/kibana.yml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host     = self.public_ip
      private_key = var.private_key
    }
  }

  provisioner "file" {
    content       = "http.host: 0.0.0.0"
    destination   = "/tmp/logstash.yml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host     = self.public_ip
      private_key =  var.private_key
    }
  }

  provisioner "file" {
    source        = "${path.module}/filebeat.yml"
    destination   = "/tmp/filebeat.yml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host     = self.public_ip
      private_key = var.private_key
    }
  }

  provisioner "file" {
    source        = "${path.module}/beats.conf"
    destination   = "/tmp/beats.conf"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host     = self.public_ip
      private_key = var.private_key
    }
  }

  depends_on = [ aws_security_group.allow_elk ]
}

resource "aws_eip" "ip" {
  instance = aws_instance.elk.id
}

data "template_file" "installation_template" {
  template = "${file("${path.module}/elasticsearch.tpl")}"
}