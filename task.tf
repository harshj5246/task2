provider "aws" {
    region = "ap-south-1"
    profile = "harsh"
}

resource "tls_private_key" "webserver_key" {
    algorithm   =  "RSA"
    rsa_bits    =  4096
}
resource "local_file" "private_key" {
    content         =  tls_private_key.webserver_key.private_key_pem
    filename        =  "hj2.pem"
    file_permission =  0400
}
resource "aws_key_pair" "webserver_key" {
    key_name   = "hj2"
    public_key = tls_private_key.webserver_key.public_key_openssh
}


resource "aws_security_group" "devil" {
  name        = "new_security_group"

   ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name       = "new_security_group"
  }
}



resource "aws_instance" "OS" {
    ami                     = "ami-052c08d70def0ac62"
    instance_type           = "t2.micro"
    key_name                = "hj2"
    security_groups         = ["new_security_group"]

  
tags = {
        Name = "hj-OS"
    }
connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.OS.public_ip
        private_key = file("C:/Users/dell/task2/hj2.pem")
    }
provisioner "remote-exec" {
        inline = [
        "sudo yum install httpd -y",
        "sudo systemctl start httpd",
        "sudo systemctl enable httpd",
        "sudo yum install git -y"
        ]
    }
}



resource "aws_efs_file_system" "efs1" {
  creation_token = "my-product"

  tags = {
    Name = "EFS_Storage"
  }
}

resource "aws_efs_mount_target" "mount1" {
  file_system_id = "${aws_efs_file_system.efs1.id}"
  subnet_id      = "subnet-a6dce6ce"
}

resource "null_resource"  "null1" {
  
   connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.OS.public_ip
        private_key = file("C:/Users/dell/task2/hj2.pem")
    }

   provisioner "remote-exec" {
     inline = [
         "sudo yum -y install nfs-utils",
         "sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.efs1.id}:/   /var/www/html",
        "sudo su -c \"echo '${aws_efs_file_system.efs1.id}:/ /var/www/html nfs4 defaults,vers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0' >> /etc/fstab\""
     
    ]
 
 }
}



resource "aws_s3_bucket" "h1" {
    bucket  = "public-s3-jain"
    acl     = "public-read"
    
    provisioner "local-exec" {
        command     = "git clone https://github.com/harshj5246/task2.git"
    }
}
    
resource "aws_s3_bucket_object" "image-upload" {
    bucket  = aws_s3_bucket.h1.bucket
    key     = "1_75jvBleoQfAZJc3sgTSPQA.jpeg"
    source  = "task2/baby-groot-wallpaper-preview.jpg"
    acl     = "public-read"
}




variable "var1" {default = "S3-"}
locals {
    s3_origin_id = "${var.var1}${aws_s3_bucket.h1.bucket}"
    image_url = "${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.image-upload.key}"
}
resource "aws_cloudfront_distribution" "s3_distribution" {
    default_cache_behavior {
        allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id
        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
    }
enabled             = true
origin {
        domain_name = aws_s3_bucket.h1.bucket_domain_name
        origin_id   = local.s3_origin_id
    }
restrictions {
        geo_restriction {
        restriction_type = "none"
        }
    }
viewer_certificate {
        cloudfront_default_certificate = true
    }
connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.OS.public_ip
        private_key = file("C:/Users/dell/task2/hj2.pem")
    }

provisioner "remote-exec" {
        inline  = [
            # "sudo su << \"EOF\" \n echo \"<img src='${self.domain_name}'>\" >> /var/www/html/file1 \n \"EOF\""
            "sudo su << EOF",
            "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.image-upload.key}'>\" >> /var/www/html/file1",
            "EOF"
        ]
    }
}


resource "null_resource"  "null2" {
	provisioner "local-exec" {
		command = "start chrome  ${aws_instance.OS.public_ip}"
		}
	}